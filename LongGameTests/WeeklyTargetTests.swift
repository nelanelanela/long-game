import Testing
import Foundation
import SwiftData
@testable import LongGame

private func record(_ hours: Double, _ start: Date, _ end: Date) -> TargetRecord {
    TargetRecord(hoursPerWeek: hours, start: start, end: end)
}

struct TargetWindowTests {
    @Test func theYearIsTwelveMonthsFromTheDayItIsSet() {
        let start = WeeklyTarget.startDay(day(2026, 11, 2, hour: 15), calendar: utc)
        #expect(start == day(2026, 11, 2, hour: 0))
        #expect(WeeklyTarget.endDate(from: start, calendar: utc) == day(2027, 11, 2, hour: 0))
        // Not the calendar year: a target set in December runs into next December.
        #expect(WeeklyTarget.endDate(from: day(2026, 12, 20, hour: 0), calendar: utc) == day(2027, 12, 20, hour: 0))
    }

    @Test func aLeapDaySetsTheLastDayOfFebruaryNextYear() {
        #expect(WeeklyTarget.endDate(from: day(2028, 2, 29, hour: 0), calendar: utc) == day(2029, 2, 28, hour: 0))
    }

    @Test func theSliderRunsFromOneTo168InHalfHours() {
        #expect(WeeklyTarget.clamped(0) == 1)
        #expect(WeeklyTarget.clamped(55) == 55)
        #expect(WeeklyTarget.clamped(200) == 168)
        #expect(WeeklyTarget.clamped(6.3) == 6.5)
        #expect(WeeklyTarget.clamped(6.2) == 6)
    }

    @Test func theSliderStartsOnTheRecentPaceRoundedToWholeHours() {
        #expect(WeeklyTarget.suggested(pace: 11.6) == 12)
        #expect(WeeklyTarget.suggested(pace: 0.2) == 1)
        #expect(WeeklyTarget.suggested(pace: 60) == 60)
        #expect(WeeklyTarget.suggested(pace: 500) == 168)
    }

    @Test func theCardShowsADayAndAYearOfHours() {
        #expect(WeeklyTarget.perDay(12) == "1 h 43 m a day")
        #expect(WeeklyTarget.perDay(7) == "1 h a day")
        #expect(WeeklyTarget.addedHours(12) == 624)
        #expect(WeeklyTarget.number(12) == "12")
        #expect(WeeklyTarget.number(12.5) == "12.5")
    }
}

struct TargetHistoryTests {
    let first = record(8, day(2025, 3, 1, hour: 0), day(2026, 3, 1, hour: 0))

    @Test func theOldTargetEndsTheDayANewOneStarts() throws {
        let closed = try #require(TargetHistory.closing(first, on: day(2026, 3, 9, hour: 18), calendar: utc))
        #expect(closed.hoursPerWeek == 8)
        #expect(closed.start == first.start)
        // It carried on for eight days after its twelve months, so that is when it ends.
        #expect(closed.end == day(2026, 3, 9, hour: 0))
    }

    @Test func changingItMidYearEndsItToday() throws {
        let closed = try #require(TargetHistory.closing(first, on: day(2025, 9, 1, hour: 10), calendar: utc))
        #expect(closed.end == day(2025, 9, 1, hour: 0))
    }

    @Test func changingItOnTheDayItWasSetJustReplacesIt() {
        #expect(TargetHistory.closing(first, on: day(2025, 3, 1, hour: 20), calendar: utc) == nil)
        #expect(TargetHistory.closing(nil, on: day(2025, 3, 1), calendar: utc) == nil)
    }

    @Test func aPastDayIsJudgedAgainstTheTargetOfItsTime() {
        let second = record(12, day(2026, 3, 9, hour: 0), day(2027, 3, 9, hour: 0))
        let periods = [record(8, day(2025, 3, 1, hour: 0), day(2026, 3, 9, hour: 0))]
        #expect(TargetHistory.hours(on: day(2025, 6, 1), periods: periods, current: second) == 8)
        #expect(TargetHistory.hours(on: day(2026, 3, 8), periods: periods, current: second) == 8)
        #expect(TargetHistory.hours(on: day(2026, 3, 9), periods: periods, current: second) == 12)
        #expect(TargetHistory.hours(on: day(2026, 12, 25), periods: periods, current: second) == 12)
    }

    @Test func thereIsNoTargetBeforeTheFirstOne() {
        #expect(TargetHistory.hours(on: day(2025, 2, 28), periods: [], current: first) == nil)
        #expect(TargetHistory.hours(on: day(2025, 2, 28), periods: [], current: nil) == nil)
    }

