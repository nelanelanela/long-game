import Testing
import Foundation
@testable import LongGame

// Update 44: the weekly look-back, small anniversaries, last week's bars, haptics.

private var fpUTC: Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "UTC")!
    c.locale = Locale(identifier: "en_GB")
    return c
}

private func fpDate(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ min: Int = 0) -> Date {
    fpUTC.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
}

private func entry(_ d: Date, minutes: Double, photo: Bool = false, views: Int = 0, note: String? = nil) -> WeekLookBack.Entry {
    .init(id: UUID(), start: d, seconds: minutes * 60, hasPhoto: photo, viewCount: views, note: note)
}

struct WeekLookBackTests {
    // Saturday 14 November 2026; last week (Monday start) is 2–8 November.
    let now = fpDate(2026, 11, 14)

    @Test func weekBoundariesWithAMondayStart() throws {
        let entries = [entry(fpDate(2026, 11, 1, 20), minutes: 60),  // Sunday before: the week before
                       entry(fpDate(2026, 11, 2, 0, 5), minutes: 30), // Monday just after midnight: in
                       entry(fpDate(2026, 11, 8, 23, 50), minutes: 45), // Sunday late: in
                       entry(fpDate(2026, 11, 9, 0, 10), minutes: 90)]  // this week: out
        let look = try #require(WeekLookBack.make(entries, now: now, weekStart: .monday, calendar: fpUTC))
        #expect(look.weekStart == fpDate(2026, 11, 2, 0))
        #expect(look.hours == 1.25)
        #expect(look.previousHours == 1)
        #expect(look.dates(calendar: fpUTC) == "2 – 8 November")
    }

    @Test func weekBoundariesWithASundayStart() throws {
        // Sunday start: last week is Sunday 1 – Saturday 7 November.
        let entries = [entry(fpDate(2026, 11, 1, 20), minutes: 60), entry(fpDate(2026, 11, 8, 10), minutes: 30)]
        let look = try #require(WeekLookBack.make(entries, now: now, weekStart: .sunday, calendar: fpUTC))
        #expect(look.weekStart == fpDate(2026, 11, 1, 0))
        #expect(look.hours == 1)
        #expect(look.dates(calendar: fpUTC) == "1 – 7 November")
    }

    @Test func nothingWhenLastWeekWasEmpty() {
        #expect(WeekLookBack.make([entry(fpDate(2026, 11, 10), minutes: 60)], now: now, weekStart: .monday, calendar: fpUTC) == nil)
    }

    @Test func theLongestDayAndItsTies() throws {
        // Tuesday and Thursday both 2 h: the later day wins.
        let entries = [entry(fpDate(2026, 11, 3), minutes: 120), entry(fpDate(2026, 11, 5), minutes: 120),
                       entry(fpDate(2026, 11, 4), minutes: 60)]
        let look = try #require(WeekLookBack.make(entries, now: now, weekStart: .monday, calendar: fpUTC))
        #expect(look.longestDay == 3)
        #expect(look.longestDayText(calendar: fpUTC) == "Thu · 2 h 00")
    }

    @Test func daysPlayed() throws {
        let entries = [entry(fpDate(2026, 11, 2, 9), minutes: 30), entry(fpDate(2026, 11, 2, 18), minutes: 30),
                       entry(fpDate(2026, 11, 4), minutes: 10), entry(fpDate(2026, 11, 8), minutes: 10)]
        let look = try #require(WeekLookBack.make(entries, now: now, weekStart: .monday, calendar: fpUTC))
        #expect(look.daysPlayed == 3)
    }

    @Test func thePartOfTheDayAndItsTies() throws {
        // An hour in the morning and an hour in the evening: the later part wins.
        let tie = [entry(fpDate(2026, 11, 2, 8), minutes: 60), entry(fpDate(2026, 11, 3, 19), minutes: 60)]
        #expect(try #require(WeekLookBack.make(tie, now: now, weekStart: .monday, calendar: fpUTC)).mostly == .evening)
        // More in the mornings.
        let mornings = [entry(fpDate(2026, 11, 2, 7), minutes: 90), entry(fpDate(2026, 11, 3, 19), minutes: 60)]
        #expect(try #require(WeekLookBack.make(mornings, now: now, weekStart: .monday, calendar: fpUTC)).mostly == .morning)
        // The session pictures' hours: 22:00 is night, 11:00 (midday) counts as morning, 13:00 as afternoon.
        #expect(WeekLookBack.Part.at(fpDate(2026, 11, 2, 22), calendar: fpUTC) == .night)
        #expect(WeekLookBack.Part.at(fpDate(2026, 11, 2, 11), calendar: fpUTC) == .morning)
        #expect(WeekLookBack.Part.at(fpDate(2026, 11, 2, 13), calendar: fpUTC) == .afternoon)
        #expect(WeekLookBack.Part.at(fpDate(2026, 11, 2, 4), calendar: fpUTC) == .night)
    }

