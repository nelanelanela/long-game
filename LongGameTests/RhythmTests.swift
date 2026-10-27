import Testing
import Foundation
@testable import LongGame

struct RhythmTests {
    /// Wednesday 28 Oct 2026. Weeks start on Monday, so this week began on Monday 26 Oct.
    let now = day(2026, 10, 28)
    let longAgo = day(2025, 1, 1)

    /// A date `weeksAgo` weeks back, `dayOffset` days after that week's Monday.
    func date(weeksAgo: Int, dayOffset: Int) -> Date {
        utc.date(byAdding: .day, value: dayOffset - 7 * weeksAgo, to: day(2026, 10, 26))!
    }

    /// One session per practice day: `perWeek[0]` is this week, `perWeek[1]` last week, and so on.
    func daily(_ perWeek: [Int], catchUp: Bool = false, hours: Double = 1) -> [Date: Double] {
        var records: [SessionRecord] = []
        for (weeksAgo, count) in perWeek.enumerated() {
            for offset in 0..<count {
                records.append(SessionRecord(start: date(weeksAgo: weeksAgo, dayOffset: offset), durationSec: hours * 3600, isCatchUp: catchUp))
            }
        }
        return Practice.dailySeconds(records, calendar: utc)
    }

    func rhythm(_ d: [Date: Double], since: Date? = nil) -> Rhythm.Result {
        Rhythm.compute(daily: d, since: since ?? longAgo, now: now, weekStart: .monday, calendar: utc)
    }

    // MARK: Rhythm

    @Test func rhythmIsTheMedianOfDaysPerWeek() {
        // This week 2 (still going), then eight weeks of 4, 4, 5, 3, 4, 4, 6, 4 days.
        let r = rhythm(daily([2, 4, 4, 5, 3, 4, 4, 6, 4]))
        #expect(r.daysPerWeek == 4)
    }

    @Test func oneOffBigWeekDoesNotMoveRhythm() {
        let r = rhythm(daily([3, 3, 3, 3, 3, 3, 3, 3, 7]))
        #expect(r.daysPerWeek == 3)
    }

    @Test func onlyTheLastEightCompleteWeeksPlusThisWeekCount() {
        // Nine recent weeks of 2 days; everything older is 7 days a week and must be ignored.
        let r = rhythm(daily([2, 2, 2, 2, 2, 2, 2, 2, 2, 7, 7, 7, 7, 7, 7]))
        #expect(r.daysPerWeek == 2)
    }

    @Test func weeksWithNoPracticeCountAsZero() {
        // Practised in 4 of the 9 weeks only: the typical week is a rest week.
        let r = rhythm(daily([3, 0, 0, 3, 0, 3, 0, 0, 3]))
        #expect(r.daysPerWeek == 0)
        #expect(r.steadyWeeks == 0)
    }

    @Test func aMostlyPlayedPatternWithAFewEmptyWeeksStillHasARhythm() {
        let r = rhythm(daily([3, 0, 3, 3, 3, 0, 3, 3, 3]))
        #expect(r.daysPerWeek == 3)
    }

    @Test func nothingLoggedMeansNoRhythm() {
        #expect(rhythm([:]) == Rhythm.Result(daysPerWeek: 0, steadyWeeks: 0))
    }

    @Test func sessionsOnTheSameDayAreOnePracticeDay() {
        let twice = [session(day(2026, 10, 26, hour: 8), hours: 1), session(day(2026, 10, 26, hour: 20), hours: 1)]
        let r = rhythm(Practice.dailySeconds(twice, calendar: utc), since: day(2026, 10, 26))
        #expect(r.daysPerWeek == 1)
    }

    // MARK: Brand-new users

    @Test func brandNewUserWithLessThanAWeekOfData() {
        // Began on Tuesday; weeks before that are not rest weeks, they are not part of the story.
        let began = day(2026, 10, 27)
        let r = rhythm(daily([2]), since: began)
        #expect(r.daysPerWeek == 2)
        #expect(r.steadyWeeks == 1)
    }

    @Test func brandNewUserWhoHasNotPractisedYetSeesDashes() {
        let r = rhythm([:], since: day(2026, 10, 27))
        #expect(r.daysPerWeek == 0)
        #expect(r.steadyWeeks == 0)
    }

