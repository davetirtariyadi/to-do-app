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

public struct TodoGroup: Codable, Identifiable, Equatable, Hashable {
    public var name: String
    public var colorHex: String
    public var id: String { name }

    public init(name: String, colorHex: String) {
        self.name = name
        self.colorHex = colorHex
    }

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
}
