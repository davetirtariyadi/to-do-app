import Foundation

/// Calendar-day arithmetic on "yyyy-MM-dd" keys, done in UTC so it is
/// independent of the machine's time zone. Only `todayKey` looks at the clock.
public enum DayKey {
    private static let utc: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private static let monthsShort = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    private static let monthsLong = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    private static let weekdaysShort = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    /// Today's key in the user's local calendar.
    public static func todayKey(now: Date = Date(), calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: now)
        return key(year: c.year!, month: c.month!, day: c.day!)
    }

    public static func key(year: Int, month: Int, day: Int) -> String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    public static func parts(_ key: String) -> (year: Int, month: Int, day: Int) {
        let p = key.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return (1970, 1, 1) }
        return (p[0], p[1], p[2])
    }

    static func date(_ key: String) -> Date {
        let p = parts(key)
        return utc.date(from: DateComponents(year: p.year, month: p.month, day: p.day))!
    }

    static func key(_ date: Date) -> String {
        let c = utc.dateComponents([.year, .month, .day], from: date)
        return key(year: c.year!, month: c.month!, day: c.day!)
    }

    public static func addDays(_ key: String, _ n: Int) -> String {
        Self.key(utc.date(byAdding: .day, value: n, to: date(key))!)
    }

    /// Adds months, clamping the day to the target month's length (Jan 31 + 1 → Feb 28/29).
    public static func addMonths(_ key: String, _ n: Int) -> String {
        Self.key(utc.date(byAdding: .month, value: n, to: date(key))!)
    }

    /// 0 = Sunday … 6 = Saturday.
    public static func weekday(_ key: String) -> Int {
        utc.component(.weekday, from: date(key)) - 1
    }

    public static func daysInMonth(year: Int, month: Int) -> Int {
        let d = utc.date(from: DateComponents(year: year, month: month, day: 1))!
        return utc.range(of: .day, in: .month, for: d)!.count
    }

    public static func daysBetween(_ from: String, _ to: String) -> Int {
        utc.dateComponents([.day], from: date(from), to: date(to)).day!
    }

    public static func monthTitle(_ key: String) -> String {
        let p = parts(key)
        return "\(monthsLong[p.month - 1]) \(p.year)"
    }

    /// The weeks (Sunday-first) covering the month that contains `key`.
    public static func monthGrid(for key: String) -> [[String]] {
        let p = parts(key)
        let first = Self.key(year: p.year, month: p.month, day: 1)
        let lead = weekday(first)
        let count = daysInMonth(year: p.year, month: p.month)
        let weeks = Int((Double(lead + count) / 7).rounded(.up))
        let start = addDays(first, -lead)
        return (0..<weeks).map { w in (0..<7).map { d in addDays(start, w * 7 + d) } }
    }

    // MARK: Labels

    public enum Kind: Equatable { case none, overdue, today, tomorrow, later }

    public static func kind(_ key: String?, today: String) -> Kind {
        guard let key else { return .none }
        let diff = daysBetween(today, key)
        if diff < 0 { return .overdue }
        if diff == 0 { return .today }
        if diff == 1 { return .tomorrow }
        return .later
    }

    /// Compact label for list rows: "Oct 13", "Today", "Tmrw", "Oct 20".
    public static func shortLabel(_ key: String?, today: String) -> String {
        guard let key else { return "" }
        switch kind(key, today: today) {
        case .today: return "Today"
        case .tomorrow: return "Tmrw"
        default:
            let p = parts(key)
            return "\(monthsShort[p.month - 1]) \(p.day)"
        }
    }

    /// Longer label for cards: "Overdue · Oct 13", "Due today", "Tomorrow", "Oct 20".
    public static func longLabel(_ key: String?, today: String) -> String {
        guard let key else { return "" }
        let p = parts(key)
        let base = "\(monthsShort[p.month - 1]) \(p.day)"
        switch kind(key, today: today) {
        case .overdue: return "Overdue · \(base)"
        case .today: return "Due today"
        case .tomorrow: return "Tomorrow"
        default: return base
        }
    }

    /// Label for the date picker button: "No date", "Today", "Tomorrow", "Mon, Oct 19".
    public static func pickerLabel(_ key: String?, today: String) -> String {
        guard let key else { return "No date" }
        switch kind(key, today: today) {
        case .today: return "Today"
        case .tomorrow: return "Tomorrow"
        default:
            let p = parts(key)
            return "\(weekdaysShort[weekday(key)]), \(monthsShort[p.month - 1]) \(p.day)"
        }
    }

    /// The next Monday strictly after `today`.
    public static func nextMonday(after today: String) -> String {
        let wd = weekday(today)
        let ahead = (8 - wd) % 7
        return addDays(today, ahead == 0 ? 7 : ahead)
    }

    /// The coming Saturday (today if it is Saturday).
    public static func thisWeekend(from today: String) -> String {
        let wd = weekday(today)
        return addDays(today, (6 - wd + 7) % 7)
    }
}
