import Foundation

struct ForecastPoint: Equatable, Sendable {
    var monthsFromNow: Double
    var hours: Double
}

struct ScenarioResult: Equatable, Sendable {
    /// Months from now until 10,000 h, nil if not reached within 15 years.
    var monthsToGoal: Double?
    var points: [ForecastPoint]
}

struct Forecast: Equatable, Sendable {
    var mid: ScenarioResult
    var high: ScenarioResult
    var low: ScenarioResult
}

enum ForecastEngine {
    static let horizonMonths = 180
    static let daysPerMonth = 30.436875

    enum Scenario { case mid, high, low }

    /// Weekly average of each year: estimates for past years, logged data for
    /// the current year once there are at least 2 weeks of it.
    static func yearlyRates(estimates: [YearRate], sessions: [SessionRecord], onboardingDate: Date, now: Date, calendar: Calendar = .current) -> [YearRate] {
        let currentYear = calendar.component(.year, from: now)
        return estimates.sorted { $0.year < $1.year }.compactMap { e in
            guard e.year <= currentYear else { return nil }
            guard e.year == currentYear else { return e }
            guard let jan1 = calendar.date(from: DateComponents(year: currentYear, month: 1, day: 1)) else { return e }
            let from = max(jan1, calendar.startOfDay(for: onboardingDate))
            let weeks = now.timeIntervalSince(from) / (7 * 86_400)
            guard weeks >= 2 else { return e }
            let logged = sessions.filter { $0.start >= from }.reduce(0) { $0 + $1.hours }
            return YearRate(year: currentYear, hoursPerWeek: logged / weeks)
        }
    }

    /// Least-squares slope in h/week per year, clamped to [-2, +2].
    static func trend(yearly: [YearRate]) -> Double {
        guard yearly.count >= 2 else { return 0 }
        let n = Double(yearly.count)
        let xs = yearly.map { Double($0.year) }, ys = yearly.map(\.hoursPerWeek)
        let mx = xs.reduce(0, +) / n, my = ys.reduce(0, +) / n
        let num = zip(xs, ys).reduce(0) { $0 + ($1.0 - mx) * ($1.1 - my) }
        let den = xs.reduce(0) { $0 + ($1 - mx) * ($1 - mx) }
        guard den > 0 else { return 0 }
        return min(2, max(-2, num / den))
    }

    static func weeklyRate(_ scenario: Scenario, years t: Double, pace r: Double, trend s: Double, extra e: Double) -> Double {
        let rate: Double
        switch scenario {
        case .mid: rate = min(1.5 * r + e, r + e + 0.5 * s * t)
        case .high: rate = min(2 * r + e, r + e + s * t)
        case .low: rate = 0.75 * r + e
        }
        return max(0, rate)
    }

    static func simulate(_ scenario: Scenario, total: Double, pace: Double, trend: Double, extra: Double = 0) -> ScenarioResult {
        var hours = total
        var points = [ForecastPoint(monthsFromNow: 0, hours: hours)]
        if total >= Totals.goalHours { return ScenarioResult(monthsToGoal: 0, points: points) }
        for m in 0..<horizonMonths {
            let rate = weeklyRate(scenario, years: Double(m) / 12, pace: pace, trend: trend, extra: extra)
            let add = rate * 52 / 12
            if add > 0, hours + add >= Totals.goalHours {
                let months = Double(m) + (Totals.goalHours - hours) / add
                points.append(ForecastPoint(monthsFromNow: months, hours: Totals.goalHours))
                return ScenarioResult(monthsToGoal: months, points: points)
            }
            hours += add
            points.append(ForecastPoint(monthsFromNow: Double(m + 1), hours: hours))
        }
        return ScenarioResult(monthsToGoal: nil, points: points)
    }

    static func forecast(total: Double, pace: Double, trend: Double, extra: Double = 0) -> Forecast {
        Forecast(
            mid: simulate(.mid, total: total, pace: pace, trend: trend, extra: extra),
            high: simulate(.high, total: total, pace: pace, trend: trend, extra: extra),
            low: simulate(.low, total: total, pace: pace, trend: trend, extra: extra)
        )
    }

    static func date(afterMonths months: Double, from now: Date) -> Date {
        now.addingTimeInterval(months * daysPerMonth * 86_400)
    }

    /// Months the mid date moves earlier with `extra` h/week (nil if either never arrives).
    static func monthsSooner(total: Double, pace: Double, trend: Double, extra: Double) -> Double? {
        guard let base = simulate(.mid, total: total, pace: pace, trend: trend).monthsToGoal,
              let with = simulate(.mid, total: total, pace: pace, trend: trend, extra: extra).monthsToGoal
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

    static func headline(_ result: ScenarioResult, now: Date, calendar: Calendar = .current) -> String {
        guard let m = result.monthsToGoal else {
            return "After \(calendar.component(.year, from: now) + 15)"
        }
        return monthYear(ForecastEngine.date(afterMonths: m, from: now), calendar: calendar)
    }

    static func year(_ result: ScenarioResult, now: Date, calendar: Calendar = .current) -> String {
        guard let m = result.monthsToGoal else {
            return "after \(calendar.component(.year, from: now) + 15)"
        }
        return String(calendar.component(.year, from: ForecastEngine.date(afterMonths: m, from: now)))
    }

    /// "~2036" on Home.
    static func homeMastery(_ result: ScenarioResult, now: Date, calendar: Calendar = .current) -> String {
        result.monthsToGoal == nil ? "—" : "~" + year(result, now: now, calendar: calendar)
    }

    static func whatIf(extra: Double, total: Double, pace: Double, trend: Double, now: Date, calendar: Calendar = .current) -> String {
        guard extra > 0 else { return "Based on your recent pace and how it has been growing." }
        let with = ForecastEngine.simulate(.mid, total: total, pace: pace, trend: trend, extra: extra)
        guard let sooner = ForecastEngine.monthsSooner(total: total, pace: pace, trend: trend, extra: extra) else {
            return "Around " + headline(with, now: now, calendar: calendar) + "."
        }
        let months = Int(sooner.rounded())
        let amount: String
        if months >= 12 {
            amount = String(format: "%.1f years", (sooner / 12 * 10).rounded() / 10)
        } else {
            amount = months == 1 ? "1 month" : "\(months) months"
        }
        return "About \(amount) sooner, around " + headline(with, now: now, calendar: calendar) + "."
    }
}
