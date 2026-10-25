import Combine
import Foundation

/// Holds every to-do, note and group, and persists them to a JSON file.
/// All mutations are expected on the main thread.
public final class Store: ObservableObject {
    @Published public private(set) var items: [TodoItem]
    @Published public private(set) var groups: [TodoGroup]
    /// Newest first. Separate from `items`, so notes stay out of Today, the to-do
    /// catch-up deck, and the menu-bar count.
    @Published public private(set) var notes: [Note]

    private let url: URL?
    private var pendingSave: DispatchWorkItem?
    /// Injected so tests can pin "today".
    public var todayProvider: () -> String = { DayKey.todayKey() }

    /// `url == nil` keeps everything in memory (used by tests and previews).
    public init(url: URL?) {
        self.url = url
        if let url, let data = try? Data(contentsOf: url),
           let file = try? JSONDecoder.store.decode(StoreFile.self, from: data) {
            items = file.items
            groups = file.groups
            notes = file.notes.sorted { $0.createdAt > $1.createdAt }
        } else {
            items = []
            groups = TodoGroup.defaults
            notes = []
        }
    }

    /// Bundle ID of the installed app built from main by scripts/make-app.sh.
    public static let releaseBundleID = "com.local.todo"

    /// Only the release app reads and writes the real `Todo/todos.json`. Anything
    /// else (`swift run`, which has no bundle ID, or a dev build stamped
    /// `com.local.todo.dev`) uses `Todo-dev/` so testing never touches real data.
    public static func defaultURL(bundleID: String? = Bundle.main.bundleIdentifier) -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let folder = bundleID == releaseBundleID ? "Todo" : "Todo-dev"
        return base.appendingPathComponent(folder, isDirectory: true).appendingPathComponent("todos.json")
    }

    public var today: String { todayProvider() }

    // MARK: Queries

    /// Dated items first (earliest first), then undated, oldest first.
    public static func sorted(_ xs: [TodoItem]) -> [TodoItem] {
        xs.sorted { a, b in
            switch (a.date, b.date) {
            case let (x?, y?) where x != y: return x < y
            case (.some, nil): return true
            case (nil, .some): return false
            default: return a.createdAt < b.createdAt
            }
        }
    }

    public var open: [TodoItem] { Self.sorted(items.filter { !$0.done }) }
    public var done: [TodoItem] { Self.sorted(items.filter { $0.done }) }
    public var todayOpen: [TodoItem] { open.filter { $0.onToday } }
    public var todayDone: [TodoItem] { done.filter { $0.onToday } }

    /// Open items that are due (or overdue) but not on Today's list.
    public var dueNotOnToday: [TodoItem] {
        let t = today
        return open.filter { !$0.onToday && ($0.date.map { $0 <= t } ?? false) }
    }

    /// What Catch up walks through: open items on Today plus anything due or overdue.
    public var catchUpDeck: [TodoItem] {
        let t = today
        return open.filter { $0.onToday || ($0.date.map { $0 <= t } ?? false) }
    }

    public func item(_ id: UUID) -> TodoItem? { items.first { $0.id == id } }

    public func color(forGroup name: String?) -> String {
        guard let name, let g = groups.first(where: { $0.name == name }) else { return TodoGroup.ungroupedHex }
        return g.colorHex
    }

    public func emoji(forGroup name: String?) -> String? {
        guard let name else { return nil }
        return groups.first { $0.name == name }?.emoji
    }

    // MARK: Mutations

    @discardableResult
    public func add(title: String, group: String?, date: String?, onToday: Bool) -> TodoItem? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let item = TodoItem(title: trimmed, group: group, date: date, onToday: onToday)
        items.append(item)
        scheduleSave()
        return item
    }

    public func setDone(_ id: UUID, _ value: Bool) {
        update(id) { $0.done = value; $0.doneAt = value ? Date() : nil }
    }

    public func toggleDone(_ id: UUID) {
        guard let x = item(id) else { return }
        setDone(id, !x.done)
    }

    public func toggleToday(_ id: UUID) {
        update(id) { $0.onToday.toggle() }
    }

    public func delete(_ id: UUID) {
        items.removeAll { $0.id == id }
        scheduleSave()
    }

    /// Saves a one-line thought. Blank text is rejected. The list stays newest-first.
    @discardableResult
    public func addNote(text: String) -> Note? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let note = Note(text: trimmed)
        notes.insert(note, at: 0)
        scheduleSave()
        return note
    }

    public func deleteNote(_ id: UUID) {
        notes.removeAll { $0.id == id }
        scheduleSave()
    }

    /// Puts a note back and keeps the list newest-first. A second restore of the
    /// same id replaces the existing one rather than duplicating it.
    public func restoreNote(_ note: Note) {
        notes.removeAll { $0.id == note.id }
        notes.append(note)
        notes.sort { $0.createdAt > $1.createdAt }
        scheduleSave()
    }

    /// Renames a to-do. Fails (returns false) for a blank title or an unknown
    /// id and leaves the item unchanged. Only the title changes.
    @discardableResult
    public func rename(_ id: UUID, to raw: String) -> Bool {
        let title = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, item(id) != nil else { return false }
        update(id) { $0.title = title }
        return true
    }

    /// Returns the existing group when the name matches case-insensitively.
    @discardableResult
    public func addGroup(named raw: String) -> TodoGroup? {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        if let existing = groups.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            return existing
        }
        let custom = max(0, groups.count - TodoGroup.defaults.count)
        let g = TodoGroup(name: name, colorHex: TodoGroup.palette[custom % TodoGroup.palette.count])
        groups.append(g)
        scheduleSave()
        return g
    }

    public func setGroup(_ id: UUID, _ group: String?) {
        update(id) { $0.group = group }
    }

    public func openCount(inGroup name: String?) -> Int {
        items.filter { !$0.done && $0.group == name }.count
    }

    /// Renames a group and every to-do in it. Fails (returns false) for an
    /// empty name or one another group already uses; changing only the
    /// capitalisation of the same group is allowed.
    @discardableResult
    public func renameGroup(_ old: String, to raw: String) -> Bool {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let i = groups.firstIndex(where: { $0.name == old }) else { return false }
        if name == old { return true }
        let clash = groups.contains { $0.name != old && $0.name.caseInsensitiveCompare(name) == .orderedSame }
        guard !clash else { return false }
        groups[i].name = name
        for j in items.indices where items[j].group == old { items[j].group = name }
        scheduleSave()
        return true
    }

    public func setGroupColor(_ name: String, _ hex: String) {
        guard let i = groups.firstIndex(where: { $0.name == name }) else { return }
        groups[i].colorHex = hex
        scheduleSave()
    }

    /// Sets a group's emoji to the first extended grapheme cluster in `raw`.
    /// Empty or whitespace-only text is rejected and the current emoji stays.
    /// Pass nil to clear it, which brings the colour dot back.
    @discardableResult
    public func setGroupEmoji(_ name: String, _ raw: String?) -> Bool {
        guard let i = groups.firstIndex(where: { $0.name == name }) else { return false }
        if let raw {
            guard let emoji = TodoGroup.normalizedEmoji(raw) else { return false }
            groups[i].emoji = emoji
        } else {
            groups[i].emoji = nil
        }
        scheduleSave()
        return true
    }

    /// Steps a group's colour through `TodoGroup.colorChoices`.
    public func cycleGroupColor(_ name: String, by step: Int = 1) {
        guard let g = groups.first(where: { $0.name == name }) else { return }
        let choices = TodoGroup.colorChoices
        let current = choices.firstIndex(of: g.colorHex.uppercased()) ?? -1
        let next = ((current + step) % choices.count + choices.count) % choices.count
        setGroupColor(name, choices[next])
    }

    /// Moves a group earlier (-1) or later (+1); Board columns follow this order.
    public func moveGroup(_ name: String, by delta: Int) {
        guard let i = groups.firstIndex(where: { $0.name == name }) else { return }
        let j = i + delta
        guard groups.indices.contains(j) else { return }
        groups.swapAt(i, j)
        scheduleSave()
    }

    /// Deletes a group; its to-dos (open and done) move to `target` (nil = No group).
    public func deleteGroup(_ name: String, moveItemsTo target: String?) {
        guard groups.contains(where: { $0.name == name }), target != name else { return }
        groups.removeAll { $0.name == name }
        for j in items.indices where items[j].group == name { items[j].group = target }
        scheduleSave()
    }

    private func update(_ id: UUID, _ change: (inout TodoItem) -> Void) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        change(&items[i])
        scheduleSave()
    }

    // MARK: Persistence

    private func scheduleSave() {
        guard url != nil else { return }
        pendingSave?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.saveNow() }
        pendingSave = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    public func saveNow() {
        pendingSave?.cancel()
        pendingSave = nil
        guard let url else { return }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder.store.encode(StoreFile(items: items, groups: groups, notes: notes))
            try data.write(to: url, options: .atomic)
        } catch {
            NSLog("Todo: failed to save \(url.path): \(error)")
        }
    }
}

extension JSONEncoder {
    static var store: JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }
}

extension JSONDecoder {
    static var store: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}
