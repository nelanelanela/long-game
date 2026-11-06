import Foundation

struct CumulativePoint: Equatable, Sendable {
    var date: Date
    var hours: Double
}

/// Everything the Growth chart draws.
struct GrowthChartData: Sendable {
    var past: [CumulativePoint]
    /// The dashed line at the chosen pace, from today to its finish (or the 30-year horizon).
    var chosen: [CumulativePoint]
    /// The dotted line at the actual pace, from today to its finish (or the 30-year horizon).
    var actual: [CumulativePoint]
    /// Where the chosen pace reaches 10,000 h (the sun), nil when it does not within 30 years.
    var chosenDate: Date?
    var xStart: Date
    var xEnd: Date
}

enum GrowthSeries {
    /// Cumulative hours over time: the estimate curve (frozen at onboarding)
    /// plus every logged session as it happened.
    static func past(estimates: [YearRate], sessions: [SessionRecord], onboardingDate: Date,
                     startYear: Int, now: Date, calendar: Calendar = .current) -> [CumulativePoint] {
        let onboardingYear = calendar.component(.year, from: onboardingDate)
        var dates: Set<Date> = []
        for year in startYear...max(startYear, onboardingYear) {
            if let jan1 = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) { dates.insert(jan1) }
        }
        dates.insert(onboardingDate)
        dates.insert(now)
        for s in sessions { dates.insert(calendar.startOfDay(for: s.start)) }

        let sorted = sessions.sorted { $0.start < $1.start }
        let ordered = dates.filter { $0 <= now }.sorted()
        var points: [CumulativePoint] = []
        var cursor = 0
        var logged = 0.0
        for date in ordered {
            // sessions of the day count at the end of that day
            let cutoff = calendar.isDate(date, equalTo: calendar.startOfDay(for: date), toGranularity: .second)
                ? (calendar.date(byAdding: .day, value: 1, to: date) ?? date) : date
            while cursor < sorted.count, sorted[cursor].start < cutoff {
                logged += sorted[cursor].hours
                cursor += 1
            }
            let baseline = Baseline.hours(estimates: estimates, onboardingDate: min(date, onboardingDate), calendar: calendar)
            points.append(CumulativePoint(date: date, hours: baseline + logged))
        }
        return points
    }

    static func chartData(forecast: Forecast, past: [CumulativePoint], now: Date, calendar: Calendar = .current) -> GrowthChartData {
        func dated(_ r: ScenarioResult) -> [CumulativePoint] {
            r.points.map { CumulativePoint(date: ForecastEngine.date(afterMonths: $0.monthsFromNow, from: now), hours: $0.hours) }
        }
        // The chart runs to the later of the two finishes (30 years at most), plus half a year of room for the sun.
        let chosenMonths = forecast.chosen.monthsToGoal ?? Double(ForecastEngine.horizonMonths)
        let actualMonths = forecast.actual.monthsToGoal ?? Double(ForecastEngine.horizonMonths)
        let lastMonths = max(chosenMonths, actualMonths, 12)
        let endMonths = lastMonths + 6
        return GrowthChartData(past: past,
                               chosen: dated(forecast.chosen),
                               actual: dated(forecast.actual),
                               chosenDate: forecast.chosen.monthsToGoal.map { ForecastEngine.date(afterMonths: $0, from: now) },
                               xStart: past.first?.date ?? now,
                               xEnd: ForecastEngine.date(afterMonths: endMonths, from: now))
    }
}

extension ScenarioResult {
    /// Cumulative hours at a point in time; stays at 10,000 once reached.
    func hours(atMonth month: Double) -> Double {
        guard let first = points.first else { return 0 }
        if let goal = monthsToGoal, month >= goal { return Totals.goalHours }
        guard let upper = points.firstIndex(where: { $0.monthsFromNow >= month }) else {
            return points.last?.hours ?? first.hours
        }
        if upper == 0 { return first.hours }
        let a = points[upper - 1], b = points[upper]
        let span = b.monthsFromNow - a.monthsFromNow
        guard span > 0 else { return b.hours }
        return a.hours + (b.hours - a.hours) * (month - a.monthsFromNow) / span
    }
}

enum GrowthText {
    /// What VoiceOver reads for the chart on the Growth card.
    static func chartLabel(total: Double, forecast: Forecast, now: Date, calendar: Calendar = .current) -> String {
        let today = "Cumulative hours: \(DurationFormat.grouped(Totals.wholeHours(total: total))) today. "
        if total >= Totals.goalHours { return today + "You have crossed the finish line." }
        return today + "At your chosen pace you reach 10,000 hours: "
            + ForecastText.headline(forecast.chosen, now: now, calendar: calendar) + ". "
            + ForecastText.actualLine(forecast, now: now, calendar: calendar) + "."
    }
}

/// The words in the key under the Growth chart. Live: the chosen pace includes the What-if extra.
enum GrowthKeyText {
    /// "12 h a week · Nov 2035"
    static func chosenNumbers(_ forecast: Forecast, now: Date, calendar: Calendar = .current) -> String {
        let finish = forecast.chosen.monthsToGoal == nil
            ? ForecastText.year(forecast.chosen, now: now, calendar: calendar)
            : ForecastText.shortMonthYear(ForecastEngine.date(afterMonths: forecast.chosen.monthsToGoal ?? 0, from: now), calendar: calendar)
        return "\(WeeklyTarget.number(forecast.chosenRate)) h a week · \(finish)"
    }

    /// "9.5 h a week · 2039", or "… · after 2056" beyond 30 years.
    static func actualNumbers(_ forecast: Forecast, now: Date, calendar: Calendar = .current) -> String {
        "\(WeeklyTarget.number(forecast.actualRate)) h a week · \(ForecastText.year(forecast.actual, now: now, calendar: calendar))"
    }

    /// One VoiceOver sentence for the whole key.
    static func spoken(_ forecast: Forecast, now: Date, calendar: Calendar = .current) -> String {
        func rate(_ r: Double) -> String { WeeklyTarget.number(r) }
        let chosen: String
        if let m = forecast.chosen.monthsToGoal {
            chosen = "finishes around " + ForecastText.monthYear(ForecastEngine.date(afterMonths: m, from: now), calendar: calendar)
        } else {
            chosen = "finishes " + ForecastText.year(forecast.chosen, now: now, calendar: calendar)
        }
        let actual = forecast.actual.monthsToGoal == nil
            ? "finishes " + ForecastText.year(forecast.actual, now: now, calendar: calendar)
            : "finishes around " + ForecastText.year(forecast.actual, now: now, calendar: calendar)
        return "Your chosen pace, \(rate(forecast.chosenRate)) hours a week, \(chosen). "
            + "Your actual pace, \(rate(forecast.actualRate)) hours a week, \(actual)."
    }
}
