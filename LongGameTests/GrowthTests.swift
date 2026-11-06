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
        let r = ForecastEngine.line(total: 9000, weeklyRate: 20)
        #expect(r.hours(atMonth: 0) == 9000)
        #expect(abs(r.hours(atMonth: 1) - (9000 + 20 * ForecastEngine.daysPerMonth / 7)) < 0.01)
        #expect(r.hours(atMonth: 100) == 10_000)
    }

    @Test func chartDataHasTheTwoLinesFromToday() {
        let now = day(2026, 10, 25)
        let f = ForecastEngine.forecast(total: 3294, chosenPace: 12, recentPace: 8)
        let data = GrowthSeries.chartData(forecast: f, past: [], now: now, calendar: utc)
        #expect(data.chosen.first?.hours == 3294 && data.recent.first?.hours == 3294)
        #expect(data.chosen.first?.date == now && data.recent.first?.date == now)
        #expect(data.chosen.last?.hours == 10_000)
        #expect(data.recent.last?.hours == 10_000)
        #expect(data.chosenDate != nil)
        // The slower recent pace finishes later, and the chart runs to it.
        #expect((data.recent.last?.date ?? .distantPast) > (data.chosen.last?.date ?? .distantFuture))
        #expect(data.xEnd > (data.recent.last?.date ?? .distantFuture))
    }

    @Test func aLineThatNeverArrivesRunsToTheHorizon() {
        let now = day(2026, 10, 25)
        let f = ForecastEngine.forecast(total: 3000, chosenPace: 12, recentPace: 0)
        let data = GrowthSeries.chartData(forecast: f, past: [], now: now, calendar: utc)
        #expect(data.recent.last?.hours == 3000)
        #expect(data.recent.last?.date == ForecastEngine.date(afterMonths: 360, from: now))
        #expect(data.xEnd > ForecastEngine.date(afterMonths: 360, from: now))
    }

    @Test func linesDrawInOrderAndCanBeCutShort() {
        #expect(DrawProgress.at(0) == .empty)
        let mid = DrawProgress.at(0.4)
        #expect(mid.past > 0 && mid.past < 1 && mid.chosen == 0 && mid.recent == 0 && !mid.sun)
        let dashed = DrawProgress.at(1.05)
        #expect(dashed.past == 1 && dashed.chosen > 0 && dashed.chosen < 1 && dashed.recent == 0)
        let dotted = DrawProgress.at(1.4)
        #expect(dotted.chosen == 1 && dotted.recent > 0 && dotted.recent < 1 && !dotted.sun)
        #expect(DrawProgress.at(1.6) == .complete)
        let line = [CumulativePoint(date: Date(timeIntervalSince1970: 0), hours: 0),
                    CumulativePoint(date: Date(timeIntervalSince1970: 100), hours: 1_000)]
        #expect(LineDraw.partial(line, fraction: 0).isEmpty)
        #expect(LineDraw.partial(line, fraction: 1) == line)
        let half = LineDraw.partial(line, fraction: 0.5)
        #expect(half.last == CumulativePoint(date: Date(timeIntervalSince1970: 50), hours: 500))
    }

    @Test func textHelpers() {
        let f = ForecastEngine.forecast(total: 3294, chosenPace: 12, recentPace: 8)
        let label = GrowthText.chartLabel(total: 3294, forecast: f, now: day(2026, 10, 25), calendar: utc)
        #expect(label.contains(" today. At your chosen pace you reach 10,000 hours"))
        #expect(label.contains("At your recent pace: around"))
    }
}
