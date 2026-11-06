import Foundation

// Your pace for the year: a weekly target for the next 12 months, counted from the day it is set.
// Pure functions only; saving it is in `TargetSaving`, showing it in `WeeklyTargetView`.

/// One weekly target and the 12 months it covers.
struct TargetRecord: Equatable, Sendable {
    var hoursPerWeek: Double
    var start: Date
    /// The first day *after* the year of pace: it runs from `start` up to this day.
    var end: Date
}

enum WeeklyTarget {
    /// Every hour of a week.
    static let maxHours = 168.0
    static let range: ClosedRange<Double> = 1...maxHours
    static let step = 0.5
    /// The reminder appears this many days before the year ends.
    static let reminderLeadDays = 14

    /// Into the slider's range, in steps of half an hour.
    static func clamped(_ hours: Double) -> Double {
        let stepped = (hours / step).rounded() * step
        return min(range.upperBound, max(range.lowerBound, stepped))
    }

    /// Where the slider starts: the recent pace, rounded to whole hours.
    static func suggested(pace: Double) -> Double { clamped(pace.rounded()) }

    /// Counted from the day it is set, not from the calendar year.
    static func startDay(_ now: Date, calendar: Calendar = .current) -> Date { calendar.startOfDay(for: now) }

    /// Set date + 12 months.
    static func endDate(from start: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .month, value: 12, to: calendar.startOfDay(for: start)) ?? start.addingTimeInterval(365 * 86_400)
    }

    /// What a year of this pace adds: target × 52 weeks.
    static func addedHours(_ target: Double) -> Double { target * 52 }

    /// What the weekly target still adds before its year ends ("+624 h" on the first day): 52 weeks of it, less the
    /// share of the year already gone. Nil when there is no target or its year is over.
    static func addedByEnd(_ target: TargetRecord?, now: Date, calendar: Calendar = .current) -> Double? {
        guard let target, target.hoursPerWeek > 0, now < target.end else { return nil }
        let today = calendar.startOfDay(for: now)
        let total = calendar.dateComponents([.day], from: calendar.startOfDay(for: target.start), to: target.end).day ?? 365
        let left = calendar.dateComponents([.day], from: today, to: target.end).day ?? 0
        guard total > 0 else { return nil }
        return addedHours(target.hoursPerWeek) * min(1, max(0, Double(left) / Double(total)))
    }

    /// "1 h 43 m a day": the weekly target spread over seven days.
    static func perDay(_ target: Double) -> String {
        DurationFormat.short(seconds: target / 7 * 3600) + " a day"
    }

    /// "12" or "12.5": no decimals when whole.
    static func number(_ hours: Double) -> String {
        let rounded = (hours * 10).rounded() / 10
        return rounded == rounded.rounded() ? String(Int(rounded)) : String(format: "%.1f", rounded)
    }
}

/// The current target plus the finished ones, so a past week is judged against the target of its time.
enum TargetHistory {
    /// The year of pace that a new target closes today. The old one carries on until a new one is set, so it ends
    /// today even when its twelve months were already over. Nil when it started today (it is simply replaced).
    static func closing(_ current: TargetRecord?, on now: Date, calendar: Calendar = .current) -> TargetRecord? {
        guard var old = current, old.hoursPerWeek > 0 else { return nil }
        let today = calendar.startOfDay(for: now)
        guard old.start < today else { return nil }
        old.end = today
        return old
    }

    /// The target in force on a day: the latest one that had started by then. Nil before the first.
    static func hours(on date: Date, periods: [TargetRecord], current: TargetRecord?) -> Double? {
        (periods + [current].compactMap { $0 })
            .filter { $0.start <= date }
            .max { $0.start < $1.start }?
            .hoursPerWeek
    }

    /// A week is judged against the target in force on its last day, so a change made during the week counts for it.
    static func hours(forWeekStarting weekStart: Date, periods: [TargetRecord], current: TargetRecord?,
                      calendar: Calendar = .current) -> Double? {
        let lastDay = calendar.date(byAdding: .day, value: 6, to: calendar.startOfDay(for: weekStart)) ?? weekStart
        return hours(on: lastDay, periods: periods, current: current)
    }
}

/// Where the year of pace stands: nothing chosen yet, running, in its last two weeks, or over.
enum TargetCycle {
    enum Phase: Equatable {
        case notSet
        case running
        case endingSoon(daysLeft: Int)
        case ended
    }

