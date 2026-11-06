import Foundation

struct ForecastPoint: Equatable, Sendable {
    var monthsFromNow: Double
    var hours: Double
}

struct ScenarioResult: Equatable, Sendable {
    /// Months from now until 10,000 h, nil if not reached within 30 years.
    var monthsToGoal: Double?
    var points: [ForecastPoint]
}

/// The two straight lines from today to 10,000 hours.
struct Forecast: Equatable, Sendable {
    /// At the chosen pace ("Your pace for the year") plus the What-if extra.
    var chosen: ScenarioResult
    /// At the recent pace (lifetime average blended with the last 12 weeks).
    var recent: ScenarioResult
    /// Hours a week behind each line.
    var chosenRate: Double
    var recentRate: Double

    /// The recent pace is as fast as the chosen one (or faster).
    var recentIsAsFast: Bool { recentRate >= chosenRate && chosenRate > 0 }
}

enum ForecastEngine {
    static let horizonYears = 30
    static let horizonMonths = horizonYears * 12
    static let daysPerMonth = 30.436875

    /// Hours added per month at a weekly rate.
    static func hoursPerMonth(weeklyRate: Double) -> Double { weeklyRate * daysPerMonth / 7 }

    /// A straight line from today at `weeklyRate` hours a week: finish = today + (10,000 − total) ÷ rate weeks.
    /// A rate of 0 (or a finish beyond 30 years) has no finish date; its line stops at the 30-year horizon.
    static func line(total: Double, weeklyRate: Double) -> ScenarioResult {
        let start = ForecastPoint(monthsFromNow: 0, hours: total)
        if total >= Totals.goalHours { return ScenarioResult(monthsToGoal: 0, points: [start]) }
        let perMonth = hoursPerMonth(weeklyRate: max(0, weeklyRate))
        let months = perMonth > 0 ? (Totals.goalHours - total) / perMonth : .infinity
        if months <= Double(horizonMonths) {
            return ScenarioResult(monthsToGoal: months,
                                  points: [start, ForecastPoint(monthsFromNow: months, hours: Totals.goalHours)])
        }
        return ScenarioResult(monthsToGoal: nil,
                              points: [start, ForecastPoint(monthsFromNow: Double(horizonMonths),
                                                            hours: total + perMonth * Double(horizonMonths))])
    }

    /// Both lines. The chosen line runs on `chosenPace + extra`; the recent line on `recentPace`.
    static func forecast(total: Double, chosenPace: Double, extra: Double = 0, recentPace: Double) -> Forecast {
        let chosenRate = max(0, chosenPace) + max(0, extra)
        return Forecast(chosen: line(total: total, weeklyRate: chosenRate),
                        recent: line(total: total, weeklyRate: recentPace),
                        chosenRate: chosenRate, recentRate: max(0, recentPace))
    }

    /// Pace the forecast runs on: the lifetime average (total hours ÷ weeks since
    /// the first estimate year began), nudged towards the recent logged pace as
    /// real entries arrive. Recent logging gets up to half the weight, reached
    /// after 12 weeks of data.
    static func forecastPace(total: Double, estimates: [YearRate], sessions: [SessionRecord], onboardingDate: Date,
                             now: Date, calendar: Calendar = .current) -> Double {
        guard let firstYear = estimates.map(\.year).min(),
              let start = calendar.date(from: DateComponents(year: firstYear, month: 1, day: 1)) else { return 0 }
        let weeksSinceStart = max(1, now.timeIntervalSince(start) / (7 * 86_400))
        let lifetime = total / weeksSinceStart
        let weeks = Pace.weeksOfData(onboardingDate: onboardingDate, now: now, calendar: calendar)
        guard weeks > 0 else { return lifetime }
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        let windowStart = now.addingTimeInterval(-weeks * 7 * 86_400)
        let recent = sessions.filter { $0.start >= windowStart && $0.start < endOfToday }.reduce(0) { $0 + $1.hours } / weeks
        let weight = 0.5 * weeks / Pace.windowWeeks
        return weight * recent + (1 - weight) * lifetime
    }

    static func date(afterMonths months: Double, from now: Date) -> Date {
        now.addingTimeInterval(months * daysPerMonth * 86_400)
    }