    @Test func theOldTargetCarriesOnUntilANewOneIsSet() {
        #expect(TargetHistory.hours(on: day(2026, 8, 1), periods: [], current: first) == 8)
    }

    @Test func aWeekUsesTheTargetInForceOnItsLastDay() {
        let second = record(12, day(2026, 3, 11, hour: 0), day(2027, 3, 11, hour: 0))
        let periods = [record(8, day(2025, 3, 1, hour: 0), day(2026, 3, 11, hour: 0))]
        // The week of Mon 9 Mar 2026 ends Sun 15 Mar: the new target, set on the Wednesday, counts for all of it.
        #expect(TargetHistory.hours(forWeekStarting: day(2026, 3, 9, hour: 0), periods: periods, current: second, calendar: utc) == 12)
        #expect(TargetHistory.hours(forWeekStarting: day(2026, 3, 2, hour: 0), periods: periods, current: second, calendar: utc) == 8)
    }
}

struct TargetCycleTests {
    let start = day(2026, 11, 2, hour: 0)
    var target: TargetRecord { record(12, start, WeeklyTarget.endDate(from: start, calendar: utc)) }

    @Test func itRunsQuietlyUntilTwoWeeksBeforeTheEnd() {
        #expect(TargetCycle.phase(target, now: day(2026, 11, 3), calendar: utc) == .running)
        #expect(TargetCycle.phase(target, now: day(2027, 10, 18), calendar: utc) == .running)
        #expect(TargetCycle.reminder(target, now: day(2027, 10, 18), calendar: utc) == nil)
    }

    @Test func theReminderStartsFourteenDaysBeforeTheEnd() {
        #expect(TargetCycle.phase(target, now: day(2027, 10, 19), calendar: utc) == .endingSoon(daysLeft: 14))
        #expect(TargetCycle.phase(target, now: day(2027, 11, 1, hour: 23), calendar: utc) == .endingSoon(daysLeft: 1))
        #expect(TargetCycle.reminder(target, now: day(2027, 10, 19), calendar: utc)
                == "Your year of pace ends on 2 Nov. Choose the next one.")
    }

    @Test func afterTheEndDateTheReminderStaysUntilANewTargetIsSet() {
        #expect(TargetCycle.phase(target, now: day(2027, 11, 2, hour: 8), calendar: utc) == .ended)
        #expect(TargetCycle.phase(target, now: day(2028, 2, 1), calendar: utc) == .ended)
        #expect(TargetCycle.reminder(target, now: day(2027, 11, 5), calendar: utc)
                == "Your year of pace ended on 2 Nov. Choose the next one.")
    }

    @Test func noTargetMeansNothingChosenYet() {
        #expect(TargetCycle.phase(nil, now: start, calendar: utc) == .notSet)
        #expect(TargetCycle.phase(record(0, start, start), now: start, calendar: utc) == .notSet)
        #expect(TargetCycle.reminder(nil, now: start, calendar: utc) == nil)
    }

    @Test func theSheetOpensOnceOnTheFirstOpenAfterTheEnd() {
        let after = day(2027, 11, 3)
        #expect(TargetCycle.shouldOpenSheet(target, promptShownAt: nil, now: after, calendar: utc))
        // Already shown since the year ended: leave it to the reminder in the target row.
        #expect(!TargetCycle.shouldOpenSheet(target, promptShownAt: day(2027, 11, 3, hour: 9), now: day(2027, 11, 9), calendar: utc))
        // Shown for an earlier year: this year's end is new.
        #expect(TargetCycle.shouldOpenSheet(target, promptShownAt: day(2026, 11, 3), now: after, calendar: utc))
    }

    @Test func theSheetStaysClosedWhileTheYearRuns() {
        #expect(!TargetCycle.shouldOpenSheet(target, promptShownAt: nil, now: day(2027, 3, 1), calendar: utc))
        #expect(!TargetCycle.shouldOpenSheet(target, promptShownAt: nil, now: day(2027, 10, 25), calendar: utc))
    }

    @Test func aGameWithoutATargetIsAskedOnce() {
        #expect(TargetCycle.shouldOpenSheet(nil, promptShownAt: nil, now: start, calendar: utc))
        #expect(!TargetCycle.shouldOpenSheet(nil, promptShownAt: start, now: start, calendar: utc))
    }

    @Test func untilANewOneIsSetTheOldTargetStillCounts() {
        let ended = target
        #expect(TargetHistory.hours(on: day(2027, 12, 1), periods: [], current: ended) == 12)
    }
}

