import Foundation

enum Milestones {
    static let all = [100, 500, 1_000, 2_500, 5_000, 7_500, 10_000]

    /// Milestones the total has reached that were not celebrated yet.
    static func newlyCrossed(total: Double, seen: [Int]) -> [Int] {
        all.filter { Double($0) <= total && !seen.contains($0) }
    }

    static func message(hours: Int, craft: String) -> String {
        if hours >= 10_000 { return "10,000 hours. The sun has fully risen." }
        let formatted = NumberFormatter.localizedString(from: NSNumber(value: hours), number: .decimal)
        return "\(formatted) hours of \(craft.lowercased()). Sunrise is coming."
    }
}

enum ReminderPlanner {
    static let streakReminderHour = 20
    static let minimumStreak = 3

    struct StreakReminder: Equatable {
        var date: Date
        var streak: Int
    }

    /// 8 pm reminders for today and tomorrow, only where a streak of 3+ days is at risk.
    static func streakReminders(daily: [Date: Double], now: Date, calendar: Calendar = .current) -> [StreakReminder] {
        let today = calendar.startOfDay(for: now)
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else { return [] }
        let hasToday = (daily[today] ?? 0) > 0
        let streak = Streaks.current(daily: daily, today: now, calendar: calendar)
        var result: [StreakReminder] = []

        if !hasToday, streak >= minimumStreak, let at = calendar.date(bySettingHour: streakReminderHour, minute: 0, second: 0, of: today), at > now {
            result.append(StreakReminder(date: at, streak: streak))
        }
        if hasToday, streak >= minimumStreak, let at = calendar.date(bySettingHour: streakReminderHour, minute: 0, second: 0, of: tomorrow) {
            result.append(StreakReminder(date: at, streak: streak))
        }
        return result
    }
}

enum CSVExport {
    struct Row {
        var craft: String
        var start: Date
        var durationSec: Double
        var source: String
        var note: String
    }

    static func escape(_ field: String) -> String {
        guard field.contains(where: { [",", "\"", "\n", "\r"].contains($0) }) else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    static func sessions(_ rows: [Row], calendar: Calendar = .current) -> String {
        let day = DateFormatter()
        day.calendar = calendar
        day.timeZone = calendar.timeZone
        day.locale = Locale(identifier: "en_GB")
        day.dateFormat = "yyyy-MM-dd"
        let time = DateFormatter()
        time.calendar = calendar
        time.timeZone = calendar.timeZone
        time.locale = Locale(identifier: "en_GB")
        time.dateFormat = "HH:mm"

        var lines = ["Craft,Date,Start,Minutes,Source,Note"]
        for r in rows.sorted(by: { $0.start < $1.start }) {
            let minutes = Int((r.durationSec / 60).rounded())
            lines.append([escape(r.craft), day.string(from: r.start), time.string(from: r.start),
                          String(minutes), r.source, escape(r.note)].joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }
}
