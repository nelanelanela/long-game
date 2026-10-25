import Foundation
import UserNotifications

/// Local notifications. Everything is off until the user agrees after their
/// first saved session.
enum Notifications {
    static let longSessionId = "long-session"

    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
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
