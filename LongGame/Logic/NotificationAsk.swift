import Foundation

/// The setup steps pushed after the craft name (step 1), in order. Update 53 made setup five steps: the notification
/// question moved to the first session (`NotificationAskRule`) and the weather to a week later (`WeatherInviteRule`).
enum OnboardingStep: Hashable, CaseIterable, Sendable {
    case start, hours, pace, keepSafe
}

/// What iOS has been told about Long Game's notifications.
enum NotificationPermission: Equatable, Sendable {
    /// iOS has never shown its prompt.
    case notAsked
    /// Allowed (including provisional or ephemeral).
    case allowed
    /// Turned off, here or in the iPhone's Settings app.
    case denied
}

/// The order of the setup steps. Nothing in setup asks for a permission any more.
enum OnboardingSteps {
    /// The pushed steps in order.
    static let order = OnboardingStep.allCases

    /// The step after this one, or nil when this one ("Keep your game safe") finishes onboarding.
    static func next(after step: OnboardingStep) -> OnboardingStep? {
        guard let i = order.firstIndex(of: step), i + 1 < order.count else { return nil }
        return order[i + 1]
    }

    /// How many step dots there are: the craft step plus the pushed steps (five).
    static var count: Int { 1 + order.count }

    /// The dot a step lights up to (the craft step is 1).
    static func number(of step: OnboardingStep) -> Int {
        2 + (order.firstIndex(of: step) ?? 0)
    }
}

/// The daily reminder, which only the person turns on, in Settings. Onboarding never sets it.
enum DailyReminder {
    /// The time a newly switched-on reminder starts at: 7 pm today. The person can change it, and the days, there.
    static func defaultTime(now: Date = Date(), calendar: Calendar = .current) -> Date {
        calendar.date(bySettingHour: 19, minute: 0, second: 0, of: now) ?? now
    }
}
