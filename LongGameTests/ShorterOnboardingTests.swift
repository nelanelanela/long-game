import Testing
import Foundation
import SwiftData
@testable import LongGame

/// Update 53: a shorter, clearer onboarding.
struct ShorterOnboardingTests {
    // MARK: The baseline with a total for this year

    @Test func aTotalForTheOnboardingYearIsItsBaseline() {
        let onboarding = day(2026, 11, 21)
        let withTotal = [YearRate(year: 2026, hoursPerWeek: 1, totalHours: 40)]
        #expect(Baseline.hours(estimates: withTotal, onboardingDate: onboarding, calendar: utc) == 40)
        // Without one, hours a week × weeks elapsed, as before.
        let weeks = Baseline.weeksElapsedInYear(of: onboarding, calendar: utc)
        let without = [YearRate(year: 2026, hoursPerWeek: 2)]
        #expect(abs(Baseline.hours(estimates: without, onboardingDate: onboarding, calendar: utc) - 2 * weeks) < 0.0001)
    }

    @Test func earlierYearsStillCountFiftyTwoWeeksBesideATotal() {
        let est = [YearRate(year: 2025, hoursPerWeek: 10), YearRate(year: 2026, hoursPerWeek: 1, totalHours: 40)]
        #expect(Baseline.hours(estimates: est, onboardingDate: day(2026, 11, 21), calendar: utc) == 520 + 40)
    }

    @Test func theGrowthLineBeforeSetupGrowsEvenlyToTheTotal() {
        let onboarding = day(2026, 7, 2)
        let est = [YearRate(year: 2026, hoursPerWeek: 2, totalHours: 52)]
        let halfway = Baseline.hours(estimates: est, onboardingDate: onboarding, upTo: day(2026, 4, 2), calendar: utc)
        #expect(halfway > 20 && halfway < 32)
        #expect(Baseline.hours(estimates: est, onboardingDate: onboarding, upTo: onboarding, calendar: utc) == 52)
    }

    @Test func theWeeklyRateBesideATotalIsRoundedToHalfHours() {
        // 21 November: 46 weeks since 1 January.
        let rate = Baseline.weeklyRate(totalHours: 40, onboardingDate: day(2026, 11, 21), calendar: utc)
        #expect(rate == 1)
        #expect(Baseline.weeklyRate(totalHours: 0, onboardingDate: day(2026, 11, 21), calendar: utc) == 0)
        // In the first week it counts as one week.
        #expect(Baseline.weeklyRate(totalHours: 7, onboardingDate: day(2026, 1, 2), calendar: utc) == 7)
    }

    @Test func startedThisYearSavesTheTotalAndARate() throws {
        let context = try makeContext()
        let model = OnboardingModel(now: day(2026, 11, 21), calendar: utc)
        model.craftName = "Calligraphy"
        model.startYear = model.currentYear
        model.soFarTotal = 40
        model.targetHours = 5
        model.save(in: context)
        let estimates = try context.fetch(FetchDescriptor<YearEstimate>())
        #expect(estimates.count == 1)
        #expect(estimates.first?.totalHours == 40)
        #expect(estimates.first?.hoursPerWeek == 1)
        #expect(model.estimatedSoFar() == 40)
        #expect(model.actualPace == 5)
    }

    @Test func editingTheYearAsHoursAWeekClearsTheTotal() {
        let estimate = YearEstimate(craftId: UUID(), year: 2026, hoursPerWeek: 1, totalHours: 40)
        #expect(estimate.rate.totalHours == 40)
        estimate.setHoursPerWeek(3)
        #expect(estimate.totalHours == nil)
        #expect(estimate.hoursPerWeek == 3)
    }

    @Test func goingBackToAnEarlierYearFillsThisYearFromTheTotal() {
        let model = OnboardingModel(now: day(2026, 11, 21), calendar: utc)
        model.startYear = 2026
        model.soFarTotal = 92
        model.soFarSeen = true
        model.startYear = 2023
        #expect(!model.startedThisYear)
        #expect(model.hoursFor(2026) == 2)
        #expect(model.hoursFor(2025) == 5)
    }

