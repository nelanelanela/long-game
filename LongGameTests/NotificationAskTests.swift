import Testing
import Foundation
import SwiftData
@testable import LongGame

/// "A gentle nudge" (setup step 6): where it sits, when it is left out, and what its answer saves.
struct NotificationAskTests {
    // MARK: Step order

    @Test func theNudgeIsTheLastOfSixSteps() {
        #expect(OnboardingSteps.order(permission: .notAsked) == [.start, .hours, .pace, .keepSafe, .notifications])
        #expect(OnboardingSteps.count(permission: .notAsked) == 6)
        #expect(OnboardingSteps.next(after: .keepSafe, permission: .notAsked) == .notifications)
        #expect(OnboardingSteps.next(after: .notifications, permission: .notAsked) == nil)
    }

    @Test func stepNumbersFollowTheCraftStep() {
        #expect(OnboardingSteps.number(of: .start) == 2)
        #expect(OnboardingSteps.number(of: .hours) == 3)
        #expect(OnboardingSteps.number(of: .pace) == 4)
        #expect(OnboardingSteps.number(of: .keepSafe) == 5)
        #expect(OnboardingSteps.number(of: .notifications) == 6)
    }

    @Test(arguments: [NotificationPermission.allowed, .denied])
    func theNudgeIsSkippedOncePermissionIsDecided(_ permission: NotificationPermission) {
        #expect(!OnboardingSteps.showsNotifications(permission))
        #expect(OnboardingSteps.order(permission: permission) == [.start, .hours, .pace, .keepSafe])
        #expect(OnboardingSteps.count(permission: permission) == 5)
        // Keep your game safe finishes onboarding instead.
        #expect(OnboardingSteps.next(after: .keepSafe, permission: permission) == nil)
    }

    // MARK: Allow notifications

    @Test func allowSetsSevenPmOnlyWhenGranted() throws {
        let now = day(2026, 11, 11, hour: 10)
        let time = try #require(NotificationAsk.reminderTime(granted: true, now: now, calendar: utc))
        #expect(utc.component(.hour, from: time) == 19)
        #expect(utc.component(.minute, from: time) == 0)
        #expect(NotificationAsk.reminderTime(granted: false, now: now, calendar: utc) == nil)
    }

    private func makeContext() throws -> ModelContext {
        let schema = Schema([Craft.self, YearEstimate.self, Session.self, AppSettings.self, TargetPeriod.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        return ModelContext(container)
    }

    private func savedSettings(granted: Bool) throws -> AppSettings {
        let context = try makeContext()
        let model = OnboardingModel(now: Date(), calendar: .current)
        model.craftName = "Piano"
        model.reminderTime = NotificationAsk.reminderTime(granted: granted)
        model.save(in: context)
        return try #require(try context.fetch(FetchDescriptor<AppSettings>()).first)
    }

    @Test func aGrantedAllowSavesTheDailyReminderOnEveryDay() throws {
        let settings = try savedSettings(granted: true)
        let time = try #require(settings.reminderTime)
        #expect(Calendar.current.component(.hour, from: time) == 19)
        #expect(settings.reminderDays == [1, 2, 3, 4, 5, 6, 7])
    }

    @Test func aDeclinedAllowOrNotNowSavesNoReminder() throws {
        #expect(try savedSettings(granted: false).reminderTime == nil)
    }

    // MARK: Starting a session

    @MainActor @Test func startingASessionNeverAsks() async throws {
        let original = Notifications.requestAuthorization
        let asks = AskCounter()
        Notifications.requestAuthorization = { asks.count += 1; return true }
        defer { Notifications.requestAuthorization = original }

        let timer = TimerStore()
        timer.clear()
        timer.start(craft: Craft(name: "Piano", startYear: 2024))
        // Give any task the start might have launched time to run.
        try await Task.sleep(for: .milliseconds(200))
        #expect(timer.isActive)
        timer.clear()
        #expect(asks.count == 0)
    }
}

@MainActor private final class AskCounter { var count = 0 }
