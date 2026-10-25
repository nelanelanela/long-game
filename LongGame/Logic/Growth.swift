import Foundation

struct CumulativePoint: Equatable, Sendable {
    var date: Date
    var hours: Double
}

struct BandPoint: Equatable, Sendable {
    var date: Date
    var low: Double
    var high: Double
}

/// Everything the Growth chart draws.
struct GrowthChartData: Sendable {
    var past: [CumulativePoint]
    var mid: [CumulativePoint]
    var band: [BandPoint]
    var masteryDate: Date?
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
        let longest = [forecast.mid, forecast.high, forecast.low].map { $0.monthsToGoal ?? Double(ForecastEngine.horizonMonths) }.max() ?? 0
        let lastMonth = Int(longest.rounded(.up))
        let band = (0...max(1, lastMonth)).map { m in
            BandPoint(date: ForecastEngine.date(afterMonths: Double(m), from: now),
                      low: forecast.low.hours(atMonth: Double(m)),
                      high: forecast.high.hours(atMonth: Double(m)))
        }
        let midDate = forecast.mid.monthsToGoal.map { ForecastEngine.date(afterMonths: $0, from: now) }
        let xEnd = ForecastEngine.date(afterMonths: Double(max(lastMonth, 12) + 6), from: now)
        return GrowthChartData(past: past, mid: dated(forecast.mid), band: band, masteryDate: midDate,
                               xStart: past.first?.date ?? now, xEnd: xEnd)
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
    /// "+0.8 h/wk a year" (or minus).
    static func trend(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        let sign = rounded < 0 ? "−" : "+"
        return "\(sign)\(String(format: "%.1f", abs(rounded))) h/wk a year"
    }

    static func chartLabel(total: Double, forecast: Forecast, now: Date, calendar: Calendar = .current) -> String {
        let high = ForecastText.year(forecast.high, now: now, calendar: calendar)
        let low = ForecastText.year(forecast.low, now: now, calendar: calendar)
        return "Cumulative hours: \(Totals.wholeHours(total: total).formatted()) today. Forecast reaches 10,000 hours around "
            + ForecastText.headline(forecast.mid, now: now, calendar: calendar) + ", likely between \(high) and \(low)."
    }
}