    @Test func theComparisonLineOnlyWhenUp() throws {
        let before = [entry(fpDate(2026, 10, 27), minutes: 60)]
        let up = try #require(WeekLookBack.make(before + [entry(fpDate(2026, 11, 3), minutes: 135)], now: now, weekStart: .monday, calendar: fpUTC))
        #expect(up.moreThanBefore == TimeInterval(75 * 60))
        let level = try #require(WeekLookBack.make(before + [entry(fpDate(2026, 11, 3), minutes: 60)], now: now, weekStart: .monday, calendar: fpUTC))
        #expect(level.moreThanBefore == nil)
        let down = try #require(WeekLookBack.make(before + [entry(fpDate(2026, 11, 3), minutes: 20)], now: now, weekStart: .monday, calendar: fpUTC))
        #expect(down.moreThanBefore == nil)
    }

    @Test func whichMomentIsChosen() throws {
        let plain = entry(fpDate(2026, 11, 3, 19), minutes: 200, note: "Long one")
        let oldPhoto = entry(fpDate(2026, 11, 2, 9), minutes: 30, photo: true, views: 4)
        let newPhoto = entry(fpDate(2026, 11, 6, 20), minutes: 30, photo: true, views: 1)
        // The most viewed photo.
        var look = try #require(WeekLookBack.make([plain, oldPhoto, newPhoto], now: now, weekStart: .monday, calendar: fpUTC))
        #expect(look.moment?.sessionId == oldPhoto.id)
        #expect(look.moment?.kind == .photo)
        // No views: the most recent photo.
        var unseen = oldPhoto; unseen.viewCount = 0
        var unseen2 = newPhoto; unseen2.viewCount = 0
        look = try #require(WeekLookBack.make([plain, unseen, unseen2], now: now, weekStart: .monday, calendar: fpUTC))
        #expect(look.moment?.sessionId == newPhoto.id)
        // No photo: the longest session's picture, with its note.
        look = try #require(WeekLookBack.make([plain, entry(fpDate(2026, 11, 4), minutes: 20)], now: now, weekStart: .monday, calendar: fpUTC))
        #expect(look.moment?.sessionId == plain.id)
        #expect(look.moment?.kind == .sessionPicture)
        #expect(look.momentWhen(calendar: fpUTC) == "A moment from Tuesday evening")
        #expect(look.momentLine(calendar: fpUTC) == "Long one")
        // Without a note: its time and length.
        look = try #require(WeekLookBack.make([entry(fpDate(2026, 11, 4, 7, 30), minutes: 70)], now: now, weekStart: .monday, calendar: fpUTC))
        #expect(look.momentLine(calendar: fpUTC) == "07:30 · 1 h 10")
    }

    @Test func oncePerWeek() {
        let onboarded = fpDate(2026, 9, 1)
        let thisWeek = WeekMath.startOfWeek(now, weekStart: .monday, calendar: fpUTC)
        func show(_ last: Date?, running: Bool = false, sheet: Bool = false, had: Bool = true, onboarding: Date? = nil) -> Bool {
            WeekLookBack.shouldShow(now: now, weekStart: .monday, onboardingDate: onboarding ?? onboarded, lastShownWeek: last,
                                    lastWeekHadSession: had, sessionRunning: running, sheetOpen: sheet, calendar: fpUTC)
        }
        #expect(show(nil))
        #expect(show(fpDate(2026, 11, 2, 0)))
        #expect(!show(thisWeek))
        #expect(!show(nil, running: true))
        #expect(!show(nil, sheet: true))
        #expect(!show(nil, had: false))
        // Never in the very first week (the week of onboarding).
        #expect(!show(nil, onboarding: fpDate(2026, 11, 10)))
        #expect(show(nil, onboarding: fpDate(2026, 11, 5)))
    }

