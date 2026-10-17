import Foundation
import Testing
@testable import TodoCore

@Suite struct DayKeyTests {
    @Test func addDaysCrossesMonthAndYear() {
        #expect(DayKey.addDays("2026-10-31", 1) == "2026-11-01")
        #expect(DayKey.addDays("2026-12-31", 1) == "2027-01-01")
        #expect(DayKey.addDays("2026-03-01", -1) == "2026-02-28")
    }

    @Test func addMonthsClampsDay() {
        #expect(DayKey.addMonths("2026-01-31", 1) == "2026-02-28")
        #expect(DayKey.addMonths("2026-10-15", -1) == "2026-09-15")
    }

    @Test func weekdayAndShortcuts() {
        #expect(DayKey.weekday("2026-10-15") == 4) // Thursday
        #expect(DayKey.nextMonday(after: "2026-10-15") == "2026-10-19")
        #expect(DayKey.nextMonday(after: "2026-10-19") == "2026-10-26")
        #expect(DayKey.thisWeekend(from: "2026-10-15") == "2026-10-17")
    }

    @Test func monthGridIsSundayFirst() {
        let grid = DayKey.monthGrid(for: "2026-10-15")
        #expect(grid.count == 5)
        #expect(grid[0][0] == "2026-09-27")
        #expect(grid[0][4] == "2026-10-01")
        #expect(grid.allSatisfy { $0.count == 7 })
    }

    @Test func labels() {
        let t = "2026-10-15"
        #expect(DayKey.kind("2026-10-13", today: t) == .overdue)
        #expect(DayKey.longLabel("2026-10-13", today: t) == "Overdue · Oct 13")
        #expect(DayKey.shortLabel("2026-10-16", today: t) == "Tmrw")
        #expect(DayKey.pickerLabel("2026-10-19", today: t) == "Mon, Oct 19")
        #expect(DayKey.pickerLabel(nil, today: t) == "No date")
    }
}

@Suite struct StoreTests {
    @Test func onlyReleaseBundleUsesRealData() {
        #expect(Store.defaultURL(bundleID: "com.local.todo").path.hasSuffix("/Todo/todos.json"))
        #expect(Store.defaultURL(bundleID: "com.local.todo.dev").path.hasSuffix("/Todo-dev/todos.json"))
        #expect(Store.defaultURL(bundleID: nil).path.hasSuffix("/Todo-dev/todos.json"))
    }

    func makeStore() -> Store {
        let s = Store(url: nil)
        s.todayProvider = { "2026-10-15" }
        return s
    }

    @Test func rejectsBlankTitles() {
        let s = makeStore()
        #expect(s.add(title: "   ", group: nil, date: nil, onToday: false) == nil)
        #expect(s.items.isEmpty)
    }

    @Test func catchUpDeckIsTodayPlusDue() {
        let s = makeStore()
        s.add(title: "on today", group: nil, date: nil, onToday: true)
        s.add(title: "overdue", group: nil, date: "2026-10-13", onToday: false)
        s.add(title: "due today", group: nil, date: "2026-10-15", onToday: false)
        s.add(title: "later", group: nil, date: "2026-10-20", onToday: false)
        let finished = s.add(title: "done today", group: nil, date: nil, onToday: true)!
        s.setDone(finished.id, true)

        let titles = s.catchUpDeck.map(\.title)
        #expect(Set(titles) == ["on today", "overdue", "due today"])
        #expect(titles.first == "overdue") // dated items sort earliest first
        #expect(s.dueNotOnToday.map(\.title) == ["overdue", "due today"])
    }

    @Test func groupsDedupeCaseInsensitively() {
        let s = makeStore()
        let g = s.addGroup(named: "work")
        #expect(g?.name == "Work")
        #expect(s.groups.count == 3)
        #expect(s.addGroup(named: " Side project ")?.name == "Side project")
        #expect(s.groups.count == 4)
    }

    @Test func renameCarriesItemsAndRejectsClashes() {
        let s = makeStore()
        let a = s.add(title: "a", group: "Errands", date: nil, onToday: false)!
        #expect(s.renameGroup("Errands", to: "Shopping"))
        #expect(s.item(a.id)?.group == "Shopping")
        #expect(!s.renameGroup("Shopping", to: "work"))   // clashes with Work
        #expect(!s.renameGroup("Shopping", to: "  "))
        #expect(s.renameGroup("Shopping", to: "shopping")) // case-only change is fine
        #expect(s.groups.map(\.name) == ["Work", "Home", "shopping"])
    }