struct TargetForecastTests {
    let now = day(2026, 11, 2, hour: 0)
    var target: TargetRecord { record(11, now, WeeklyTarget.endDate(from: now, calendar: utc)) }
    let estimates = [YearRate(year: 2025, hoursPerWeek: 10), YearRate(year: 2026, hoursPerWeek: 10)]

    private func make(_ target: TargetRecord?, extra: Double = 0) -> ProgressSummary {
        ProgressSummary.make(estimates: estimates, sessions: [], onboardingDate: now, weekStart: .monday,
                             now: now, extra: extra, target: target, calendar: utc)
    }

    @Test func theChosenLineRunsOnTheChosenPaceWhateverThePlayedPaceIs() throws {
        // A 30 h target is far from the actual pace of about 10, and still sets the finish line.
        let bold = make(record(30, now, WeeklyTarget.endDate(from: now, calendar: utc)))
        let plain = make(nil)
        #expect(bold.chosenPace == 30)
        #expect(bold.forecast.chosenRate == 30)
        #expect(bold.forecast.actualRate == plain.forecast.actualRate)
        #expect(bold.forecast.actual == plain.forecast.actual)
        let sooner = try #require(bold.forecast.chosen.monthsToGoal)
        let later = try #require(plain.forecast.chosen.monthsToGoal)
        #expect(sooner < later)
    }

    @Test func theChosenPaceStaysAfterItsTwelveMonths() {
        let old = record(11, day(2025, 1, 2, hour: 0), day(2026, 1, 2, hour: 0))
        #expect(make(old).chosenPace == 11)
    }

    @Test func withoutATargetTheChosenPaceIsTheRecentPace() {
        let s = make(nil)
        #expect(s.chosenPace == s.forecastPace)
        #expect(s.forecast.chosen == s.forecast.actual)
        #expect(make(record(0, now, now)).chosenPace == s.forecastPace)
    }

    @Test func theWhatIfExtraMovesOnlyTheChosenLine() throws {
        let t = target
        let base = make(t), more = make(t, extra: 5)
        #expect(more.forecast.chosenRate == 16)
        #expect(more.forecast.actual == base.forecast.actual)
        let a = try #require(base.forecast.chosen.monthsToGoal), b = try #require(more.forecast.chosen.monthsToGoal)
        #expect(b < a)
    }

    @Test func theWhatIfDifferenceIsTheGapBetweenTheTwoChosenDates() throws {
        let t = target
        let base = try #require(make(t).forecast.chosen.monthsToGoal)
        let more = try #require(make(t, extra: 5).forecast.chosen.monthsToGoal)
        let sooner = try #require(ForecastEngine.monthsSooner(total: make(t).total, chosenPace: 11, extra: 5))
        #expect(abs(sooner - (base - more)) < 1e-9)
    }
}

struct WeekTargetTests {
    // Thursday 5 Nov 2026; weeks start on Monday.
    let thursday = day(2026, 11, 5)

    @Test func theRowSaysHowMuchIsLeftAndHowManyDays() {
        let week = WeekTarget.make(hoursThisWeek: 6.5, target: 12, now: thursday, weekStart: .monday, calendar: utc)
        #expect(week.headline == "5.5 h to go · 3 days left")
        #expect(week.percent == 54)
        #expect(abs(week.fraction - 6.5 / 12) < 0.0001)
        #expect(!week.reached)
    }

    @Test func oncePassedItSaysHowFarOver() {
        let week = WeekTarget.make(hoursThisWeek: 13.5, target: 12, now: thursday, weekStart: .monday, calendar: utc)
        #expect(week.headline == "Target reached · +1.5 h")
        #expect(week.fraction == 1)
        #expect(week.reached)
        #expect(WeekTarget.make(hoursThisWeek: 12, target: 12, now: thursday, weekStart: .monday, calendar: utc).headline
                == "Target reached · +0 h")
    }

    @Test func daysLeftFollowsTheWeekStart() {
        #expect(WeekTarget.daysLeft(now: day(2026, 11, 2), weekStart: .monday, calendar: utc) == 6)
        #expect(WeekTarget.daysLeft(now: day(2026, 11, 8), weekStart: .monday, calendar: utc) == 0)
        // Sunday 1 Nov starts a Sunday week; Thursday 5 Nov is its fifth day.
        #expect(WeekTarget.daysLeft(now: thursday, weekStart: .sunday, calendar: utc) == 2)
    }

    @Test func theLastDaysReadNaturally() {
        let sun = WeekTarget.make(hoursThisWeek: 1, target: 12, now: day(2026, 11, 8), weekStart: .monday, calendar: utc)
        #expect(sun.headline == "11 h to go · last day")
        let sat = WeekTarget.make(hoursThisWeek: 1, target: 12, now: day(2026, 11, 7), weekStart: .monday, calendar: utc)
        #expect(sat.headline == "11 h to go · 1 day left")
    }
}

