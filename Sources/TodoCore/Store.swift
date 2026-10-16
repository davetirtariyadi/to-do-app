import Combine
import Foundation

/// Holds every to-do and group, and persists them to a JSON file.
/// All mutations are expected on the main thread.
public final class Store: ObservableObject {
    @Published public private(set) var items: [TodoItem]
    @Published public private(set) var groups: [TodoGroup]

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
        } else {
            items = []
            groups = TodoGroup.defaults
        }
    }

    public static func defaultURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Todo", isDirectory: true).appendingPathComponent("todos.json")
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
        guard let name, let g = groups.first(where: { $0.name == name }) else { return "#B9BFC9" }
        return g.colorHex
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
            let data = try JSONEncoder.store.encode(StoreFile(items: items, groups: groups))
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