    /// Months the chosen-pace date moves earlier with `extra` h/week (nil if either never arrives).
    static func monthsSooner(total: Double, chosenPace: Double, extra: Double) -> Double? {
        guard let base = line(total: total, weeklyRate: chosenPace).monthsToGoal,
              let with = line(total: total, weeklyRate: chosenPace + max(0, extra)).monthsToGoal
        else { return nil }
        return base - with
    }
}

enum ForecastText {
    private static let months = ["January", "February", "March", "April", "May", "June", "July",
                                 "August", "September", "October", "November", "December"]

    static func monthYear(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month], from: date)
        return "\(months[(c.month ?? 1) - 1]) \(c.year ?? 0)"
    }

    /// "November 2035", or "After 2056" past 30 years.
    static func headline(_ result: ScenarioResult, now: Date, calendar: Calendar = .current) -> String {
        guard let m = result.monthsToGoal else {
            return "After \(calendar.component(.year, from: now) + ForecastEngine.horizonYears)"
        }
        return monthYear(ForecastEngine.date(afterMonths: m, from: now), calendar: calendar)
    }

    /// "2039", or "after 2056" past 30 years.
    static func year(_ result: ScenarioResult, now: Date, calendar: Calendar = .current) -> String {
        guard let m = result.monthsToGoal else {
            return "after \(calendar.component(.year, from: now) + ForecastEngine.horizonYears)"
        }
        return String(calendar.component(.year, from: ForecastEngine.date(afterMonths: m, from: now)))
    }

    /// The line under the headline: "At your recent pace: around 2039" / "…: after 2056", or, when the recent pace is
    /// as fast as the chosen one, "You're already playing at this pace".
    static func recentLine(_ forecast: Forecast, now: Date, calendar: Calendar = .current) -> String {
        if forecast.recentIsAsFast { return String(localized: "You're already playing at this pace") }
        if forecast.recent.monthsToGoal == nil {
            return String(localized: "At your recent pace: \(year(forecast.recent, now: now, calendar: calendar))")
        }
        return String(localized: "At your recent pace: around \(year(forecast.recent, now: now, calendar: calendar))")
    }

    /// "You crossed the finish line on 12 May 2035"
    static func crossed(on date: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        String(localized: "You crossed the finish line on \(ScrubText.day(date, calendar: calendar, locale: locale))")
    }

    private static let shortMonths = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    /// "~Nov 2035" at the end of the future-self track, or "after 2056" when it is more than 30 years away.
    static func shortFinish(_ result: ScenarioResult, now: Date, calendar: Calendar = .current) -> String {
        guard let m = result.monthsToGoal else { return year(result, now: now, calendar: calendar) }
        let c = calendar.dateComponents([.year, .month], from: ForecastEngine.date(afterMonths: m, from: now))
        return "~\(shortMonths[(c.month ?? 1) - 1]) \(c.year ?? 0)"
    }

    /// "~2036" on Home, or "after 2056" when it is more than 30 years away.
    static func homeMastery(_ result: ScenarioResult, now: Date, calendar: Calendar = .current) -> String {
        result.monthsToGoal == nil ? year(result, now: now, calendar: calendar) : "~" + year(result, now: now, calendar: calendar)
    }

    /// Under the What-if slider. With no extra: "On top of your chosen pace of 12 h a week."
    static func whatIf(extra: Double, total: Double, chosenPace: Double, now: Date, calendar: Calendar = .current) -> String {
        guard extra > 0 else {
            return String(localized: "On top of your chosen pace of \(WeeklyTarget.number(chosenPace)) h a week.")
        }
        let with = ForecastEngine.line(total: total, weeklyRate: chosenPace + extra)
        guard let sooner = ForecastEngine.monthsSooner(total: total, chosenPace: chosenPace, extra: extra) else {
            return "Around " + headline(with, now: now, calendar: calendar) + "."
        }
        let months = Int(sooner.rounded())
        let amount: String
        if months >= 12 {
            amount = String(format: "%.1f years", (sooner / 12 * 10).rounded() / 10)
        } else {
            amount = Labels.months(months)
        }
        return "About \(amount) sooner, around " + headline(with, now: now, calendar: calendar) + "."
    }
}
