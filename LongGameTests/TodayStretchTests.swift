import Testing
import Foundation
@testable import LongGame

private let min5: TimeInterval = 300
private let hour: TimeInterval = 3600

private func hours(_ h: Double) -> TimeInterval { h * hour }
private func mins(_ m: Double) -> TimeInterval { m * 60 }

/// Sessions of `length` hours on the given days (offsets from Monday, 0 = Monday) of each of the `weeks` weeks
/// before the week starting at `thisMonday`.
private func routine(weeks: Int, offsets: [Int], from thisMonday: Date, length: Double = 1) -> [SessionRecord] {
    var out: [SessionRecord] = []
    for back in 1...weeks {
        for offset in offsets {
            let d = utc.date(byAdding: .day, value: offset - 7 * back, to: thisMonday)!
            out.append(session(d, hours: length))
        }
    }
    return out
}

private func stretchTarget(_ state: StretchState) -> TimeInterval? { state.target }

// Mon 9 Nov 2026 starts the week used in most of these tests.
private let monday = day(2026, 11, 9, hour: 0)

struct StretchRoundingTests {
    @Test func roundsToTheNearestFiveMinutes() {
        // 10 h over 7 days = 85.7 min -> 85 min
        let s = Stretch.todayStretch(sessions: [], weeklyTargetHours: 10, now: day(2026, 11, 9, hour: 9), weekStart: .monday, calendar: utc)
        #expect(s.target == mins(85))
        // 12 h over 7 days = 102.9 min -> 105 min
        let t = Stretch.todayStretch(sessions: [], weeklyTargetHours: 12, now: day(2026, 11, 9, hour: 9), weekStart: .monday, calendar: utc)
        #expect(t.target == mins(105))
    }

    @Test func neverShorterThanFifteenMinutes() {
        // 1 h over 7 days = 8.6 min -> 15 min
        let s = Stretch.todayStretch(sessions: [], weeklyTargetHours: 1, now: day(2026, 11, 9, hour: 9), weekStart: .monday, calendar: utc)
        #expect(s.target == mins(15))
        #expect(Stretch.rounded(0) == mins(15))
        #expect(Stretch.rounded(mins(7)) == mins(15))
        #expect(Stretch.rounded(mins(22)) == mins(20))
        #expect(Stretch.rounded(mins(23)) == mins(25))
    }

    @Test func startsAtNothingDone() {
        let s = Stretch.todayStretch(sessions: [], weeklyTargetHours: 12, now: day(2026, 11, 9, hour: 9), weekStart: .monday, calendar: utc)
        #expect(s == .stretch(target: mins(105), done: 0))
        #expect(s.fraction == 0)
    }
}

struct StretchSpreadTests {
    @Test func aShortYesterdaySpreadsOverTheRemainingDays() {
        // Wed 11 Nov, target 12 h. Mon 2 h and Tue nothing: 10 h left over Wed...Sun (5 days) = 2 h.
        let sessions = [session(day(2026, 11, 9), hours: 2)]
        let s = Stretch.todayStretch(sessions: sessions, weeklyTargetHours: 12, now: day(2026, 11, 11, hour: 8), weekStart: .monday, calendar: utc)
        #expect(s.target == hours(2))
        // Had Tuesday been a full day (2 h) too, the rest of the week would be lighter: 8 h / 5 = 96 min -> 95 min.
        let fuller = sessions + [session(day(2026, 11, 10), hours: 2)]
        let t = Stretch.todayStretch(sessions: fuller, weeklyTargetHours: 12, now: day(2026, 11, 11, hour: 8), weekStart: .monday, calendar: utc)
        #expect(t.target == mins(95))
    }

