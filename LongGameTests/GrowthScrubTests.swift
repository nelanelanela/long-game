import Testing
import Foundation
@testable import LongGame

private let en = Locale(identifier: "en_GB")
private func d(_ y: Int, _ m: Int, _ dd: Int) -> Date { day(y, m, dd, hour: 0) }

// A past of 0 → 500 → 1,200 hours in the estimate (to the day tracking began), then logged sessions.
private let onboarding = d(2022, 1, 1)
private let now = d(2022, 6, 15)
private let past: [CumulativePoint] = [
    CumulativePoint(date: d(2020, 1, 1), hours: 0), CumulativePoint(date: d(2021, 1, 1), hours: 500),
    CumulativePoint(date: d(2022, 1, 1), hours: 1_200), CumulativePoint(date: d(2022, 3, 1), hours: 1_300),
    CumulativePoint(date: d(2022, 6, 1), hours: 2_600), CumulativePoint(date: now, hours: 2_700),
]

/// 100 hours a month from now: 5,000 after 23 months, 7,500 after 48, 10,000 after 73.
private func forecast(months: Int = 73, perMonth: Double = 100, start: Double = 2_700) -> ScenarioResult {
    let points = (0...months).map { ForecastPoint(monthsFromNow: Double($0), hours: min(10_000, start + perMonth * Double($0))) }
    let reaches = start + perMonth * Double(months) >= 10_000
    return ScenarioResult(monthsToGoal: reaches ? (10_000 - start) / perMonth : nil, points: points)
}

private func milestones(_ f: ScenarioResult? = nil, past p: [CumulativePoint] = past, now n: Date = now) -> [ScrubMilestone] {
    GrowthScrub.milestoneDates(past: p, forecast: f ?? forecast(), onboardingDate: onboarding, now: n)
}

struct ScrubMilestoneTests {
    @Test func aMilestoneInsideTheOnboardingEstimateIsAnEstimate() throws {
        let m = try #require(milestones().first { $0.hours == 1_000 })
        #expect(m.isReached && m.isEstimate)
        // 1,000 lies 500/700 of the way from 1 Jan 2021 to 1 Jan 2022: about 18 Sep 2021.
        #expect(m.date > d(2021, 8, 1) && m.date < d(2021, 10, 31))
    }

    @Test func aMilestoneReachedByLoggedHoursHasTheRealDay() throws {
        let m = try #require(milestones().first { $0.hours == 2_500 })
        #expect(m.isReached && !m.isEstimate)
        #expect(m.date == d(2022, 6, 1))
    }

    @Test func aMilestoneStillAheadIsTheForecastMonth() throws {
        let all = milestones()
        let half = try #require(all.first { $0.hours == 5_000 })
        #expect(!half.isReached && !half.isEstimate)
        #expect(half.date == ForecastEngine.date(afterMonths: 23, from: now))
        let finish = try #require(all.first { $0.isFinish })
        #expect(finish.date == ForecastEngine.date(afterMonths: 73, from: now))
        #expect(all.map(\.hours) == [1_000, 2_500, 5_000, 7_500, 10_000])
    }

    @Test func aMilestoneExactlyOnTodayIsReachedToday() throws {
        var p = past
        p[p.count - 1].hours = 2_500
        p.remove(at: p.count - 2)   // the 1 June point
        let m = try #require(milestones(forecast(start: 2_500), past: p).first { $0.hours == 2_500 })
        #expect(m.isReached && m.date == now)
    }

    @Test func aForecastThatNeverArrivesLeavesOutWhatLiesBeyondTheHorizon() {
        let slow = forecast(months: 360, perMonth: 20)   // 2,700 + 7,200 = 9,900 after 30 years
        let all = milestones(slow)
        #expect(all.map(\.hours) == [1_000, 2_500, 5_000, 7_500])
        #expect(slow.monthsToGoal == nil)
        let range = GrowthScrub.range(past: past, forecast: slow, now: now)
        #expect(range.upperBound == ForecastEngine.date(afterMonths: 360, from: now))
        // Nothing on the line lies beyond the horizon.
        let end = GrowthScrub.curvePoint(at: d(2080, 1, 1), past: past, forecast: slow, onboardingDate: onboarding, now: now)
        #expect(end.date == range.upperBound && end.isFuture)
    }

