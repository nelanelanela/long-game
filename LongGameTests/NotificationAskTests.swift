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

    private func makeContext() throws -> ModelContext {
        let schema = Schema([Craft.self, YearEstimate.self, Session.self, AppSettings.self, TargetPeriod.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        return ModelContext(container)
    }

    /// Onboarding saved, whatever was answered on "A gentle nudge": the model no longer carries any reminder.
    private func onboardingSettings() throws -> (AppSettings, ModelContext) {
        let context = try makeContext()
        let model = OnboardingModel(now: Date(), calendar: .current)
        model.craftName = "Piano"
        model.save(in: context)
        return (try #require(try context.fetch(FetchDescriptor<AppSettings>()).first), context)
    }

    @Test func onboardingLeavesTheDailyReminderOff() throws {
        let (settings, _) = try onboardingSettings()
        #expect(settings.reminderTime == nil)
        #expect(!settings.rhythmNudge)
    }

    @Test func freshSettingsHaveEveryReminderOff() {
        let settings = AppSettings()
        #expect(settings.reminderTime == nil)
        #expect(!settings.rhythmNudge)
    }

    @Test func turningTheReminderOnInSettingsStartsAtSevenPm() throws {
        let now = day(2026, 11, 11, hour: 10)
        let time = DailyReminder.defaultTime(now: now, calendar: utc)
        #expect(utc.component(.hour, from: time) == 19)
        #expect(utc.component(.minute, from: time) == 0)
        #expect(utc.isDate(time, inSameDayAs: now))

        // As Settings' Daily reminder switch does after onboarding: it saves, on every day.
        let (settings, context) = try onboardingSettings()
        settings.reminderTime = DailyReminder.defaultTime()
        try context.save()
        let saved = try #require(try context.fetch(FetchDescriptor<AppSettings>()).first)
        #expect(saved.reminderTime != nil)
        #expect(saved.reminderDays == [1, 2, 3, 4, 5, 6, 7])
    }

    // MARK: The milestone notification

    @Test func theMilestoneNotificationNamesTheCraftAsTheCardShows() {
        #expect(Milestones.notificationMessage(hours: 1_000, craft: "Piano") == "1,000 hours of piano. Sunrise is coming.")
        #expect(Milestones.notificationMessage(hours: 100, craft: " Watercolour ") == "100 hours of watercolour. Sunrise is coming.")
        #expect(Milestones.notificationMessage(hours: 10_000, craft: "Piano") == "10,000 hours of piano. The sun has fully risen.")
        // The celebration on Home keeps its own short line.
        #expect(Milestones.message(hours: 1_000, craft: "Piano") == "A thousand hours.")
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