    @Test func todaysOwnSessionsNeverChangeTodaysStretch() {
        let before = [session(day(2026, 11, 9), hours: 1)]
        let morning = Stretch.todayStretch(sessions: before, weeklyTargetHours: 12, now: day(2026, 11, 11, hour: 8), weekStart: .monday, calendar: utc)
        let evening = Stretch.todayStretch(sessions: before + [session(day(2026, 11, 11, hour: 9), hours: 1.5)],
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
        let plan = Stretch.plan(sessions: [], weeklyTargetHours: 12, now: day(2026, 11, 9, hour: 9), weekStart: .monday, calendar: utc)
        #expect(plan.state(running: mins(104)) == .stretch(target: mins(105), done: mins(104)))
        #expect(plan.state(running: mins(105)) == .covered(target: mins(105), done: mins(105)))
        #expect(plan.state(running: mins(200)).fraction == 1)
        #expect(plan.state(running: mins(200)).isCovered)
    }

    @Test func aSessionTakesTheStretchFromOpenToCoveredOnlyOnce() {
        let plan = StretchPlan(kind: .stretch(target: 3600), doneSaved: 1800)
        #expect(plan.isCovered(byAdding: 1800))
        #expect(!plan.isCovered(byAdding: 1799))
        #expect(plan.coveredAfter() == 1800)
        // Already covered before the session began: this session did not cover it.
        let done = StretchPlan(kind: .stretch(target: 3600), doneSaved: 3600)
        #expect(!done.isCovered(byAdding: 600))
        #expect(done.coveredAfter() == nil)
        #expect(!StretchPlan(kind: .restDay, doneSaved: 0).isCovered(byAdding: 9999))
    }

    @Test func theTargetThatAppliesThisWeekComesFromTheHistory() {
        let old = TargetRecord(hoursPerWeek: 6, start: day(2025, 11, 1, hour: 0), end: day(2026, 11, 1, hour: 0))
        let current = TargetRecord(hoursPerWeek: 14, start: day(2026, 11, 1, hour: 0), end: day(2027, 11, 1, hour: 0))
        #expect(Stretch.weeklyTarget(now: day(2026, 11, 11), weekStart: .monday, periods: [old], current: current, calendar: utc) == 14)
        #expect(Stretch.weeklyTarget(now: day(2026, 3, 11), weekStart: .monday, periods: [old], current: current, calendar: utc) == 6)
        #expect(Stretch.weeklyTarget(now: day(2025, 3, 11), weekStart: .monday, periods: [old], current: current, calendar: utc) == nil)
    }

    @Test func noTargetNoStretch() {
        #expect(Stretch.todayStretch(sessions: [], weeklyTargetHours: nil, now: day(2026, 11, 9), weekStart: .monday, calendar: utc) == .noTarget)
        #expect(Stretch.todayStretch(sessions: [], weeklyTargetHours: 0, now: day(2026, 11, 9), weekStart: .monday, calendar: utc) == .noTarget)
        #expect(StretchState.noTarget.fraction == 0)
    }
}

struct StretchPracticeDaysTests {
    @Test func noHistoryMeansEveryDayCounts() {
        #expect(Stretch.practiceDays(sessions: [], today: monday, weekStart: .monday, calendar: utc) == Set(1...7))
        // One full week of history is still too little.
        let oneWeek = routine(weeks: 1, offsets: [0, 2], from: monday)
        #expect(Stretch.practiceDays(sessions: oneWeek, today: monday, weekStart: .monday, calendar: utc) == Set(1...7))
    }

    @Test func aWeekdayCountsWhenPractisedInTwoOfTheLastFourFullWeeks() {
        // Mon, Wed, Fri every week for 4 weeks -> weekdays 2, 4, 6.
        let sessions = routine(weeks: 4, offsets: [0, 2, 4], from: monday)
        #expect(Stretch.practiceDays(sessions: sessions, today: day(2026, 11, 12), weekStart: .monday, calendar: utc) == [2, 4, 6])
    }

    @Test func aDayDoneOnlyOnceInFourWeeksDoesNotCount() {
        var sessions = routine(weeks: 4, offsets: [0, 2], from: monday)
        sessions.append(session(day(2026, 10, 24), hours: 1)) // a single Saturday
        #expect(Stretch.practiceDays(sessions: sessions, today: day(2026, 11, 12), weekStart: .monday, calendar: utc) == [2, 4])
    }

