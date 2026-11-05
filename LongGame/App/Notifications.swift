import Foundation
import UserNotifications

/// Local notifications. Everything is off until the user agrees after their
/// first saved session.
enum Notifications {
    static let longSessionId = "long-session"
    static let milestoneId = "milestone"

    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// Asks iOS for permission the first time it is needed (status "not determined"). Does nothing once the
    /// user has answered, so it is safe to call whenever a notification is about to matter.
    @discardableResult
    static func requestIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let status = await center.notificationSettings().authorizationStatus
        switch status {
        case .notDetermined: return await requestAuthorization()
        case .authorized, .provisional, .ephemeral: return true
        default: return false
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