    @Test func theSlidersExtraHoursMoveTheFinishSooner() throws {
        func finish(extra: Double) throws -> Date {
            let s = ProgressSummary.make(estimates: [2020, 2021, 2022].map { YearRate(year: $0, hoursPerWeek: 10) }, sessions: [session(d(2022, 5, 2), hours: 1)],
                                         onboardingDate: d(2022, 5, 1), weekStart: .monday, now: d(2022, 6, 15), extra: extra, calendar: utc)
            let all = milestones(s.forecast.mid, now: d(2022, 6, 15))
            let finish = try #require(all.first { $0.isFinish })
            return finish.date
        }
        #expect(try finish(extra: 5) < finish(extra: 0))
    }
}

struct ScrubCurveTests {
    @Test func theCurveFollowsThePastLineDayByDay() {
        let p = GrowthScrub.curvePoint(at: d(2022, 4, 15), past: past, forecast: forecast(), onboardingDate: onboarding, now: now)
        #expect(!p.isFuture && !p.isEstimate)
        // Between 1 Mar (1,300) and 1 Jun (2,600), 45 of 92 days along.
        #expect(abs(p.hours - (1_300 + 1_300 * 45.0 / 92.0)) < 1)
    }

    @Test func theCurveFollowsTheForecastAfterToday() {
        let at = ForecastEngine.date(afterMonths: 23, from: now)
        let p = GrowthScrub.curvePoint(at: at, past: past, forecast: forecast(), onboardingDate: onboarding, now: now)
        #expect(p.isFuture && abs(p.hours - 5_000) < 0.01)
        let today = GrowthScrub.curvePoint(at: now, past: past, forecast: forecast(), onboardingDate: onboarding, now: now)
        #expect(!today.isFuture && today.hours == 2_700)
    }

    @Test func beforeTrackingBeganThePointIsAnEstimate() {
        let p = GrowthScrub.curvePoint(at: d(2021, 7, 1), past: past, forecast: forecast(), onboardingDate: onboarding, now: now)
        #expect(p.isEstimate && !p.isFuture)
        #expect(p.hours > 500 && p.hours < 1_200)
    }

    @Test func positionsOutsideTheLineAreHeldAtItsEnds() {
        let start = GrowthScrub.curvePoint(at: d(2010, 1, 1), past: past, forecast: forecast(), onboardingDate: onboarding, now: now)
        #expect(start.date == d(2020, 1, 1) && start.hours == 0)
        let end = GrowthScrub.curvePoint(at: d(2090, 1, 1), past: past, forecast: forecast(), onboardingDate: onboarding, now: now)
        #expect(end.hours == 10_000)
    }
}

struct ScrubCrossingTests {
    private let ms = milestones()   // 1,000 (2021), 2,500 (1 Jun 2022), 5,000, 7,500, 10,000

    @Test func scrubbingRightPastAMilestone() {
        #expect(GrowthScrub.crossedMilestone(from: d(2022, 5, 1), to: d(2022, 7, 1), milestones: ms) == 1)
    }

    @Test func scrubbingLeftPastAMilestone() {
        #expect(GrowthScrub.crossedMilestone(from: d(2022, 7, 1), to: d(2022, 5, 1), milestones: ms) == 1)
    }

    @Test func nothingBetweenNothingCrossed() {
        #expect(GrowthScrub.crossedMilestone(from: d(2022, 6, 2), to: d(2022, 6, 10), milestones: ms) == nil)
        #expect(GrowthScrub.crossedMilestone(from: d(2022, 6, 2), to: d(2022, 6, 2), milestones: ms) == nil)
    }

    @Test func arrivingOnAMilestoneCountsButLeavingOneDoesNot() {
        #expect(GrowthScrub.crossedMilestone(from: d(2022, 5, 1), to: d(2022, 6, 1), milestones: ms) == 1)
        #expect(GrowthScrub.crossedMilestone(from: d(2022, 6, 1), to: d(2022, 7, 1), milestones: ms) == nil)
        #expect(GrowthScrub.crossedMilestone(from: d(2022, 7, 1), to: d(2022, 6, 1), milestones: ms) == 1)
        #expect(GrowthScrub.crossedMilestone(from: d(2022, 6, 1), to: d(2022, 5, 1), milestones: ms) == nil)
    }