    @Test func twoOfFourIsEnoughEvenIfTheOtherTwoWereEmpty() {
        // Tuesdays in the two oldest of the four weeks only.
        let sessions = [session(day(2026, 10, 13), hours: 1), session(day(2026, 10, 20), hours: 1),
                        session(day(2026, 11, 3), hours: 0.01), // the newest full week: something else
                        session(day(2026, 10, 12), hours: 1)]
        let days = Stretch.practiceDays(sessions: sessions, today: day(2026, 11, 12), weekStart: .monday, calendar: utc)
        #expect(days.contains(3)) // Tuesday: 13 Oct and 20 Oct (and 3 Nov)
    }

    @Test func theCurrentWeekDoesNotCount() {
        // Sessions only in this week: no full weeks of history.
        let sessions = [session(day(2026, 11, 9), hours: 1), session(day(2026, 11, 10), hours: 1)]
        #expect(Stretch.practiceDays(sessions: sessions, today: day(2026, 11, 12), weekStart: .monday, calendar: utc) == Set(1...7))
    }

    @Test func weeksBeforeTheFirstSessionAreNotHistory() {
        // First session on Mon 26 Oct: the full weeks are 26 Oct and 2 Nov, so two is just enough.
        let sessions = [session(day(2026, 10, 26), hours: 1), session(day(2026, 11, 2), hours: 1)]
        #expect(Stretch.practiceDays(sessions: sessions, today: day(2026, 11, 12), weekStart: .monday, calendar: utc) == [2])
        // First session mid-week: that week is partial, so only one full week remains -> every day counts.
        let late = [session(day(2026, 10, 28), hours: 1), session(day(2026, 11, 2), hours: 1)]
        #expect(Stretch.practiceDays(sessions: late, today: day(2026, 11, 12), weekStart: .monday, calendar: utc) == Set(1...7))
    }

    @Test func fallsBackToEveryDayWhenNoneQualifies() {
        // Four full weeks, but each week a different single day.
        let sessions = [session(day(2026, 11, 2), hours: 1), session(day(2026, 10, 27), hours: 1),
                        session(day(2026, 10, 21), hours: 1), session(day(2026, 10, 16), hours: 1)]
        #expect(Stretch.practiceDays(sessions: sessions, today: day(2026, 11, 12), weekStart: .monday, calendar: utc) == Set(1...7))
    }
}

struct StretchRestAndWeekTests {
    @Test func aDayYouDoNotUsuallyPractiseIsARestDay() {
        // Mon/Wed/Fri habit; today is Tuesday 10 Nov.
        let sessions = routine(weeks: 4, offsets: [0, 2, 4], from: monday)
        let s = Stretch.todayStretch(sessions: sessions, weeklyTargetHours: 6, now: day(2026, 11, 10, hour: 10), weekStart: .monday, calendar: utc)
        #expect(s == .restDay(done: 0))
        #expect(s.fraction == 0)
    }

    @Test func playingOnARestDayIsCountedButStaysARestDay() {
        let sessions = routine(weeks: 4, offsets: [0, 2, 4], from: monday) + [session(day(2026, 11, 10, hour: 9), hours: 0.5)]
        let s = Stretch.todayStretch(sessions: sessions, weeklyTargetHours: 6, now: day(2026, 11, 10, hour: 10),
                                     weekStart: .monday, running: 600, calendar: utc)
        #expect(s == .restDay(done: 1800 + 600))
    }