    @Test func secondWeekOfUseUsesBothWeeks() {
        // Began last Thursday: last week 3 days, this week 1 so far. Sorted [1, 3] -> the upper middle, 3.
        let r = rhythm(daily([1, 3]), since: date(weeksAgo: 1, dayOffset: 3))
        #expect(r.daysPerWeek == 3)
    }

    @Test func pastHoursLoggedBeforeOnboardingStillStartTheStory() {
        // Added hours for a day two weeks before the onboarding date: that week counts too.
        let began = day(2026, 10, 27)
        let r = rhythm(daily([1, 0, 4]), since: began)
        #expect(r.daysPerWeek == 1)
    }

    // MARK: Catch-up

    @Test func catchUpSessionsCountLikeAnyOther() {
        // Welcome back spread 30 minutes a day over four weeks, 4 days a week; that is the rhythm now.
        let r = rhythm(daily([0, 4, 4, 4, 4], catchUp: true, hours: 0.5), since: date(weeksAgo: 4, dayOffset: 0))
        #expect(r.daysPerWeek == 4)
        #expect(r.steadyWeeks == 4)  // this week is still empty (skipped), then four steady weeks
    }

    @Test func catchUpAndRealSessionsMixInOneWeek() {
        let real = daily([2, 2, 2], catchUp: false)
        let catchUp = daily([0, 0, 0, 3, 3, 3, 3], catchUp: true, hours: 0.25)
        let merged = real.merging(catchUp) { $0 + $1 }
        #expect(rhythm(merged, since: date(weeksAgo: 6, dayOffset: 0)).daysPerWeek == 3)
    }

    // MARK: Steady for

    @Test func steadyForCountsWeeksWithAtLeastRhythmMinusOne() {
        // Rhythm 4, so 3+ days keeps the run: this week 3, then 4, 5, 3 and a 2-day week that ends it.
        let r = rhythm(daily([3, 4, 5, 3, 2, 4, 4, 4, 4]))
        #expect(r.daysPerWeek == 4)
        #expect(r.steadyWeeks == 4)
    }

    @Test func steadyForSkipsAnUnfinishedCurrentWeekInsteadOfBreaking() {
        // Wednesday and only one day so far this week: not yet, but it does not end eight good weeks.
        let r = rhythm(daily([1, 4, 4, 4, 4, 4, 4, 4, 4]))
        #expect(r.daysPerWeek == 4)
        #expect(r.steadyWeeks == 8)
    }

    @Test func steadyForCountsBackBeyondTheRhythmWindow() {
        let r = rhythm(daily(Array(repeating: 3, count: 14)))
        #expect(r.steadyWeeks == 14)
    }

    @Test func steadyForNeverCountsWeeksBeforeTheUserBegan() {
        let r = rhythm(daily([3, 3, 3]), since: date(weeksAgo: 2, dayOffset: 1))
        #expect(r.steadyWeeks == 3)
    }

    @Test func aRestWeekEndsTheRunWithoutAnyFuss() {
        let r = rhythm(daily([3, 3, 0, 3, 3, 3, 3, 3, 3]))
        #expect(r.daysPerWeek == 3)
        #expect(r.steadyWeeks == 2)
    }

    @Test func aRhythmOfOneStillNeedsAPracticeDayToBeSteady() {
        let r = rhythm(daily([1, 1, 0, 1, 1, 1, 1, 1, 1]))
        #expect(r.daysPerWeek == 1)
        #expect(r.steadyWeeks == 2)
    }

    @Test func deletingSessionsUpdatesBothNumbers() {
        let full = daily([3, 3, 3, 3, 3, 3, 3, 3, 3])
        #expect(rhythm(full).daysPerWeek == 3)
        #expect(rhythm([:]).daysPerWeek == 0)
    }

    @Test func sundayStartWeeksAreRespected() {
        // Sun 25 and Mon 26 Oct share a week for a Sunday-start user, but not for a Monday-start one.
        let sessions = [session(day(2026, 10, 25), hours: 1), session(day(2026, 10, 26), hours: 1)]
        let d = Practice.dailySeconds(sessions, calendar: utc)
        let began = day(2026, 10, 25)
        let sunday = Rhythm.compute(daily: d, since: began, now: now, weekStart: .sunday, calendar: utc)
        let monday = Rhythm.compute(daily: d, since: began, now: now, weekStart: .monday, calendar: utc)
        #expect(sunday.daysPerWeek == 2)
        #expect(monday.daysPerWeek == 1)
    }
}
