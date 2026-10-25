import Testing
import Foundation
@testable import LongGame

struct GrowthTests {
    let est = [YearRate(year: 2024, hoursPerWeek: 10), YearRate(year: 2025, hoursPerWeek: 10), YearRate(year: 2026, hoursPerWeek: 10)]
    let onboarding = day(2026, 3, 12, hour: 0)

    @Test func pastSeriesStartsAtZeroAndNeverDecreases() {
        let now = day(2026, 10, 25)
        let s = [session(day(2026, 5, 1), hours: 2), session(day(2026, 6, 1), hours: 3), session(day(2026, 1, 15), hours: 1)]
        let past = GrowthSeries.past(estimates: est, sessions: s, onboardingDate: onboarding, startYear: 2024, now: now, calendar: utc)
        #expect(past.first?.hours == 0)
        #expect(zip(past, past.dropFirst()).allSatisfy { $0.1.hours >= $0.0.hours })
    }

    @Test func pastSeriesEndsAtTheTotal() {
        let now = day(2026, 10, 25)
        let s = [session(day(2026, 5, 1), hours: 2), session(day(2026, 10, 25), hours: 1)]
        let past = GrowthSeries.past(estimates: est, sessions: s, onboardingDate: onboarding, startYear: 2024, now: now, calendar: utc)
        let baseline = Baseline.hours(estimates: est, onboardingDate: onboarding, calendar: utc)
        #expect(abs((past.last?.hours ?? 0) - (baseline + 3)) < 0.0001)
        #expect(past.last?.date == now)
    }

    @Test func pastSeriesHitsBaselineAtOnboarding() {
        let past = GrowthSeries.past(estimates: est, sessions: [], onboardingDate: onboarding, startYear: 2024, now: day(2026, 10, 25), calendar: utc)
        let atOnboarding = past.first { $0.date == onboarding }
        let baseline = Baseline.hours(estimates: est, onboardingDate: onboarding, calendar: utc)
        #expect(abs((atOnboarding?.hours ?? -1) - baseline) < 0.0001)
        // after onboarding with no sessions the curve stays flat
        #expect(abs((past.last?.hours ?? 0) - baseline) < 0.0001)
    }

    @Test func scenarioHoursInterpolateAndCap() {
        let r = ForecastEngine.simulate(.mid, total: 9000, pace: 20, trend: 0)
        #expect(r.hours(atMonth: 0) == 9000)
        #expect(abs(r.hours(atMonth: 1) - (9000 + 20 * 52 / 12)) < 0.01)
        #expect(r.hours(atMonth: 100) == 10_000)
    }

    @Test func chartDataHasAlignedBand() {
        let f = ForecastEngine.forecast(total: 3294, pace: 12, trend: 0.5)
        let data = GrowthSeries.chartData(forecast: f, past: [], now: day(2026, 10, 25), calendar: utc)
        #expect(data.band.allSatisfy { $0.high >= $0.low })
        #expect(data.band.first?.low == 3294)
        #expect(data.masteryDate != nil)
        #expect(data.mid.last?.hours == 10_000)
        #expect(data.xEnd > (data.masteryDate ?? .distantPast))
    }

    @Test func textHelpers() {
        #expect(GrowthText.trend(0.84) == "+0.8 h/wk a year")
        #expect(GrowthText.trend(-1.25) == "−1.3 h/wk a year" || GrowthText.trend(-1.25) == "−1.2 h/wk a year")
        let f = ForecastEngine.forecast(total: 3294, pace: 12, trend: 0.5)
        #expect(GrowthText.chartLabel(total: 3294, forecast: f, now: day(2026, 10, 25), calendar: utc).contains(" today. Forecast reaches"))
    }
}
