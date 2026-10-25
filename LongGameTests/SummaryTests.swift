import Testing
import Foundation
@testable import LongGame

struct FormatTests {
    @Test func durations() {
        #expect(DurationFormat.short(seconds: 5400) == "1 h 30 m")
        #expect(DurationFormat.short(seconds: 7200) == "2 h")
        #expect(DurationFormat.short(seconds: 2700) == "45 m")
        #expect(DurationFormat.hoursMinutes(seconds: 7200) == "2:00")
        #expect(DurationFormat.clock(seconds: 42 * 60 + 18) == "42:18")
        #expect(DurationFormat.clock(seconds: 3725) == "1:02:05")
    }

    @Test func statText() {
        #expect(DurationFormat.hours(9.5) == "9.5 h")
        #expect(DurationFormat.hours(12.04) == "12 h")
        #expect(DurationFormat.perWeek(12) == "12 h/wk")
    }

    @Test func addLabels() {
        #expect(DurationFormat.addLabel(seconds: 0) == "Add hours")
        #expect(DurationFormat.addLabel(seconds: 3600) == "Add 1 hour")
        #expect(DurationFormat.addLabel(seconds: 7200) == "Add 2 hours")
        #expect(DurationFormat.addLabel(seconds: 5400) == "Add 1 h 30 m")
        #expect(DurationFormat.addLabel(seconds: 2700) == "Add 45 minutes")
    }

    @Test func relativeDays() {
        let now = day(2026, 10, 25)
        #expect(RelativeDay.label(day(2026, 10, 25, hour: 8), now: now, calendar: utc) == "Today")
        #expect(RelativeDay.label(day(2026, 10, 24), now: now, calendar: utc) == "Yesterday")
        #expect(RelativeDay.label(day(2026, 10, 22), now: now, calendar: utc) == "Thursday")
        #expect(RelativeDay.label(day(2026, 10, 1), now: now, calendar: utc) == "1 Oct")
        #expect(RelativeDay.label(day(2025, 10, 1), now: now, calendar: utc) == "1 Oct 2025")
        #expect(RelativeDay.full(day(2026, 10, 22), calendar: utc) == "Thursday, 22 October")
    }
}

struct SummaryTests {
    @Test func summaryCombinesBaselineAndLogged() {
        let now = day(2026, 10, 25)
        let est = [YearRate(year: 2025, hoursPerWeek: 10), YearRate(year: 2026, hoursPerWeek: 10)]
        let s = ProgressSummary.make(estimates: est, sessions: [session(day(2026, 10, 24), hours: 2)],
                                     onboardingDate: day(2026, 10, 20, hour: 0), weekStart: .monday, now: now, calendar: utc)
        let baseline = 10 * 52 + 10 * Baseline.weeksElapsedInYear(of: day(2026, 10, 20, hour: 0), calendar: utc)
        #expect(abs(s.baseline - baseline) < 0.0001)
        #expect(s.logged == 2)
        #expect(abs(s.total - (baseline + 2)) < 0.0001)
        #expect(s.thisWeek == 2)
        #expect(s.hasEnoughData == false)
        #expect(s.forecast.mid.monthsToGoal == nil)   // ~9,000 h to go at ~10 h/wk is beyond 15 years
    }

    @Test func twoWeeksOfData() {
        let now = day(2026, 10, 25)
        #expect(!ProgressSummary.hasTwoWeeksOfData([], now: now))
        #expect(!ProgressSummary.hasTwoWeeksOfData([session(day(2026, 10, 20), hours: 1)], now: now))
        #expect(ProgressSummary.hasTwoWeeksOfData([session(day(2026, 10, 1), hours: 1)], now: now))
    }

    @Test func dayLimit() {
        #expect(SessionRules.fits(existingSecondsThatDay: 20 * 3600, adding: 4 * 3600))
        #expect(!SessionRules.fits(existingSecondsThatDay: 20 * 3600, adding: 4 * 3600 + 60))
    }

    @Test func manualSessionsSitAtNoon() {
        let start = SessionRules.manualStart(on: day(2026, 10, 22, hour: 3), calendar: utc)
        #expect(start == day(2026, 10, 22, hour: 12))
    }
}
