import Foundation

/// Everything Home and Growth show, computed from stored entities each time.
struct ProgressSummary: Sendable {
    var baseline: Double
    var logged: Double
    var total: Double
    var thisWeek: Double
    var pace: Double
    var forecastPace: Double
    var trend: Double
    var yearlyRates: [YearRate]
    var forecast: Forecast
    var hasEnoughData: Bool
    /// Set while the mid forecast runs on the weekly target (the recent pace is within 25% of it).
    var forecastTarget: ForecastTarget?

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
        let yearly = ForecastEngine.yearlyRates(estimates: estimates, sessions: sessions, onboardingDate: onboardingDate, now: now, calendar: calendar)
        let trend = ForecastEngine.trend(yearly: yearly)
        // The forecast runs on the lifetime average, adjusted by recent entries;
        // a falling trend is not extrapolated into the future.
        let forecastPace = ForecastEngine.forecastPace(total: total, estimates: estimates, sessions: sessions,
                                                       onboardingDate: onboardingDate, now: now, calendar: calendar)
        // For the 12 months of the weekly target the mid line runs on it, if the recent pace is close to it.
        let window = WeeklyTarget.forecastWindow(target: target, pace: pace, now: now)
        return ProgressSummary(
            baseline: baseline, logged: logged, total: total,
            thisWeek: WeekMath.thisWeekHours(sessions, now: now, weekStart: weekStart, calendar: calendar),
            pace: pace, forecastPace: forecastPace, trend: trend, yearlyRates: yearly,
            forecast: ForecastEngine.forecast(total: total, pace: forecastPace, trend: max(0, trend), extra: extra, target: window),
            hasEnoughData: hasTwoWeeksOfData(sessions, now: now),
            forecastTarget: window
        )
    }

    /// The mid finish if the next 12 months ran on this weekly target, whatever the recent pace is: the
    /// "In a year" line of the target screen shows what a target would do, before it is chosen.
    func finish(ifTarget hours: Double, months: Double = 12) -> ScenarioResult {
        ForecastEngine.simulate(.mid, total: total, pace: forecastPace, trend: max(0, trend),
                                target: ForecastTarget(hoursPerWeek: hours, monthsRemaining: months))
    }

    /// "Forecast improves as you log more" shows until there are 2 weeks of logged data.
    static func hasTwoWeeksOfData(_ sessions: [SessionRecord], now: Date) -> Bool {
        guard let first = sessions.map(\.start).min() else { return false }
        return now.timeIntervalSince(first) >= 14 * 86_400
    }
}

enum SessionRules {
    static let maxDaySeconds = 24.0 * 3600
    static let maxNoteLength = 280

    /// A day's total across all sessions cannot exceed 24 hours.
    static func fits(existingSecondsThatDay: Double, adding: Double) -> Bool {
        existingSecondsThatDay + adding <= maxDaySeconds
    }

    /// Manual sessions sit at 12:00 local on the chosen day.
    static func manualStart(on day: Date, calendar: Calendar = .current) -> Date {
        calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day
    }
}