    @Test func aFastDragOverSeveralGivesTheOneNearestTheFinger() {
        #expect(GrowthScrub.crossedMilestone(from: d(2020, 6, 1), to: d(2023, 1, 1), milestones: ms) == 1)
        #expect(GrowthScrub.crossedMilestone(from: d(2023, 1, 1), to: d(2020, 6, 1), milestones: ms) == 0)
    }

    @Test func crossingToday() {
        #expect(GrowthScrub.crossedToday(from: d(2022, 6, 1), to: d(2022, 7, 1), now: now))
        #expect(GrowthScrub.crossedToday(from: d(2022, 7, 1), to: d(2022, 6, 1), now: now))
        #expect(!GrowthScrub.crossedToday(from: d(2022, 7, 1), to: d(2022, 8, 1), now: now))
        #expect(!GrowthScrub.crossedToday(from: now, to: d(2022, 8, 1), now: now))
    }

    @Test func aMilestoneExactlyOnTodayIsCrossedLikeAnyOther() {
        let onToday = [ScrubMilestone(hours: 2_700, date: now, isReached: true, isEstimate: false)]
        #expect(GrowthScrub.crossedMilestone(from: d(2022, 6, 1), to: d(2022, 7, 1), milestones: onToday) == 0)
        #expect(GrowthScrub.crossedMilestone(from: d(2022, 7, 1), to: d(2022, 6, 1), milestones: onToday) == 0)
    }
}

struct ScrubTrackerTests {
    private func tracker(days: Double = 20) -> GrowthScrub.Tracker {
        let ms = milestones()
        let range = GrowthScrub.range(past: past, forecast: forecast(), now: now)
        return GrowthScrub.Tracker(milestones: ms, now: now, range: range, tolerance: days * 86_400)
    }

    @Test func theFirstTouchSaysNothing() {
        var t = tracker()
        #expect(t.move(to: d(2022, 3, 1)) == nil)
    }

    @Test func aTapOnlyHappensOncePerMilestoneWhileTheFingerStaysClose() {
        var t = tracker()
        _ = t.move(to: d(2022, 5, 1))
        #expect(t.move(to: d(2022, 6, 3)) == .milestone(1))
        // Sitting on it, and wobbling across it, never repeats.
        #expect(t.move(to: d(2022, 6, 3)) == nil)
        #expect(t.move(to: d(2022, 5, 30)) == nil)
        #expect(t.move(to: d(2022, 6, 2)) == nil)
        #expect(t.move(to: d(2022, 5, 28)) == nil)
    }

    @Test func movingAwayAndBackTapsAgain() {
        var t = tracker(days: 5)
        _ = t.move(to: d(2022, 5, 1))
        #expect(t.move(to: d(2022, 6, 3)) == .milestone(1))
        #expect(t.move(to: d(2022, 6, 10)) == nil)     // more than 5 days away: re-armed
        #expect(t.active == nil)
        #expect(t.move(to: d(2022, 6, 1)) == .milestone(1))
    }

    @Test func todayAndBothEndsGiveATick() {
        var t = tracker()
        _ = t.move(to: d(2022, 6, 3))
        #expect(t.move(to: d(2022, 6, 20)) == .tick)   // past Today (15 Jun)
        // The first point of the line.
        var s = tracker()
        _ = s.move(to: d(2020, 6, 1))
        #expect(s.move(to: d(2000, 1, 1)) == .tick)
        // The end of a line whose finish is beyond 30 years: no milestone there, just the tick.
        let slow = forecast(months: 360, perMonth: 20)
        var e = GrowthScrub.Tracker(milestones: milestones(slow), now: now,
                                    range: GrowthScrub.range(past: past, forecast: slow, now: now), tolerance: 20 * 86_400)
        _ = e.move(to: d(2050, 1, 1))
        #expect(e.move(to: d(2090, 1, 1)) == .tick)
        #expect(e.move(to: d(2095, 1, 1)) == nil)      // still at the end: nothing more
    }

