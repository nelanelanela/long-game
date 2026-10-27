import Foundation

enum Practice {
    /// Seconds per day, keyed by the start of the day a session began on
    /// (a session crossing midnight counts on the day it started).
    static func dailySeconds(_ sessions: [SessionRecord], calendar: Calendar = .current) -> [Date: Double] {
        var result: [Date: Double] = [:]
        for s in sessions {
            result[calendar.startOfDay(for: s.start), default: 0] += s.durationSec
        }
        return result
    }

    /// Days with any logged time in the inclusive range.
    static func activeDays(daily: [Date: Double], from: Date, to: Date, calendar: Calendar = .current) -> Int {
        let lo = calendar.startOfDay(for: from), hi = calendar.startOfDay(for: to)
        return daily.filter { $0.value > 0 && $0.key >= lo && $0.key <= hi }.count
    }
}

/// The gentle replacement for streaks: how many days a week the user usually
/// practises, and for how many weeks in a row they have kept to it. Nothing ever "breaks".
/// Catch-up sessions count like any other session.
enum Rhythm {
    /// The last 8 complete weeks plus the current one.
    static let lookbackWeeks = 8

    struct Result: Equatable, Sendable {
        /// Typical practice days per week (0 when there is nothing to go on).
        var daysPerWeek: Int
        /// Consecutive weeks with at least `daysPerWeek - 1` practice days (and never fewer than one).
        var steadyWeeks: Int
    }

    static func compute(daily: [Date: Double], since: Date, now: Date, weekStart: WeekStart,
                        calendar: Calendar = .current) -> Result {
        let cal = WeekMath.calendar(calendar, weekStart: weekStart)
        let thisWeek = WeekMath.startOfWeek(now, weekStart: weekStart, calendar: calendar)
        // Weeks before the user began (or first logged anything) are not rest weeks, they are not part of the story.
        let firstDay = min(cal.startOfDay(for: since), daily.filter { $0.value > 0 }.keys.min() ?? .distantFuture)
        let firstWeek = WeekMath.startOfWeek(firstDay, weekStart: weekStart, calendar: calendar)

        func practiceDays(inWeekStarting start: Date) -> Int {
            guard let end = cal.date(byAdding: .day, value: 7, to: start) else { return 0 }
            return daily.filter { $0.value > 0 && $0.key >= start && $0.key < end }.count
        }
        func week(_ back: Int) -> Date? { cal.date(byAdding: .weekOfYear, value: -back, to: thisWeek) }

        var recent: [Int] = []
        for back in 0...lookbackWeeks {
            guard let start = week(back), start >= firstWeek else { break }
            recent.append(practiceDays(inWeekStarting: start))
        }
        let sorted = recent.sorted()
        guard let rhythm = sorted.isEmpty ? nil : sorted[sorted.count / 2], rhythm > 0 else {
            return Result(daysPerWeek: 0, steadyWeeks: 0)
        }

        // At least one practice day, so a rhythm of 1 never counts rest weeks as steady.
        // The week in progress counts when it already keeps to the rhythm; it never ends the run early.
        let needed = max(1, rhythm - 1)
        var steady = 0
        var back = 0
        while let start = week(back), start >= firstWeek {
            if practiceDays(inWeekStarting: start) >= needed {
                steady += 1
            } else if back > 0 {
                break
            }
            back += 1
        }
        return Result(daysPerWeek: rhythm, steadyWeeks: steady)
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
