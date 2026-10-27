import Foundation
import UserNotifications

/// Keeps scheduled reminders in step with the settings and the practice log.
/// Safe to call often: it clears its own requests and schedules them again.
enum NotificationPlanner {
    private static let prefixes = ["daily-", "rhythm-"]

    static func refresh(craftName: String, reminderTime: Date?, reminderDays: [Int], rhythmNudge: Bool,
                        sessions: [SessionRecord], now: Date = Date(), calendar: Calendar = .current) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { id in
            prefixes.contains { id.hasPrefix($0) }
        })

        let status = await center.notificationSettings().authorizationStatus
        guard status == .authorized || status == .provisional else { return }

        if let reminderTime {
            let time = calendar.dateComponents([.hour, .minute], from: reminderTime)
            for weekday in reminderDays where (1...7).contains(weekday) {
                var parts = DateComponents()
                parts.weekday = weekday
                parts.hour = time.hour
                parts.minute = time.minute
                let content = UNMutableNotificationContent()
                content.title = "Time for a little \(craftName.lowercased())?"
                content.body = "The sun is waiting."
                let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: true)
                try? await center.add(UNNotificationRequest(identifier: "daily-\(weekday)", content: content, trigger: trigger))
            }
        }

        if rhythmNudge {
            let daily = Practice.dailySeconds(sessions, calendar: calendar)
            for (i, nudge) in ReminderPlanner.rhythmNudges(daily: daily, now: now, calendar: calendar).enumerated() {
                let content = UNMutableNotificationContent()
                content.title = ReminderPlanner.nudgeMessage(weekday: nudge.weekday, craftName: craftName, calendar: calendar)
                let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: nudge.date)
                let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
                try? await center.add(UNNotificationRequest(identifier: "rhythm-\(i)", content: content, trigger: trigger))
            }
        }
    }

    static func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