struct TargetSavingTests {
    private func makeContext() throws -> ModelContext {
        let schema = Schema([Craft.self, YearEstimate.self, Session.self, AppSettings.self, TargetPeriod.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        return ModelContext(container)
    }

    @Test func savingSetsTheYearFromToday() throws {
        let context = try makeContext()
        let settings = AppSettings()
        context.insert(settings)
        TargetSaving.apply(hours: 12, now: day(2026, 11, 2, hour: 15), settings: settings, context: context, calendar: utc)
        #expect(settings.weeklyTargetHours == 12)
        #expect(settings.targetSetAt == day(2026, 11, 2, hour: 0))
        #expect(settings.targetEndsAt == day(2027, 11, 2, hour: 0))
        #expect(try context.fetchCount(FetchDescriptor<TargetPeriod>()) == 0)
    }

    @Test func aNewTargetMovesTheOldOneIntoTheHistory() throws {
        let context = try makeContext()
        let settings = AppSettings()
        context.insert(settings)
        TargetSaving.apply(hours: 12, now: day(2026, 11, 2), settings: settings, context: context, calendar: utc)
        // Changed in the spring: the 12 months restart from that day.
        TargetSaving.apply(hours: 15, now: day(2027, 4, 10, hour: 9), settings: settings, context: context, calendar: utc)
        let periods = try context.fetch(FetchDescriptor<TargetPeriod>())
        #expect(periods.count == 1)
        #expect(periods.first?.hoursPerWeek == 12)
        #expect(periods.first?.start == day(2026, 11, 2, hour: 0))
        #expect(periods.first?.end == day(2027, 4, 10, hour: 0))
        #expect(settings.weeklyTargetHours == 15)
        #expect(settings.targetEndsAt == day(2028, 4, 10, hour: 0))
        #expect(TargetHistory.hours(on: day(2027, 1, 1), periods: periods.map(\.record), current: settings.currentTarget) == 12)
        #expect(TargetHistory.hours(on: day(2027, 6, 1), periods: periods.map(\.record), current: settings.currentTarget) == 15)
    }

    @Test func savingTwiceOnTheSameDayLeavesNoEmptyPeriod() throws {
        let context = try makeContext()
        let settings = AppSettings()
        context.insert(settings)
        TargetSaving.apply(hours: 12, now: day(2026, 11, 2, hour: 9), settings: settings, context: context, calendar: utc)
        TargetSaving.apply(hours: 14, now: day(2026, 11, 2, hour: 18), settings: settings, context: context, calendar: utc)
        #expect(try context.fetchCount(FetchDescriptor<TargetPeriod>()) == 0)
        #expect(settings.weeklyTargetHours == 14)
    }

    @Test func onboardingSavesTheCraftTheEstimatesAndTheTarget() throws {
        let context = try makeContext()
        let model = OnboardingModel(now: Date(), calendar: .current)
        model.craftName = "Piano"
        model.hours[model.currentYear] = 8
        model.targetHours = 9.5
        model.save(in: context)
        let settings = try #require(try context.fetch(FetchDescriptor<AppSettings>()).first)
        #expect(try context.fetchCount(FetchDescriptor<Craft>()) == 1)
        #expect(settings.weeklyTargetHours == 9.5)
        #expect(settings.currentTarget != nil)
        // Home opens on The long game right after onboarding, then on This week at every launch after that.
        #expect(settings.lastHomeTab == .longGame)
        #expect(model.actualPace == 8)
        // The iCloud choice from the last step is saved with the rest (on by default).
        #expect(settings.syncEnabled)
    }

    @Test func onboardingSavesAnICloudSwitchThatWasTurnedOff() throws {
        let context = try makeContext()
        let model = OnboardingModel(now: Date(), calendar: .current)
        model.craftName = "Piano"
        model.targetHours = 5
        model.saveToICloud = false
        model.save(in: context)
        let settings = try #require(try context.fetch(FetchDescriptor<AppSettings>()).first)
        #expect(!settings.syncEnabled)
    }
}
