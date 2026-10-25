import Foundation

enum Streaks {
    /// Seconds per day, keyed by the start of the day a session began on
    /// (a session crossing midnight counts on the day it started).
    static func dailySeconds(_ sessions: [SessionRecord], calendar: Calendar = .current) -> [Date: Double] {
        var result: [Date: Double] = [:]
        for s in sessions {
            result[calendar.startOfDay(for: s.start), default: 0] += s.durationSec
        }
        return result
    }

    /// Consecutive days up to today, or up to yesterday if today has nothing yet.
    static func current(daily: [Date: Double], today: Date, calendar: Calendar = .current) -> Int {
        var day = calendar.startOfDay(for: today)
        if (daily[day] ?? 0) <= 0 {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }
        var count = 0
        while (daily[day] ?? 0) > 0 {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }

    static func longest(daily: [Date: Double], calendar: Calendar = .current) -> Int {
        let days = daily.filter { $0.value > 0 }.keys.sorted()
        var best = 0, run = 0
        var previous: Date?
        for day in days {
            if let p = previous, calendar.date(byAdding: .day, value: 1, to: p) == day {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
            previous = day
        }
        return best
    }

    /// Days with any logged time in the inclusive range.
    static func activeDays(daily: [Date: Double], from: Date, to: Date, calendar: Calendar = .current) -> Int {
        let lo = calendar.startOfDay(for: from), hi = calendar.startOfDay(for: to)
        return daily.filter { $0.value > 0 && $0.key >= lo && $0.key <= hi }.count
    }
}

enum CalendarLevel: Int, CaseIterable, Sendable {
    case rest, under1, from1to2, from2to3, over3

    /// 0 = rest, < 1 h, 1–2 h, 2–3 h, 3 h+
    static func level(hours: Double) -> CalendarLevel {
        switch hours {
        case ..<0.0001: .rest
        case ..<1: .under1
        case ..<2: .from1to2
        case ..<3: .from2to3
        default: .over3
        }
    }
}

enum CalendarGrid {
    /// `count` week columns ending with the week that contains `today`,
    /// each with 7 days starting on the chosen first weekday.
    static func weeks(endingOn today: Date, count: Int = 53, weekStart: WeekStart, calendar: Calendar = .current) -> [[Date]] {
        let cal = WeekMath.calendar(calendar, weekStart: weekStart)
        let thisWeek = WeekMath.startOfWeek(today, weekStart: weekStart, calendar: calendar)
        guard let first = cal.date(byAdding: .weekOfYear, value: -(count - 1), to: thisWeek) else { return [] }
        return (0..<count).map { w in
            (0..<7).compactMap { d in
                cal.date(byAdding: .day, value: w * 7 + d, to: first)
            }
        }
    }
}
