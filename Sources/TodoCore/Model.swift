import Foundation

/// A to-do. `date` is a calendar day key ("yyyy-MM-dd") rather than a timestamp,
/// so a due date never shifts when the Mac changes time zone.
public struct TodoItem: Codable, Identifiable, Equatable, Hashable {
    public var id: UUID
    public var title: String
    public var group: String?
    public var date: String?
    public var onToday: Bool
    public var done: Bool
    public var createdAt: Date
    public var doneAt: Date?

    public init(
        id: UUID = UUID(),
        title: String,
        group: String? = nil,
        date: String? = nil,
        onToday: Bool = false,
        done: Bool = false,
        createdAt: Date = Date(),
        doneAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.group = group
        self.date = date
        self.onToday = onToday
        self.done = done
        self.createdAt = createdAt
        self.doneAt = doneAt
    }
}

/// A one-line thought. Not a to-do: it stays out of Today, the to-do catch-up deck, and the menu-bar count.
public struct Note: Codable, Identifiable, Equatable, Hashable {
    public var id: UUID
    public var text: String
    public var createdAt: Date

    public init(id: UUID = UUID(), text: String, createdAt: Date = Date()) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
    }
}

public struct TodoGroup: Codable, Identifiable, Equatable, Hashable {
    public var name: String
    public var colorHex: String
    /// One extended grapheme cluster the user chose, or nil to keep the colour dot.
    public var emoji: String?
    public var id: String { name }

    public init(name: String, colorHex: String, emoji: String? = nil) {
        self.name = name
        self.colorHex = colorHex
        self.emoji = emoji
    }

    /// The first extended grapheme cluster in `raw`, or nil when it is blank.
    /// Skin-tone and ZWJ sequences count as one cluster.
    public static func normalizedEmoji(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let cluster = trimmed.first else { return nil }
        return String(cluster)
    }

    private enum CodingKeys: String, CodingKey {
        case name, colorHex, emoji
    }

    /// Missing `emoji` stays nil so a file written before this field still loads.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        colorHex = try c.decode(String.self, forKey: .colorHex)
        emoji = try c.decodeIfPresent(String.self, forKey: .emoji).flatMap(Self.normalizedEmoji)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(name, forKey: .name)
        try c.encode(colorHex, forKey: .colorHex)
        try c.encodeIfPresent(emoji, forKey: .emoji)
    }

    /// Dot colour for a to-do that has no group.
    public static let ungroupedHex = "#A39888"

    public static let defaults: [TodoGroup] = [
        TodoGroup(name: "Work", colorHex: "#2B59C3"),
        TodoGroup(name: "Home", colorHex: "#0F766E"),
        TodoGroup(name: "Errands", colorHex: "#7E3AF2"),
    ]

    /// Colours handed out to groups created in the app, in order.
    public static let palette = ["#B45309", "#BE185D", "#4D7C0F", "#0369A1", "#9333EA", "#0F766E"]

    /// Every colour a group can cycle through on the Groups screen.
    public static let colorChoices = ["#2B59C3", "#0F766E", "#7E3AF2", "#B45309", "#BE185D", "#4D7C0F", "#0369A1", "#9333EA"]
}

/// On-disk shape of todos.json.
struct StoreFile: Codable {
    var version: Int = 1
    var items: [TodoItem]
    var groups: [TodoGroup]
    var notes: [Note]

    init(version: Int = 1, items: [TodoItem], groups: [TodoGroup], notes: [Note] = []) {
        self.version = version
        self.items = items
        self.groups = groups
        self.notes = notes
    }

    private enum CodingKeys: String, CodingKey {
        case version, items, groups, notes
    }

    /// A file written before notes existed has no `notes` key. Failing the whole
    /// decode would drop every to-do, so a missing key means an empty list.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        items = try c.decode([TodoItem].self, forKey: .items)
        groups = try c.decode([TodoGroup].self, forKey: .groups)
        notes = try c.decodeIfPresent([Note].self, forKey: .notes) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(version, forKey: .version)
        try c.encode(items, forKey: .items)
        try c.encode(groups, forKey: .groups)
        try c.encode(notes, forKey: .notes)
    }
}
