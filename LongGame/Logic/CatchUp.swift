import Foundation

/// "Welcome back": works out the days since the last session and how to spread
/// the hours the user says they played across them.
enum CatchUp {
    static let minGapDays = 7
    static let averageModeDays = 28
    static let promptEveryDays = 7
    static let maxWeeklyHours = Int(WeeklyTarget.maxHours)

    struct Gap: Equatable, Sendable, Identifiable {
        var id: Date { first }
        /// First and last day of the gap (start of day, inclusive).
        var first: Date
        var last: Date
        var days: Int
        /// The day the gap counts from: the last session day, or the onboarding day.
        var anchor: Date
        var hasSessions: Bool

        var weeks: Int { days / 7 }
        var usesAverage: Bool { days >= CatchUp.averageModeDays }
    }

    struct Block: Equatable, Sendable {
        var first: Date
        var last: Date
        var days: Int
    }

    /// The day after the last day with a session (or the onboarding day, with no sessions)
    /// up to yesterday. Nil when there are no days in between.
    static func gap(sessionStarts: [Date], onboardingDate: Date, today: Date, calendar: Calendar = .current) -> Gap? {
        let todayStart = calendar.startOfDay(for: today)
        let lastSessionDay = sessionStarts.map { calendar.startOfDay(for: $0) }.max()
        let anchor = lastSessionDay ?? calendar.startOfDay(for: onboardingDate)
        guard let first = lastSessionDay == nil ? anchor : calendar.date(byAdding: .day, value: 1, to: anchor),
              let last = calendar.date(byAdding: .day, value: -1, to: todayStart) else { return nil }
        let days = (calendar.dateComponents([.day], from: first, to: last).day ?? -1) + 1
        guard days > 0 else { return nil }
        return Gap(first: first, last: last, days: days, anchor: anchor, hasSessions: lastSessionDay != nil)
    }

    /// Asked at most once every 7 days.
    static func shouldPrompt(gap: Gap?, lastPromptAt: Date?, now: Date, calendar: Calendar = .current) -> Bool {
        guard let gap, gap.days >= minGapDays else { return false }
        guard let lastPromptAt else { return true }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: lastPromptAt),
                                           to: calendar.startOfDay(for: now)).day ?? 0
        return days >= promptEveryDays
    }

    /// 7-day blocks counting back from the last day of the gap. Leftover days
    /// (fewer than 7) join the oldest block. Returned oldest first.
    static func blocks(for gap: Gap, calendar: Calendar = .current) -> [Block] {
        let count = max(1, gap.days / 7)
        var result: [Block] = []
        var end = gap.last
        for index in 0..<count {
            let isOldest = index == count - 1
            let days = isOldest ? gap.days - 7 * (count - 1) : 7
            let start = calendar.date(byAdding: .day, value: -(days - 1), to: end) ?? end
            result.append(Block(first: start, last: end, days: days))
            end = calendar.date(byAdding: .day, value: -1, to: start) ?? start
        }
        return result.reversed()
    }

    /// Whole minutes for each day: hours split evenly, rounded to the minute, with the
    /// rounding remainder on the last day so the total matches exactly. When rounding
    /// would leave the last day negative (very long gaps, small hours), whole minutes
    /// are spread over the last days instead.
    static func dailyMinutes(totalHours: Double, days: Int) -> [Int] {
        guard days > 0 else { return [] }
        let total = max(0, Int((totalHours * 60).rounded()))
        let each = Int((Double(total) / Double(days)).rounded())
        let last = total - each * (days - 1)
        if last >= 0 { return Array(repeating: each, count: days - 1) + [last] }
        let base = total / days, extra = total % days
        return (0..<days).map { base + ($0 >= days - extra ? 1 : 0) }
    }

    /// Hours for the average mode: average hours a week over the whole gap.
    static func averageTotal(hoursPerWeek: Double, days: Int) -> Double {
        hoursPerWeek * Double(days) / 7
    }

    /// Stepper default: the current pace, rounded and kept in range.
    static func defaultHours(pace: Double) -> Int {
        min(maxWeeklyHours, max(0, Int(pace.rounded())))
    }

    /// Minutes a day on average for "about H h MM m a day".
    static func minutesPerDay(totalHours: Double, days: Int) -> Int {
        guard days > 0 else { return 0 }
        return Int((totalHours * 60 / Double(days)).rounded())
    }

    /// One entry per day: the day (start of day) and its whole minutes.
    static func plan(days: [Date], totalHours: Double) -> [(day: Date, minutes: Int)] {
        let minutes = dailyMinutes(totalHours: totalHours, days: days.count)
        return Array(zip(days, minutes)).map { (day: $0.0, minutes: $0.1) }
    }

    static func days(from first: Date, count: Int, calendar: Calendar = .current) -> [Date] {
        (0..<max(0, count)).compactMap { calendar.date(byAdding: .day, value: $0, to: first) }
    }

    /// 12:00 local on the given day.
    static func noon(of day: Date, calendar: Calendar = .current) -> Date {
        calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day
    }

    private static func formatter(_ format: String, _ calendar: Calendar) -> DateFormatter {
        CachedFormatter.pattern(format, calendar: calendar)
    }

    /// "3–10 Oct" within a month, "28 Sep – 4 Oct" across two.
    static func rangeLabel(first: Date, last: Date, calendar: Calendar = .current) -> String {
        let sameMonth = calendar.component(.month, from: first) == calendar.component(.month, from: last)
            && calendar.component(.year, from: first) == calendar.component(.year, from: last)
        if sameMonth {
            return formatter("d", calendar).string(from: first) + "–" + formatter("d MMM", calendar).string(from: last)
        }
        return formatter("d MMM", calendar).string(from: first) + " – " + formatter("d MMM", calendar).string(from: last)
    }

    /// "14 August"
    static func longDay(_ day: Date, calendar: Calendar = .current) -> String {
        formatter("d MMMM", calendar).string(from: day)
    }
}