    @Test func theBarsReadAsOneSentence() throws {
        let look = try #require(WeekLookBack.make([entry(fpDate(2026, 11, 2), minutes: 90), entry(fpDate(2026, 11, 5), minutes: 130)],
                                                  now: now, weekStart: .monday, calendar: fpUTC))
        let spoken = look.spokenBars(calendar: fpUTC)
        #expect(spoken.hasPrefix("Last week, day by day: Monday 1 hour 30 minutes, Tuesday rest"))
        #expect(spoken.contains("Thursday 2 hours 10 minutes, the longest day"))
    }
}

struct AnniversaryTests {
    func today(_ logged: [Date], starts: [Date]? = nil, milestone: Bool = false, now: Date) -> Anniversary? {
        Anniversary.today(.init(loggedAt: logged, starts: starts ?? logged, hourMilestoneToday: milestone), now: now, calendar: fpUTC)
    }

    @Test func monthsAndYears() {
        let first = fpDate(2025, 11, 14, 9)
        #expect(today([first], now: fpDate(2025, 12, 14, 20)) == .months(1))
        #expect(today([first], now: fpDate(2026, 5, 14)) == .months(6))
        #expect(today([first], now: fpDate(2026, 11, 14)) == .years(1))
        #expect(today([first], now: fpDate(2027, 11, 14)) == .years(2))
        #expect(today([first], now: fpDate(2026, 11, 15)) == nil)
        #expect(Anniversary.years(1).line == "A year since you started.")
        #expect(Anniversary.years(2).line == "Two years since you started.")
        #expect(Anniversary.months(1).line == "A month since you started.")
        #expect(Anniversary.months(6).line == "Six months since you started.")
    }

    @Test func leapYears() {
        // Started on 29 February: the anniversary is on 28 February in other years, and on the 29th again in a leap year.
        let first = fpDate(2024, 2, 29)
        #expect(today([first], now: fpDate(2025, 2, 28)) == .years(1))
        #expect(today([first], now: fpDate(2025, 3, 1)) == nil)
        #expect(today([first], now: fpDate(2028, 2, 29)) == .years(4))
        // A month after 31 January is the end of February.
        #expect(today([fpDate(2026, 1, 31)], now: fpDate(2026, 2, 28)) == .months(1))
    }

    @Test func sessionCounts() {
        let now = fpDate(2026, 6, 10, 18)
        // 99 sessions logged over earlier days (one a day from 1 March), the 100th today.
        var logged = (0..<99).map { fpDate(2026, 3, 1).addingTimeInterval(Double($0) * 3600) }
        #expect(today(logged, starts: [fpDate(2026, 3, 1)], now: now) == nil)
        logged.append(fpDate(2026, 6, 10, 9))
        #expect(today(logged, starts: [fpDate(2026, 3, 1)], now: now) == .session(100))
        #expect(Anniversary.session(100).line == "Your 100th session.")
        #expect(Anniversary.session(1_000).line == "Your 1,000th session.")
        // The 10th.
        let ten = (0..<9).map { fpDate(2026, 6, 1).addingTimeInterval(Double($0) * 60) } + [fpDate(2026, 6, 10, 8)]
        #expect(today(ten, starts: [fpDate(2026, 6, 1)], now: now) == .session(10))
    }

    @Test func daysOfPractice() {
        let first = fpDate(2026, 1, 1)
        let starts = (0..<100).map { fpUTC.date(byAdding: .day, value: $0 * 2, to: first)! }
        let hundredth = starts.last!
        #expect(today([first], starts: starts, now: hundredth) == .practiceDays(100))
        #expect(Anniversary.practiceDays(100).line == "100 days of practice.")
        #expect(today([first], starts: starts, now: fpUTC.date(byAdding: .day, value: 1, to: hundredth)!) == nil)
    }

    @Test func thePriorityOrder() {
        let first = fpDate(2025, 11, 14, 9)
        let now = fpDate(2026, 11, 14, 18)
        // A year and a 10th session on the same day: the year.
        let logged = [first] + (0..<8).map { fpDate(2026, 3, 1).addingTimeInterval(Double($0)) } + [fpDate(2026, 11, 14, 10)]
        #expect(today(logged, starts: [first], now: now) == .years(1))
        // An hour milestone today: no line at all.
        #expect(today(logged, starts: [first], milestone: true, now: now) == nil)
        // A 10th session and six months: the session.
        let sixMonthsFirst = fpDate(2026, 5, 14, 9)
        let logged2 = [sixMonthsFirst] + (0..<8).map { fpDate(2026, 6, 1).addingTimeInterval(Double($0)) } + [fpDate(2026, 11, 14, 10)]
        #expect(today(logged2, starts: [sixMonthsFirst], now: now) == .session(10))
        // Days of practice beat months.
        let starts = (0..<100).map { fpUTC.date(byAdding: .day, value: -99 + $0, to: fpDate(2026, 11, 14))! }
        #expect(today([fpDate(2026, 10, 14, 9)], starts: starts, now: now) == .practiceDays(100))
        #expect(today([fpDate(2026, 10, 14, 9)], starts: [fpDate(2026, 10, 14)], now: now) == .months(1))
    }

