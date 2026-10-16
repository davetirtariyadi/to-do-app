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