    static func phase(_ target: TargetRecord?, now: Date, calendar: Calendar = .current) -> Phase {
        guard let target, target.hoursPerWeek > 0 else { return .notSet }
        guard now < target.end else { return .ended }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: target.end)).day ?? 0
        return days <= WeeklyTarget.reminderLeadDays ? .endingSoon(daysLeft: days) : .running
    }

    /// Shown in the target row from 14 days before the end, and after it until a new target is set.
    static func reminder(_ target: TargetRecord?, now: Date, calendar: Calendar = .current) -> String? {
        guard let target else { return nil }
        switch phase(target, now: now, calendar: calendar) {
        case .endingSoon: return "Your year of pace ends on \(DateText.dayMonth(target.end, now: now, calendar: calendar)). Choose the next one."
        case .ended: return "Your year of pace ended on \(DateText.dayMonth(target.end, now: now, calendar: calendar)). Choose the next one."
        case .notSet, .running: return nil
        }
    }

    /// The target screen opens on its own as a sheet once: on the first open after the year ends, or once for a
    /// game that never had a target. Dismissing it leaves the reminder in the target row.
    static func shouldOpenSheet(_ target: TargetRecord?, promptShownAt: Date?, now: Date, calendar: Calendar = .current) -> Bool {
        switch phase(target, now: now, calendar: calendar) {
        case .notSet: return promptShownAt == nil
        case .ended: return promptShownAt.map { $0 < (target?.end ?? .distantFuture) } ?? true
        case .running, .endingSoon: return false
        }
    }
}

/// How the current week stands against the target: the lines of the target row.
struct WeekTarget: Equatable {
    var hoursThisWeek: Double
    var target: Double
    var daysLeft: Int

    /// 0...1 of the target (the sun's height on the This week tab is this, capped).
    var fraction: Double { target > 0 ? min(1, max(0, hoursThisWeek / target)) : 0 }
    /// Whole percent of the target, not capped above: 54 for 6.5 of 12, 112 for 13.5. Never 100 before the target is reached.
    var percent: Int {
        guard target > 0 else { return 0 }
        let rounded = Int((hoursThisWeek / target * 100).rounded())
        return reached ? max(100, rounded) : min(99, rounded)
    }
    var reached: Bool { target > 0 && hoursThisWeek >= target }
    var toGo: Double { max(0, target - hoursThisWeek) }
    var over: Double { max(0, hoursThisWeek - target) }

    /// Days after today until the week ends: 3 on a Thursday when weeks start on Monday.
    static func daysLeft(now: Date, weekStart: WeekStart, calendar: Calendar = .current) -> Int {
        let start = WeekMath.startOfWeek(now, weekStart: weekStart, calendar: calendar)
        let today = calendar.dateComponents([.day], from: start, to: calendar.startOfDay(for: now)).day ?? 0
        return max(0, 6 - today)
    }

    static func make(hoursThisWeek: Double, target: Double, now: Date, weekStart: WeekStart,
                     calendar: Calendar = .current) -> WeekTarget {
        WeekTarget(hoursThisWeek: hoursThisWeek, target: target,
                   daysLeft: daysLeft(now: now, weekStart: weekStart, calendar: calendar))
    }

    /// "3 days left", "1 day left" or "last day".
    var daysLeftText: String {
        switch daysLeft {
        case 0: "last day"
        case 1: "1 day left"
        default: "\(daysLeft) days left"
        }
    }

    /// "5.5 h to go · 3 days left", or "Target reached · +1.5 h" once passed.
    var headline: String {
        if reached { return "Target reached · +\(DurationFormat.hours(over))" }
        return "\(DurationFormat.hours(toGo)) to go · \(daysLeftText)"
    }
}

enum DateText {
    private static func formatter(_ format: String, _ calendar: Calendar) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_GB")
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.dateFormat = format
        return f
    }

    /// "Nov 2027"
    static func monthYear(_ date: Date, calendar: Calendar = .current) -> String {
        formatter("MMM yyyy", calendar).string(from: date)
    }

    /// "2 Nov 2027"
    static func dayMonthYear(_ date: Date, calendar: Calendar = .current) -> String {
        formatter("d MMM yyyy", calendar).string(from: date)
    }

    /// "2 Nov", and the year too when it is not this year.
    static func dayMonth(_ date: Date, now: Date, calendar: Calendar = .current) -> String {
        let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: now)
        return formatter(sameYear ? "d MMM" : "d MMM yyyy", calendar).string(from: date)
    }
}
