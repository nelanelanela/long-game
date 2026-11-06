import Foundation

/// Everything Home and Growth show, computed from stored entities each time.
struct ProgressSummary: Sendable {
    var baseline: Double
    var logged: Double
    var total: Double
    var thisWeek: Double
    var pace: Double
    /// The recent pace the dotted line runs on (lifetime average blended with the last 12 weeks).
    var forecastPace: Double
    /// The weekly pace the user chose ("Your pace for the year"); the recent pace when none is set.
    var chosenPace: Double
    var forecast: Forecast
    var hasEnoughData: Bool

    var progress: Double { Totals.progress(total: total) }
    var percent: Int { Totals.percent(total: total) }
    var wholeHours: Int { Totals.wholeHours(total: total) }

    static func make(estimates: [YearRate], sessions: [SessionRecord], onboardingDate: Date,
                     weekStart: WeekStart, now: Date, extra: Double = 0, target: TargetRecord? = nil,
                     calendar: Calendar = .current) -> ProgressSummary {
        let baseline = Baseline.hours(estimates: estimates, onboardingDate: onboardingDate, calendar: calendar)
        let logged = Totals.loggedHours(sessions)
        let total = Totals.total(baseline: baseline, logged: logged)
        let latest = estimates.max(by: { $0.year < $1.year })?.hoursPerWeek ?? 0
        let pace = Pace.hoursPerWeek(sessions: sessions, latestEstimate: latest, onboardingDate: onboardingDate, now: now, calendar: calendar)
        // The recent pace: the lifetime average, adjusted by recent entries.
        let forecastPace = ForecastEngine.forecastPace(total: total, estimates: estimates, sessions: sessions,
                                                       onboardingDate: onboardingDate, now: now, calendar: calendar)
        // The finish line runs on the pace the user chose; without one, on the recent pace.
        let chosen = (target?.hoursPerWeek).flatMap { $0 > 0 ? $0 : nil } ?? forecastPace
        return ProgressSummary(
            baseline: baseline, logged: logged, total: total,
            thisWeek: WeekMath.thisWeekHours(sessions, now: now, weekStart: weekStart, calendar: calendar),
            pace: pace, forecastPace: forecastPace, chosenPace: chosen,
            forecast: ForecastEngine.forecast(total: total, chosenPace: chosen, extra: extra, recentPace: forecastPace),
            hasEnoughData: hasTwoWeeksOfData(sessions, now: now)
        )
    }

    /// "Forecast improves as you log more" shows until there are 2 weeks of logged data.
    static func hasTwoWeeksOfData(_ sessions: [SessionRecord], now: Date) -> Bool {
        guard let first = sessions.map(\.start).min() else { return false }
        return now.timeIntervalSince(first) >= 14 * 86_400
    }
}

enum SessionRules {
    static let maxDaySeconds = 24.0 * 3600
    /// A note is up to 500 characters (section 16 of the spec).
    static let maxNoteLength = 500

    /// The note cut to the limit (a pasted text can be longer).
    static func clampedNote(_ text: String) -> String {
        text.count > maxNoteLength ? String(text.prefix(maxNoteLength)) : text
    }

    /// What is saved: trimmed, and nil when nothing is left.
    static func savedNote(_ text: String) -> String? {
        let trimmed = clampedNote(text).trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// A day's total across all sessions cannot exceed 24 hours.
    static func fits(existingSecondsThatDay: Double, adding: Double) -> Bool {
        existingSecondsThatDay + adding <= maxDaySeconds
    }

    /// Manual sessions sit at 12:00 local on the chosen day.
    static func manualStart(on day: Date, calendar: Calendar = .current) -> Date {
        calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day
    }
}
