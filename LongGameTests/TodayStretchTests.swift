import Testing
import Foundation
@testable import LongGame

private func hours(_ h: Double) -> TimeInterval { h * 3600 }
private func mins(_ m: Double) -> TimeInterval { m * 60 }

private let wed = day(2026, 11, 11, hour: 9)

struct StretchRoundingTests {
    @Test func weeklyPaceDividedBySevenRoundedToFiveMinutes() {
        #expect(Stretch.stretch(weeklyHours: 7) == mins(60))
        #expect(Stretch.stretch(weeklyHours: 12) == mins(105))
        #expect(Stretch.stretch(weeklyHours: 3) == mins(25))
        #expect(Stretch.stretch(weeklyHours: 10) == mins(85))
        #expect(Stretch.stretch(weeklyHours: 0.5) == mins(5))
        // 100 h ÷ 7 = 857.1 min, which rounds to the nearest 5 minutes: 855.
        #expect(Stretch.stretch(weeklyHours: 100) == mins(855))
        #expect(Stretch.stretch(weeklyHours: 168) == hours(24))
    }

    @Test func neverZero() {
        #expect(Stretch.stretch(weeklyHours: 0.1) == mins(5))
    }

    @Test func theSameOnEveryWeekday() {
        for offset in 0..<7 {
            let now = day(2026, 11, 9 + offset, hour: 9)
            let s = Stretch.todayStretch(sessions: [], weeklyTargetHours: 12, now: now, weekStart: .monday, calendar: utc)
            #expect(s == .inProgress(target: mins(105), done: 0))
        }
    }

    @Test func otherDaysAndShortfallsNeverChangeIt() {
        let lightWeek = [session(day(2026, 11, 9), hours: 0.5)]
        let heavyWeek = [session(day(2026, 11, 9), hours: 12)]
        for sessions in [lightWeek, heavyWeek] {
            let s = Stretch.todayStretch(sessions: sessions, weeklyTargetHours: 12, now: wed, weekStart: .monday, calendar: utc)
            #expect(s.target == mins(105))
        }
    }

    @Test func startsAtNothingDone() {
        let s = Stretch.todayStretch(sessions: [], weeklyTargetHours: 12, now: wed, weekStart: .monday, calendar: utc)
        #expect(s.fraction == 0)
    }
}

struct StretchDoneTests {
    @Test func todaysOwnSessionsNeverChangeTodaysStretch() {
        let morning = Stretch.todayStretch(sessions: [], weeklyTargetHours: 12, now: day(2026, 11, 11, hour: 8), weekStart: .monday, calendar: utc)
        let evening = Stretch.todayStretch(sessions: [session(day(2026, 11, 11, hour: 9), hours: 1.5)],
                                           weeklyTargetHours: 12, now: day(2026, 11, 11, hour: 21), weekStart: .monday, calendar: utc)
        #expect(morning.target == evening.target)
        #expect(evening.done == hours(1.5))
    }

    @Test func doneCountsEverySessionThatStartsTodayPlusTheRunningTimer() {
        let sessions = [
            session(day(2026, 11, 11, hour: 7), hours: 0.5),                              // timer
            SessionRecord(start: day(2026, 11, 11, hour: 12), durationSec: 600),          // manual (noon)
            SessionRecord(start: day(2026, 11, 11, hour: 13), durationSec: 900, isCatchUp: true),
            session(day(2026, 11, 10, hour: 20), hours: 1),                               // yesterday: not today
        ]
        let s = Stretch.todayStretch(sessions: sessions, weeklyTargetHours: 20, now: day(2026, 11, 11, hour: 15),
                                     weekStart: .monday, running: 300, calendar: utc)
        #expect(s.done == 1800 + 600 + 900 + 300)
    }

    @Test func coveredOnceDoneReachesTheStretch() {
        let plan = Stretch.plan(sessions: [], weeklyTargetHours: 12, now: wed, weekStart: .monday, calendar: utc)
        #expect(plan.state(running: mins(104)) == .inProgress(target: mins(105), done: mins(104)))
        #expect(plan.state(running: mins(105)) == .covered(target: mins(105), done: mins(105)))
        #expect(plan.state(running: mins(200)).fraction == 1)
        #expect(plan.state(running: mins(200)).isCovered)
    }

    @Test func aSessionTakesTheStretchFromOpenToCoveredOnlyOnce() {
        let plan = StretchPlan(target: 3600, doneSaved: 1800)
        #expect(plan.isCovered(byAdding: 1800))
        #expect(!plan.isCovered(byAdding: 1799))
        #expect(plan.coveredAfter() == 1800)
        let done = StretchPlan(target: 3600, doneSaved: 3600)
        #expect(!done.isCovered(byAdding: 600))
        #expect(done.coveredAfter() == nil)
        #expect(!StretchPlan(target: nil, doneSaved: 0).isCovered(byAdding: 9999))
    }