    @Test func deleteMovesItemsAndReorderWorks() {
        let s = makeStore()
        let a = s.add(title: "a", group: "Home", date: nil, onToday: false)!
        let b = s.add(title: "b", group: "Home", date: nil, onToday: false)!
        s.setDone(b.id, true)
        s.deleteGroup("Home", moveItemsTo: "Work")
        #expect(s.item(a.id)?.group == "Work")
        #expect(s.item(b.id)?.group == "Work")
        #expect(s.groups.map(\.name) == ["Work", "Errands"])

        s.deleteGroup("Errands", moveItemsTo: nil)
        s.addGroup(named: "Garden")
        s.moveGroup("Garden", by: -1)
        #expect(s.groups.map(\.name) == ["Garden", "Work"])
        s.moveGroup("Garden", by: -1) // already first: no-op
        #expect(s.groups.first?.name == "Garden")
    }

    @Test func colourCyclesAndItemsChangeGroup() {
        let s = makeStore()
        s.cycleGroupColor("Work")
        #expect(s.groups[0].colorHex == TodoGroup.colorChoices[1])
        s.cycleGroupColor("Work", by: -2)
        #expect(s.groups[0].colorHex == TodoGroup.colorChoices.last)
        let a = s.add(title: "a", group: nil, date: nil, onToday: false)!
        s.setGroup(a.id, "Home")
        #expect(s.openCount(inGroup: "Home") == 1)
        s.setGroup(a.id, nil)
        #expect(s.openCount(inGroup: nil) == 1)
    }

    @Test func groupEmojiKeepsOneClusterAndRejectsBlank() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let url = dir.appendingPathComponent("todos.json")
        defer { try? FileManager.default.removeItem(at: dir) }

        let s = Store(url: url)
        #expect(!s.setGroupEmoji("Work", ""))
        #expect(!s.setGroupEmoji("Work", " \n\t"))
        #expect(s.groups[0].emoji == nil)

        #expect(s.setGroupEmoji("Work", "👍🏽 later"))
        #expect(s.groups[0].emoji == "👍🏽")
        #expect(s.groups[0].emoji?.count == 1)

        #expect(s.setGroupEmoji("Home", "👩‍💻 extra"))
        let home = s.groups.first { $0.name == "Home" }
        #expect(home?.emoji == "👩‍💻")
        #expect(home?.emoji?.count == 1)

        #expect(!s.setGroupEmoji("Work", "   "))
        #expect(s.groups[0].emoji == "👍🏽")
        #expect(!s.setGroupEmoji("Missing", "🔥"))

        #expect(s.setGroupEmoji("Work", nil))
        #expect(s.groups[0].emoji == nil)

        s.setGroupEmoji("Errands", "📦📦")
        s.saveNow()
        let reloaded = Store(url: url)
        #expect(reloaded.groups.first { $0.name == "Errands" }?.emoji == "📦")
        #expect(reloaded.groups.first { $0.name == "Work" }?.emoji == nil)
        #expect(reloaded.groups.first { $0.name == "Home" }?.emoji == "👩‍💻")
    }

    @Test func legacyFileWithoutEmojiKeyStillLoads() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let url = dir.appendingPathComponent("todos.json")
        defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let json = """
        {
          "version": 1,
          "items": [
            {
              "id": "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE",
              "title": "Still here",
              "onToday": true,
              "done": false,
              "createdAt": "2026-10-15T15:00:00Z"
            }
          ],
          "groups": [
            { "name": "Work", "colorHex": "#2B59C3" },
            { "name": "Home", "colorHex": "#0F766E" }
          ]
        }
        """
        try Data(json.utf8).write(to: url)

        let s = Store(url: url)
        #expect(s.items.map(\.title) == ["Still here"])
        #expect(s.items[0].onToday)
        #expect(s.groups.map(\.name) == ["Work", "Home"])
        #expect(s.groups.allSatisfy { $0.emoji == nil })
    }

    @Test func savesAndReloads() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let url = dir.appendingPathComponent("todos.json")
        defer { try? FileManager.default.removeItem(at: dir) }

        let a = Store(url: url)
        let item = a.add(title: "Persist me", group: "Home", date: "2026-10-16", onToday: true)!
        a.addGroup(named: "Garden")
        a.toggleDone(item.id)
        a.saveNow()

        let b = Store(url: url)
        #expect(b.items.count == 1)
        #expect(b.items[0].title == "Persist me")
        #expect(b.items[0].done)
        #expect(b.items[0].date == "2026-10-16")
        #expect(b.groups.map(\.name).contains("Garden"))
    }
}