    @Test func anHourMilestoneToday() {
        #expect(Anniversary.hourMilestoneToday(totalAtStartOfToday: 99.5, total: 100.2))
        #expect(!Anniversary.hourMilestoneToday(totalAtStartOfToday: 100.2, total: 101))
        #expect(Anniversary.hourMilestoneToday(totalAtStartOfToday: 9_999, total: 10_000))
    }
}

struct LastWeekBarsTests {
    let now = fpDate(2026, 11, 12)  // Thursday

    @Test func lastWeeksHoursByWeekday() throws {
        let sessions = [SessionRecord(start: fpDate(2026, 11, 5), durationSec: 7200), SessionRecord(start: fpDate(2026, 11, 2), durationSec: 1800)]
        let last = try #require(WeekBars.lastWeek(sessions: sessions, now: now, weekStart: .monday, onboardingDate: fpDate(2026, 1, 1), calendar: fpUTC))
        #expect(last == [0.5, 0, 0, 2, 0, 0, 0])
    }

    @Test func hiddenInTheFirstWeekAndAfterAnEmptyWeek() {
        let sessions = [SessionRecord(start: fpDate(2026, 11, 5), durationSec: 7200)]
        #expect(WeekBars.lastWeek(sessions: sessions, now: now, weekStart: .monday, onboardingDate: fpDate(2026, 11, 10), calendar: fpUTC) == nil)
        #expect(WeekBars.lastWeek(sessions: [SessionRecord(start: fpDate(2026, 11, 10), durationSec: 60)], now: now,
                                  weekStart: .monday, onboardingDate: fpDate(2026, 1, 1), calendar: fpUTC) == nil)
    }

    @Test func theSameScaleAsThisWeek() {
        #expect(WeekBars.barHeight(hours: 1.25) == 32)
        #expect(WeekBars.barHeight(hours: 5) == 64)
    }
}

struct HapticPlanTests {
    @Test func eachMomentsPattern() {
        for m in [HapticMoment.rayLit, .sessionSaved, .timeAdded, .undo] { #expect(m.pattern == .softTap) }
        #expect(HapticMoment.stretchCovered.pattern == .twoTaps)
        for m in [HapticMoment.hourMilestone, .weeklyPaceReached, .tenThousand] { #expect(m.pattern == .risingThree) }
        for m in [HapticMoment.stepper, .crown, .growthMilestone, .tabSwitch, .scrub] { #expect(m.pattern == .tick) }
        for m in [HapticMoment.error, .deleted, .paused, .stepperLimit] { #expect(m.pattern == .none) }
    }

    @Test func theStrongestWins() {
        #expect(HapticPlan.strongest([.sessionSaved, .stretchCovered, .hourMilestone]) == .risingThree)
        #expect(HapticPlan.strongest([.sessionSaved, .stretchCovered]) == .twoTaps)
        #expect(HapticPlan.strongest([.rayLit, .tabSwitch]) == .softTap)
        #expect(HapticPlan.strongest([]) == HapticPattern.none)
    }

    @Test func aSavesFeeling() {
        #expect(HapticPlan.strongest(HapticPlan.save(timer: true, coversStretch: false, reachesMilestone: false, reachesWeeklyPace: false)) == .softTap)
        #expect(HapticPlan.strongest(HapticPlan.save(timer: false, coversStretch: true, reachesMilestone: false, reachesWeeklyPace: false)) == .twoTaps)
        #expect(HapticPlan.strongest(HapticPlan.save(timer: true, coversStretch: true, reachesMilestone: false, reachesWeeklyPace: true)) == .risingThree)
        #expect(HapticPlan.strongest(HapticPlan.save(timer: true, coversStretch: true, reachesMilestone: true, reachesWeeklyPace: false)) == .risingThree)
    }
}