    @Test func theTargetThatAppliesThisWeekComesFromTheHistory() {
        let old = TargetRecord(hoursPerWeek: 6, start: day(2025, 11, 1, hour: 0), end: day(2026, 11, 1, hour: 0))
        let current = TargetRecord(hoursPerWeek: 14, start: day(2026, 11, 1, hour: 0), end: day(2027, 11, 1, hour: 0))
        #expect(Stretch.weeklyTarget(now: day(2026, 11, 11), weekStart: .monday, periods: [old], current: current, calendar: utc) == 14)
        #expect(Stretch.weeklyTarget(now: day(2026, 3, 11), weekStart: .monday, periods: [old], current: current, calendar: utc) == 6)
        #expect(Stretch.weeklyTarget(now: day(2025, 3, 11), weekStart: .monday, periods: [old], current: current, calendar: utc) == nil)
    }

    @Test func noTargetNoStretch() {
        #expect(Stretch.todayStretch(sessions: [], weeklyTargetHours: nil, now: wed, weekStart: .monday, calendar: utc) == .noTarget)
        #expect(Stretch.todayStretch(sessions: [], weeklyTargetHours: 0, now: wed, weekStart: .monday, calendar: utc) == .noTarget)
        #expect(StretchState.noTarget.fraction == 0)
        #expect(!StretchState.noTarget.showsOnTimer)
    }

    @Test func aSessionCrossingMidnightCountsOnTheDayItStarted() {
        let late = SessionRecord(start: day(2026, 11, 10, hour: 23), durationSec: 7200)
        let s = Stretch.todayStretch(sessions: [late], weeklyTargetHours: 12, now: day(2026, 11, 11, hour: 8), weekStart: .monday, calendar: utc)
        #expect(s.done == 0)
        let t = Stretch.todayStretch(sessions: [late], weeklyTargetHours: 12, now: day(2026, 11, 10, hour: 23), weekStart: .monday, calendar: utc)
        #expect(t.done == 7200)
    }
}

struct StretchPictureTests {
    @Test func theSunSitsOnTheHorizonAtTheStartAndOnTheMoonAtTheEnd() {
        let start = StretchArc.point(fraction: 0, centreX: 195, baseY: 228, radiusX: 150, radiusY: 160)
        let end = StretchArc.point(fraction: 1, centreX: 195, baseY: 228, radiusX: 150, radiusY: 160)
        let top = StretchArc.point(fraction: 0.5, centreX: 195, baseY: 228, radiusX: 150, radiusY: 160)
        #expect(abs(start.x - 45) < 0.001 && abs(start.y - 228) < 0.001)
        #expect(abs(end.x - 345) < 0.001 && abs(end.y - 228) < 0.001)
        #expect(abs(top.x - 195) < 0.001 && abs(top.y - 68) < 0.001)
    }

    @Test func theDesignsSunPosition() {
        // 1 h 05 of 1 h 45: the design puts the sun's centre at about (249.7, 79).
        let p = StretchArc.point(fraction: 65.0 / 105, centreX: 195, baseY: 228, radiusX: 150, radiusY: 160)
        #expect(abs(p.x - 249.7) < 1.5 && abs(p.y - 79) < 1.5)
    }

    @Test func fractionsOutsideZeroToOneAreClamped() {
        let p = StretchArc.point(fraction: 2, centreX: 195, baseY: 228, radiusX: 150, radiusY: 160)
        #expect(abs(p.x - 345) < 0.001)
    }

    @Test func theNumbersReadLikeTheDesign() {
        #expect(StretchText.clock(seconds: mins(65)) == "1 h 05")
        #expect(StretchText.clock(seconds: mins(40)) == "40 m")
        #expect(StretchText.clock(seconds: 0) == "0 m")
        #expect(StretchText.clock(seconds: mins(59) + 59) == "59 m")
        #expect(StretchText.clock(seconds: 2 * 3600) == "2 h 00")
        #expect(StretchText.ofToday(mins(105)) == "of today's 1 h 45")
        #expect(StretchText.toGo(mins(40)) == "40 m to the moon")
        // A part-minute left still reads as a minute to go.
        #expect(StretchText.toGo(mins(39) + 10) == "40 m to the moon")
        #expect(StretchText.clockUp(seconds: 0) == "0 m")
    }

    @Test func voiceOverReadsThePictureAsOneSentence() {
        let s = StretchState.inProgress(target: mins(105), done: mins(65))
        #expect(StretchText.description(s) == "Today's stretch: 1 hour 5 minutes of 1 hour 45 minutes. 40 minutes to go.")
        #expect(StretchText.description(.covered(target: 3600, done: 3600)).hasPrefix("Today's stretch covered"))
    }

    @Test func homeOpensOnTodayAndLegacyValuesStillRead() {
        #expect(HomeTab.allCases == [.today, .week, .longGame])
        #expect(HomeTab(rawValue: "today") == .today)
        #expect(HomeTab(rawValue: "week") == .week)
    }
}
