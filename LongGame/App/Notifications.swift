import Foundation
import UserNotifications

/// Local notifications. iOS's permission prompt is shown only from "A gentle nudge" (the last setup step) or when
/// a notification switch is turned on in Settings; starting a session never asks.
enum Notifications {
    static let longSessionId = "long-session"
    static let milestoneId = "milestone"
    /// Set once "A gentle nudge" (or a Settings switch) has asked.
    static let askedKey = "notifications.asked"

    /// Shows iOS's own prompt (only the first time; after that iOS answers at once with the earlier choice).
    /// Tests swap it to count the asks.
    @MainActor static var requestAuthorization: @MainActor () async -> Bool = {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// Where iOS stands, without asking.
    static func permission() async -> NotificationPermission {
        switch await UNUserNotificationCenter.current().notificationSettings().authorizationStatus {
        case .notDetermined: .notAsked
        case .denied: .denied
        default: .allowed
        }
    }

    /// "1,000 hours of piano. Sunrise is coming." for the moment a running session carries the total over a
    /// milestone. Pass nil to cancel it.
    static func scheduleMilestone(at date: Date?, message: String) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [milestoneId])
        guard let date else { return }
        let content = UNMutableNotificationContent()
        content.title = message
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, date.timeIntervalSinceNow), repeats: false)
        center.add(UNNotificationRequest(identifier: milestoneId, content: content, trigger: trigger))
    }

    static func scheduleLongSession(at date: Date?) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [longSessionId])
        guard let date else { return }
        let content = UNMutableNotificationContent()
        content.title = "Still practising?"
        content.body = "Your session has been running for 4 hours. Pause or finish when you're ready."
        let interval = max(1, date.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        center.add(UNNotificationRequest(identifier: longSessionId, content: content, trigger: trigger))
    }
}