    @Test func onlyPracticeDaysShareTheRemainingHours() {
        // Mon/Wed/Fri habit, target 6 h, nothing done yet this week. On Monday: 3 practice days left -> 2 h.
        let sessions = routine(weeks: 4, offsets: [0, 2, 4], from: monday)
        let mon = Stretch.todayStretch(sessions: sessions, weeklyTargetHours: 6, now: day(2026, 11, 9, hour: 8), weekStart: .monday, calendar: utc)
        #expect(mon.target == hours(2))
        // Wednesday with Monday's 1 h done: 5 h over Wed and Fri = 2.5 h.
        let wed = Stretch.todayStretch(sessions: sessions + [session(day(2026, 11, 9), hours: 1)], weeklyTargetHours: 6,
                                       now: day(2026, 11, 11, hour: 8), weekStart: .monday, calendar: utc)
        #expect(wed.target == hours(2.5))
    }

    @Test func theWeekAlreadyCoveredAtTheStartOfToday() {
        let sessions = [session(day(2026, 11, 9), hours: 7), session(day(2026, 11, 10), hours: 5.5)]
        let s = Stretch.todayStretch(sessions: sessions, weeklyTargetHours: 12, now: day(2026, 11, 11, hour: 8), weekStart: .monday, calendar: utc)
        #expect(s == .weekCovered(done: 0))
        #expect(s.fraction == 1 && s.isCovered)
        // Exactly the target counts as covered too.
        let exact = Stretch.todayStretch(sessions: [session(day(2026, 11, 9), hours: 12)], weeklyTargetHours: 12,
                                         now: day(2026, 11, 11, hour: 8), weekStart: .monday, calendar: utc)
        #expect(exact == .weekCovered(done: 0))
    }

    @Test func reachingTheTargetTodayDoesNotTurnTodayIntoWeekCovered() {
        // 11 h done before today, target 12: the stretch is 1 h (rounded stretch, min 15 m) and stays one all day.
        let before = [session(day(2026, 11, 9), hours: 11)]
        let s = Stretch.todayStretch(sessions: before + [session(day(2026, 11, 15, hour: 9), hours: 2)], weeklyTargetHours: 12,
                                     now: day(2026, 11, 15, hour: 20), weekStart: .monday, calendar: utc)
        #expect(s == .covered(target: hours(1), done: hours(2)))
    }

    @Test func noHistoryYetEveryDayCounts() {
        // Thu 12 Nov, nothing logged, 12 h: Thu...Sun = 4 days -> 3 h.
        let s = Stretch.todayStretch(sessions: [], weeklyTargetHours: 12, now: day(2026, 11, 12, hour: 8), weekStart: .monday, calendar: utc)
        #expect(s.target == hours(3))
    }

    @Test func theDebugOverridesShowEveryState() {
        let now = day(2026, 11, 11, hour: 8)
        #expect(Stretch.todayStretch(sessions: [], weeklyTargetHours: 12, now: now, weekStart: .monday, calendar: utc,
                                     hoursBeforeToday: 7).target == hours(1))
        #expect(Stretch.todayStretch(sessions: [], weeklyTargetHours: 12, now: now, weekStart: .monday, calendar: utc,
                                     hoursBeforeToday: 12) == .weekCovered(done: 0))
        #expect(Stretch.todayStretch(sessions: [], weeklyTargetHours: 12, now: now, weekStart: .monday, calendar: utc,
                                     forceRestDay: true) == .restDay(done: 0))
    }
}

struct StretchWeekStartTests {
    // Sun 15 Nov 2026: the last day of a Monday-start week, the first day of a Sunday-start week.
    private let sunday = day(2026, 11, 15, hour: 9)

    @Test func sundayIsTheLastDayWhenTheWeekStartsOnMonday() {
        let sessions = [session(day(2026, 11, 9), hours: 9)]
        let s = Stretch.todayStretch(sessions: sessions, weeklyTargetHours: 12, now: sunday, weekStart: .monday, calendar: utc)
        // 3 h left, 1 day left -> 3 h
        #expect(s.target == hours(3))
    }

    @Test func sundayIsTheFirstDayWhenTheWeekStartsOnSunday() {
        let sessions = [session(day(2026, 11, 9), hours: 9)]
        let s = Stretch.todayStretch(sessions: sessions, weeklyTargetHours: 12, now: sunday, weekStart: .sunday, calendar: utc)
        // A new week: nothing logged yet, 7 days left -> 12 h / 7 = 105 min
        #expect(s.target == mins(105))
    }