    @Test func widgetSnapshotsFromBeforeTheTotalStillDecode() throws {
        let old = #"{"year":2026,"hoursPerWeek":4}"#.data(using: .utf8)!
        let estimate = try JSONDecoder().decode(WidgetSnapshot.Estimate.self, from: old)
        #expect(estimate.totalHours == nil)
    }

    // MARK: The link card

    @Test func theLinkCardHasFourCases() {
        let several = SetupLink.make(estimates: [YearRate(year: 2024, hoursPerWeek: 8), YearRate(year: 2025, hoursPerWeek: 12),
                                                 YearRate(year: 2026, hoursPerWeek: 10)], currentYear: 2026)
        #expect(several == .lastYear(hoursPerWeek: 12))
        #expect(several.bold == "Last year: 12 h a week.")
        #expect(several.muted == "Keep that pace, or change it.")

        let thisYear = SetupLink.make(estimates: [YearRate(year: 2026, hoursPerWeek: 6)], currentYear: 2026)
        #expect(thisYear.bold == "This year so far: 6 h a week.")
        #expect(thisYear.muted == "Keep that pace, or change it.")

        let total = SetupLink.make(estimates: [YearRate(year: 2026, hoursPerWeek: 1, totalHours: 40)], currentYear: 2026)
        #expect(total.bold == "So far: 40 h.")
        #expect(total.muted == "Now choose a pace for each week.")

        let zero = SetupLink.make(estimates: [YearRate(year: 2026, hoursPerWeek: 0, totalHours: 0)], currentYear: 2026)
        #expect(zero == .fromZero)
        #expect(zero.bold == "Starting from zero.")
        #expect(zero.muted == "Pick a pace you can keep.")
    }

    // MARK: The finish line

