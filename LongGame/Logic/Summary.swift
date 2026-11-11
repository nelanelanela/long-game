import Foundation

/// Everything Home and Growth show, computed from stored entities each time.
struct ProgressSummary: Sendable {
    var baseline: Double
    var logged: Double
    var total: Double
    var thisWeek: Double
    var pace: Double
    /// The actual pace the dotted line runs on (lifetime average blended with the last 12 weeks).
    var forecastPace: Double
    /// The weekly pace the user chose ("Your pace for the year"); the actual pace when none is set.
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
        // The actual pace: the lifetime average, adjusted by recent entries.
        let forecastPace = ForecastEngine.forecastPace(total: total, estimates: estimates, sessions: sessions,
                                                       onboardingDate: onboardingDate, now: now, calendar: calendar)
        // The finish line runs on the pace the user chose; without one, on the actual pace.
        let chosen = (target?.hoursPerWeek).flatMap { $0 > 0 ? $0 : nil } ?? forecastPace
        return ProgressSummary(
            baseline: baseline, logged: logged, total: total,
            thisWeek: WeekMath.thisWeekHours(sessions, now: now, weekStart: weekStart, calendar: calendar),
            pace: pace, forecastPace: forecastPace, chosenPace: chosen,
            forecast: ForecastEngine.forecast(total: total, chosenPace: chosen, extra: extra, actualPace: forecastPace),
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

    /// The first day Add past hours offers: 1 January of the start year, so hours from before the onboarding
    /// date can be added too. An older session being edited keeps its own day.
    static func earliestDay(startYear: Int, onboardingDate: Date, editing: Date? = nil, calendar: Calendar = .current) -> Date {
        let onboarded = calendar.startOfDay(for: onboardingDate)
        let jan1 = calendar.date(from: DateComponents(year: startYear, month: 1, day: 1)).map { calendar.startOfDay(for: $0) } ?? onboarded
        let earliest = min(jan1, onboarded)
        guard let editing else { return earliest }
        return min(earliest, calendar.startOfDay(for: editing))
    }

    /// A day before the onboarding date: its hours add to the estimated starting score.
    static func isBeforeStart(_ day: Date, onboardingDate: Date, calendar: Calendar = .current) -> Bool {
        calendar.startOfDay(for: day) < calendar.startOfDay(for: onboardingDate)
    }

    /// Manual sessions sit at 12:00 local on the chosen day.
    static func manualStart(on day: Date, calendar: Calendar = .current) -> Date {
        calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day
    }
}