    @Test func practiceDaysFollowTheWeekStartToo() {
        // Sunday-start weeks: practice on Sun and Tue in the four weeks before the week starting Sun 8 Nov.
        let sundayStart = day(2026, 11, 8, hour: 0)
        var sessions: [SessionRecord] = []
        for back in 1...4 {
            for offset in [0, 2] { sessions.append(session(utc.date(byAdding: .day, value: offset - 7 * back, to: sundayStart)!, hours: 1)) }
        }
        let days = Stretch.practiceDays(sessions: sessions, today: day(2026, 11, 12), weekStart: .sunday, calendar: utc)
        #expect(days == [1, 3])
    }
}

struct StretchTimeTests {
    @Test func aSessionCrossingMidnightCountsOnTheDayItStarted() {
        // 23:30 on Wed 11 Nov for 1.5 h: it is Wednesday's, not Thursday's.
        let late = SessionRecord(start: day(2026, 11, 11, hour: 23).addingTimeInterval(1800), durationSec: 5400)
        let thursday = Stretch.todayStretch(sessions: [late], weeklyTargetHours: 12, now: day(2026, 11, 12, hour: 9), weekStart: .monday, calendar: utc)
        #expect(thursday.done == 0)
        // ... and it counts as hours before Thursday, so Thursday's stretch is (12 - 1.5) / 4 = 2.625 h -> 2 h 40.
        #expect(thursday.target == mins(160))
        let wednesday = Stretch.todayStretch(sessions: [late], weeklyTargetHours: 12, now: day(2026, 11, 11, hour: 23).addingTimeInterval(3000),
                                             weekStart: .monday, calendar: utc)
        #expect(wednesday.done == 5400)
    }

    @Test func aTimeZoneChangeMovesWhereTheDayBegins() {
        var tokyo = utc
        tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        // 10:00 UTC on Thu 12 Nov is 19:00 Thursday in Tokyo; "now" 22:00 UTC is 07:00 on Friday there.
        let sessions = [session(day(2026, 11, 12, hour: 10), hours: 1)]
        let now = day(2026, 11, 12, hour: 22)
        let here = Stretch.todayStretch(sessions: sessions, weeklyTargetHours: 12, now: now, weekStart: .monday, calendar: utc)
        let there = Stretch.todayStretch(sessions: sessions, weeklyTargetHours: 12, now: now, weekStart: .monday, calendar: tokyo)
        #expect(here.done == hours(1))   // still Thursday: it counts today
        #expect(there.done == 0)         // already Friday: it was yesterday
        // Friday in Tokyo: (12 - 1) h over Fri, Sat, Sun = 3.67 h -> 3 h 40
        #expect(there.target == mins(220))
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
        #expect(StretchText.toGo(mins(40)) == "40 m to today's resting place")
        // A part-minute left still reads as a minute to go.
        #expect(StretchText.toGo(mins(39) + 10) == "40 m to today's resting place")
        #expect(StretchText.clockUp(seconds: 0) == "0 m")
    }

    @Test func voiceOverReadsThePictureAsOneSentence() {
        let s = StretchState.stretch(target: mins(105), done: mins(65))
        #expect(StretchText.description(s) == "Today's stretch: 1 hour 5 minutes of 1 hour 45 minutes. 40 minutes to go.")
        #expect(StretchText.description(.restDay(done: 0)) == "Rest day: the sun is resting on the horizon.")
        #expect(StretchText.description(.covered(target: 3600, done: 3600)).hasPrefix("Today's stretch covered"))
    }

    @Test func homeOpensOnTodayAndLegacyValuesStillRead() {
        #expect(HomeTab.allCases == [.today, .week, .longGame])
        #expect(HomeTab(rawValue: "today") == .today)
        #expect(HomeTab(rawValue: "week") == .week)
    }
}
