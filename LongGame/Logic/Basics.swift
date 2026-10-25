import Foundation

/// Plain value types the Logic code works with, so it never touches SwiftData.
struct SessionRecord: Equatable, Sendable {
    var start: Date
    var durationSec: Double
    var hours: Double { durationSec / 3600 }
}

struct YearRate: Equatable, Sendable {
    var year: Int
    var hoursPerWeek: Double
}

enum WeekStart: String, Codable, Sendable, CaseIterable {
    case monday, sunday

    var firstWeekday: Int { self == .monday ? 2 : 1 }

    static var localeDefault: WeekStart {
        Calendar.current.firstWeekday == 1 ? .sunday : .monday
    }
}

enum Totals {
    static let goalHours = 10_000.0

    static func loggedHours(_ sessions: [SessionRecord]) -> Double {
        sessions.reduce(0) { $0 + $1.hours }
    }

    static func total(baseline: Double, logged: Double) -> Double { baseline + logged }

    /// 0...1, capped. The app keeps counting past it.
    static func progress(total: Double) -> Double { min(1, max(0, total / goalHours)) }

    static func wholeHours(total: Double) -> Int { Int(max(0, total).rounded(.down)) }

    /// Rounded, but never shows 100% before the goal is really reached.
    static func percent(total: Double) -> Int {
        if total >= goalHours { return 100 }
        return min(99, Int((progress(total: total) * 100).rounded()))
    }
}

enum Baseline {
    /// Full past years count 52 weeks each; the onboarding year counts the
    /// weeks elapsed before the onboarding date.
    static func hours(estimates: [YearRate], onboardingDate: Date, calendar: Calendar = .current) -> Double {
        let onboardingYear = calendar.component(.year, from: onboardingDate)
        var total = 0.0
        for e in estimates {
            if e.year < onboardingYear {
                total += e.hoursPerWeek * 52
            } else if e.year == onboardingYear {
                total += e.hoursPerWeek * weeksElapsedInYear(of: onboardingDate, calendar: calendar)
            }
        }
        return total
    }

    static func weeksElapsedInYear(of date: Date, calendar: Calendar = .current) -> Double {
        let year = calendar.component(.year, from: date)
        guard let jan1 = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) else { return 0 }
        let days = calendar.dateComponents([.day], from: jan1, to: calendar.startOfDay(for: date)).day ?? 0
        return Double(days) / 7
    }
}

enum WeekMath {
    static func calendar(_ base: Calendar, weekStart: WeekStart) -> Calendar {
        var c = base
        c.firstWeekday = weekStart.firstWeekday
        return c
    }

    static func startOfWeek(_ date: Date, weekStart: WeekStart, calendar: Calendar = .current) -> Date {
        let c = Self.calendar(calendar, weekStart: weekStart)
        return c.dateInterval(of: .weekOfYear, for: date)?.start ?? c.startOfDay(for: date)
    }

    /// Logged hours since the start of the current week.
    static func thisWeekHours(_ sessions: [SessionRecord], now: Date, weekStart: WeekStart, calendar: Calendar = .current) -> Double {
        let start = startOfWeek(now, weekStart: weekStart, calendar: calendar)
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? now
        return sessions.filter { $0.start >= start && $0.start < end }.reduce(0) { $0 + $1.hours }
    }
}

enum Pace {
    static let windowWeeks = 12.0

    static func weeksOfData(onboardingDate: Date, now: Date, calendar: Calendar = .current) -> Double {
        let days = now.timeIntervalSince(calendar.startOfDay(for: onboardingDate)) / 86_400
        return min(windowWeeks, max(0, days / 7))
    }

    /// Average weekly logged hours over the last 12 weeks. While there is less
    /// than 12 weeks of data it blends with the latest estimate.
    static func hoursPerWeek(sessions: [SessionRecord], latestEstimate: Double, onboardingDate: Date, now: Date, calendar: Calendar = .current) -> Double {
        let weeks = weeksOfData(onboardingDate: onboardingDate, now: now, calendar: calendar)
        guard weeks > 0 else { return latestEstimate }
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        let windowStart = now.addingTimeInterval(-weeks * 7 * 86_400)
        let logged = sessions.filter { $0.start >= windowStart && $0.start < endOfToday }.reduce(0) { $0 + $1.hours }
        let weight = weeks / windowWeeks
        return weight * (logged / weeks) + (1 - weight) * latestEstimate
    }
}