    @Test func theFinishLineSentence() {
        let now = day(2026, 11, 21)
        // 3,100 h at 12 h a week: 6,900 ÷ 12 ≈ 575 weeks, about 11 years.
        let normal = FinishLineText.sentence(total: 3_100, weeklyRate: 12, now: now, calendar: utc)
        #expect(normal.hasPrefix("At this pace, you reach 10,000 h around "))
        #expect(normal.hasSuffix("2037"))
        #expect(FinishLineText.sentence(total: 0, weeklyRate: 1, now: now, calendar: utc)
                == "At this pace, you reach 10,000 h after 2056")
        #expect(FinishLineText.sentence(total: 10_200, weeklyRate: 5, now: now, calendar: utc) == "You're already past 10,000 h")
    }

    @Test func theFinishChipAndTheSpokenScene() {
        let now = day(2026, 11, 21)
        #expect(FinishLineText.chip(total: 3_100, weeklyRate: 12, now: now, calendar: utc).hasPrefix("Finish line ~"))
        #expect(FinishLineText.chip(total: 0, weeklyRate: 1, now: now, calendar: utc) == "Finish line after 2056")
        let scene = SetupSceneState(craftName: "Calligraphy", startYear: 2019, score: 3_100, weeklyPace: 12, showsFinish: true, now: now)
        #expect(scene.spoken.hasPrefix("Your game: Calligraphy, since 2019, 3,100 hours so far, 12 hours a week, finish line around "))
        #expect(SetupSceneState(craftName: "Calligraphy").spoken == "Your game: Calligraphy.")
        #expect(scene.sunHeight == 0.31)
    }

    // MARK: The craft list (updates 53 and 54)

    private var allChoices: Int { CraftSuggestions.groups.reduce(0) { $0 + $1.crafts.count } }

    @Test func theOwnChipShowsWithEveryChoice() {
        let c = CraftSuggestions.choice("Calligraphy")
        #expect(c.own == "Calligraphy")
        #expect(c.ownSelected)
        #expect(c.selected == "Calligraphy")
        // Never filtered: all five groups, every choice.
        #expect(c.groups.count == 5)
        #expect(c.groups.reduce(0) { $0 + $1.crafts.count } == allChoices)
        #expect(allChoices == 36)
        #expect(CraftSuggestions.playTitle(c.selected) == "Play Calligraphy")
    }

    @Test func partialTextKeepsEveryChoiceToo() {
        let c = CraftSuggestions.choice("pa")
        #expect(c.own == "pa")
        #expect(c.groups.reduce(0) { $0 + $1.crafts.count } == allChoices)
        // One character: no own chip yet, and the button stays Continue.
        #expect(CraftSuggestions.choice("p").own == nil)
        #expect(CraftSuggestions.choice("p").selected == nil)
        #expect(CraftSuggestions.playTitle(nil) == nil)
        #expect(CraftSuggestions.choice("").groups.count == 5)
    }

    @Test func anExactMatchSelectsTheChoiceAndShowsNoOwnChip() {
        let c = CraftSuggestions.choice("piano")
        #expect(c.own == nil)
        #expect(c.selectedChoice == "Piano")
        #expect(!c.showsNoMatchLine)
        #expect(c.groups.reduce(0) { $0 + $1.crafts.count } == allChoices)
        #expect(CraftSuggestions.playTitle(c.selected) == "Play Piano")
    }

    @Test func theNotOnTheListLineShowsExactlyWithTheOwnChip() {
        for text in ["", "p", "pa", "Calligraphy", "piano", "Piano ", "zz"] {
            let c = CraftSuggestions.choice(text)
            #expect(c.showsNoMatchLine == (c.own != nil), "\(text)")
        }
    }

    @Test func tappingAChoiceWinsAndTheTypedTextStays() {
        let model = OnboardingModel(now: day(2026, 11, 21), calendar: utc)
        model.craftName = "Calligraphy"
        model.pickedCraft = "Drawing"
        #expect(model.craftName == "Calligraphy")
        #expect(model.chosenCraft == "Drawing")
        #expect(model.category == "Visual arts & making")
        #expect(!model.craftChoice.ownSelected)
        // Only one thing is selected: tapping the own chip again selects it back.
        model.pickedCraft = nil
        #expect(model.chosenCraft == "Calligraphy")
        #expect(model.category == CraftSuggestions.customCategory)
        // Typing again lets go of the tapped choice.
        model.pickedCraft = "Drawing"
        model.craftName = "Calligraphy pens"
        #expect(model.chosenCraft == "Calligraphy pens")
    }

    // MARK: The two questions moved out of setup

    @Test func theNotificationAskIsShownOnceDuringASession() {
        #expect(NotificationAskRule.shouldShow(alreadyShown: false, permission: .notAsked, sessionRunning: true))
        #expect(!NotificationAskRule.shouldShow(alreadyShown: true, permission: .notAsked, sessionRunning: true))
        #expect(!NotificationAskRule.shouldShow(alreadyShown: false, permission: .allowed, sessionRunning: true))
        #expect(!NotificationAskRule.shouldShow(alreadyShown: false, permission: .denied, sessionRunning: true))
        #expect(!NotificationAskRule.shouldShow(alreadyShown: false, permission: .notAsked, sessionRunning: false))
    }

    @Test func theWeatherInviteWaitsAWeekAndNeverInterrupts() {
        let setup = day(2026, 11, 1)
        func show(_ now: Date, weather: Bool = false, shown: Bool = false, saved: Bool = true, timer: Bool = false,
                  busy: Bool = false) -> Bool {
            WeatherInviteRule.shouldShow(now: now, onboardedAt: setup, weatherOn: weather, alreadyShown: shown,
                                         sessionJustSaved: saved, timerRunning: timer, somethingElseShowing: busy, calendar: utc)
        }
        #expect(show(day(2026, 11, 8)))
        #expect(!show(day(2026, 11, 7)))
        #expect(!show(day(2026, 11, 9), shown: true))
        #expect(!show(day(2026, 11, 9), weather: true))
        #expect(!show(day(2026, 11, 9), saved: false))
        #expect(!show(day(2026, 11, 9), timer: true))
        #expect(!show(day(2026, 11, 9), busy: true))
    }

    @Test func newSettingsStartUnshown() {
        let settings = AppSettings()
        #expect(!settings.notificationAskShown)
        #expect(!settings.weatherInviteShown)
    }

    private func makeContext() throws -> ModelContext {
        let schema = Schema([Craft.self, YearEstimate.self, Session.self, AppSettings.self, TargetPeriod.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        return ModelContext(container)
    }
}