    @Test func liftingTheFingerStartsOver() {
        var t = tracker()
        _ = t.move(to: d(2022, 5, 1))
        _ = t.move(to: d(2022, 6, 3))
        t.end()
        #expect(t.move(to: d(2022, 6, 3)) == nil)       // a new touch: nothing to compare with yet
        #expect(t.active == nil)
    }

    @Test func theDotSnapsToAMilestoneItIsClose() {
        let t = tracker()
        #expect(t.milestone(near: d(2022, 6, 10)) == 1)
        #expect(t.milestone(near: d(2022, 9, 10)) == nil)
    }
}

struct ScrubTextTests {
    private func readout(_ date: Date, estimate: Bool = false, future: Bool = false, hours: Double,
                         milestone: ScrubMilestone? = nil) -> ScrubReadout {
        ScrubText.readout(for: ScrubPoint(date: date, hours: hours, isFuture: future, isEstimate: estimate),
                          milestone: milestone, calendar: utc, locale: en)
    }

    @Test func aPastPointHasDayPrecision() {
        let r = readout(d(2022, 10, 14), hours: 1_000)
        #expect(r.small == "Played" && r.chip == "Played")
        #expect(r.big == "14 Oct 2022 · 1,000 h")
        #expect(r.accent == "")
    }

    @Test func aFuturePointHasMonthPrecision() {
        let r = readout(d(2029, 2, 10), future: true, hours: 5_000)
        #expect(r.small == "If you keep your pace" && r.chip == "Forecast")
        #expect(r.big == "Feb 2029 · 5,000 h")
    }

    @Test func milestoneWords() {
        func m(_ hours: Double, reached: Bool, estimate: Bool = false) -> ScrubMilestone {
            ScrubMilestone(hours: hours, date: d(2029, 2, 10), isReached: reached, isEstimate: estimate)
        }
        #expect(readout(d(2022, 10, 14), hours: 1_000, milestone: m(1_000, reached: true)).accent == "Milestone reached")
        #expect(readout(d(2022, 10, 14), hours: 1_000, milestone: m(1_000, reached: true)).blurb == "Reached 1,000 hours")
        #expect(readout(d(2029, 2, 10), future: true, hours: 5_000, milestone: m(5_000, reached: false)).accent == "Milestone · halfway")
        #expect(readout(d(2029, 2, 10), future: true, hours: 5_000, milestone: m(5_000, reached: false)).blurb == "Halfway. The sun's at its height.")
        #expect(readout(d(2031, 2, 10), future: true, hours: 7_500, milestone: m(7_500, reached: false)).accent == "Milestone · 7,500 h")
        #expect(readout(d(2035, 11, 10), future: true, hours: 10_000, milestone: m(10_000, reached: false)).accent == "The finish line")
    }

    @Test func aMilestoneInTheEstimateSaysAbout() {
        let m = ScrubMilestone(hours: 1_000, date: d(2021, 10, 14), isReached: true, isEstimate: true)
        let r = readout(d(2021, 10, 14), estimate: true, hours: 1_000, milestone: m)
        #expect(r.big == "about Oct 2021 · 1,000 h")
        #expect(r.accent == "Milestone reached · estimate")
    }

    @Test func voiceOverStopsRunFromStartThroughMilestonesAndTodayToTheFinishLine() {
        let ms = milestones()
        let range = GrowthScrub.range(past: past, forecast: forecast(), now: now)
        let stops = ScrubText.stops(milestones: ms, range: range, now: now)
        #expect(stops.map(\.stop) == [.start, .milestone(0), .milestone(1), .today, .milestone(2), .milestone(3), .milestone(4)])
        #expect(stops.map(\.date) == stops.map(\.date).sorted())
        // Without a finish within 30 years the line's end is the last stop.
        let slow = forecast(months: 360, perMonth: 20)
        let slowStops = ScrubText.stops(milestones: milestones(slow), range: GrowthScrub.range(past: past, forecast: slow, now: now), now: now)
        #expect(slowStops.last?.stop == .end)
    }
}
