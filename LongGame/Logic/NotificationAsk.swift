import Foundation

/// The setup steps pushed after the craft name (step 1), in order.
enum OnboardingStep: Hashable, CaseIterable, Sendable {
    case start, hours, pace, keepSafe, notifications
}

/// What iOS has been told about Long Game's notifications, as far as onboarding cares.
enum NotificationPermission: Equatable, Sendable {
    /// iOS has never shown its prompt.
    case notAsked
    /// Allowed (including provisional or ephemeral).
    case allowed
    /// Turned off, here or in the iPhone's Settings app.
    case denied
}

/// The order of the setup steps, and whether the "A gentle nudge" step (6) is shown.
enum OnboardingSteps {
    /// "A gentle nudge" only makes sense while iOS has never asked; once permission is decided (for example after
    /// "Switch to a new game") the question would do nothing, so the step is left out.
    static func showsNotifications(_ permission: NotificationPermission) -> Bool {
        permission == .notAsked
    }

    /// The pushed steps in order.
    static func order(permission: NotificationPermission) -> [OnboardingStep] {
        OnboardingStep.allCases.filter { $0 != .notifications || showsNotifications(permission) }
    }

    /// The step after this one, or nil when this one finishes onboarding.
    static func next(after step: OnboardingStep, permission: NotificationPermission) -> OnboardingStep? {
        let steps = order(permission: permission)
        guard let i = steps.firstIndex(of: step), i + 1 < steps.count else { return nil }
        return steps[i + 1]
    }

    /// How many step dots there are: the craft step plus the pushed steps.
    static func count(permission: NotificationPermission) -> Int {
        1 + order(permission: permission).count
    }

    /// The dot a step lights up to (the craft step is 1).
    static func number(of step: OnboardingStep) -> Int {
        2 + (OnboardingStep.allCases.firstIndex(of: step) ?? 0)
    }
}

/// The answer to "A gentle nudge".
enum NotificationAsk {
    static let everyDay = [1, 2, 3, 4, 5, 6, 7]

    /// The daily reminder that "Allow notifications" turns on: 7 pm, only when iOS said yes.
    static func reminderTime(granted: Bool, now: Date = Date(), calendar: Calendar = .current) -> Date? {
        guard granted else { return nil }
        return calendar.date(bySettingHour: 19, minute: 0, second: 0, of: now)
    }
}
