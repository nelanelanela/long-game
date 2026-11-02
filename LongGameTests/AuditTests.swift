import Testing
import Foundation
@testable import LongGame

struct MilestoneNotificationTests {
    let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
    func state(pausedAfter: TimeInterval? = nil) -> TimerState {
        var s = TimerState(craftId: UUID(), craftName: "Piano", startedAt: start)
        if let pausedAfter { s.pause(at: start.addingTimeInterval(pausedAfter)) }
        return s
    }

    @Test func plansTheNextMilestoneForTheMomentTheTotalCrossesIt() throws {
        // 998.5 h before the session: 1,000 h arrives 1.5 h in; the session is 10 minutes old.
        let now = start.addingTimeInterval(600)
        let next = try #require(Milestones.nextCrossing(baseTotal: 998.5, state: state(), seen: [100, 500], now: now))
        #expect(next.hours == 1_000)
        #expect(abs(next.date.timeIntervalSince(start) - 1.5 * 3600) < 1)
    }

    @Test func skipsMilestonesAlreadyCelebrated() throws {
        let next = try #require(Milestones.nextCrossing(baseTotal: 499.9, state: state(), seen: [100], now: start))
        #expect(next.hours == 500)
        #expect(Milestones.nextCrossing(baseTotal: 99.9, state: state(), seen: [100, 500, 1_000, 2_500, 5_000, 7_500, 10_000], now: start) == nil)
    }

    @Test func nothingWhilePausedOrTooFarAway() {
        let now = start.addingTimeInterval(3600)
        #expect(Milestones.nextCrossing(baseTotal: 99.9, state: state(pausedAfter: 1800), seen: [], now: now) == nil)
        // 1,000 is 500 hours away: the timer auto-pauses after 12 hours long before that.
        #expect(Milestones.nextCrossing(baseTotal: 500, state: state(), seen: [100, 500], now: start) == nil)
    }
}

struct AuditFixTests {
    let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    @Test func homeFinishLineSaysAfterWhenBeyondThirtyYears() {
        let never = ScenarioResult(monthsToGoal: nil, points: [])
        let year = Calendar.current.component(.year, from: now) + ForecastEngine.horizonYears
        #expect(ForecastText.homeMastery(never, now: now) == "after \(year)")
    }

    @Test func rangeShowsAfterYearWhenOnlyTheLateEdgeMisses() {
        let reaches = ScenarioResult(monthsToGoal: 60, points: [])
        let never = ScenarioResult(monthsToGoal: nil, points: [])
        let text = ForecastText.range(Forecast(mid: reaches, high: reaches, low: never), now: now)
        #expect(text.hasPrefix("Likely between "))
        #expect(text.hasSuffix(" and after \(Calendar.current.component(.year, from: now) + ForecastEngine.horizonYears)"))
    }

    @Test func wholeNumbersUseCommasOnEveryDevice() {
        #expect(DurationFormat.grouped(3_294) == "3,294")
        #expect(DurationFormat.grouped(10_000) == "10,000")
        #expect(DurationFormat.grouped(12) == "12")
    }
}
