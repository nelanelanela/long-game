import Foundation

enum DurationFormat {
    /// "1 h 30 m", "2 h", "45 m"
    static func short(seconds: Double) -> String {
        let minutes = Int((seconds / 60).rounded())
        let h = minutes / 60, m = minutes % 60
        switch (h, m) {
        case (0, _): return "\(m) m"
        case (_, 0): return "\(h) h"
        default: return "\(h) h \(m) m"
        }
    }

    /// "H:MM" for the big preview and the timer.
    static func clock(seconds: Double) -> String {
        let total = Int(max(0, seconds))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }

    /// "2:42" (minutes unpadded), for the timer caption.
    static func minutesSeconds(seconds: Double) -> String {
        let total = Int(max(0, seconds))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    static func hoursMinutes(seconds: Double) -> String {
        let minutes = Int((seconds / 60).rounded())
        return String(format: "%d:%02d", minutes / 60, minutes % 60)
    }

    /// One decimal, no trailing ".0": "9.5 h", "12 h".
    static func hours(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        return rounded == rounded.rounded() ? "\(Int(rounded)) h" : String(format: "%.1f h", rounded)
    }

    static func perWeek(_ value: Double) -> String {
        hours(value).replacingOccurrences(of: " h", with: " h/wk")
    }

    /// Label for the Add button: "Add 2 hours", "Add 1 h 30 m", "Add 45 minutes".
    static func addLabel(seconds: Double) -> String {
        let minutes = Int((seconds / 60).rounded())
        let h = minutes / 60, m = minutes % 60
        if minutes == 0 { return "Add hours" }
        if m == 0 { return h == 1 ? "Add 1 hour" : "Add \(h) hours" }
        if h == 0 { return "Add \(m) minutes" }
        return "Add \(h) h \(m) m"
    }
}

enum RelativeDay {
    private static func formatter(_ format: String, _ calendar: Calendar) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_GB")
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.dateFormat = format
        return f
    }

    /// Today, Yesterday, a weekday name within the last week, otherwise "22 Oct".
    static func label(_ date: Date, now: Date, calendar: Calendar = .current) -> String {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? 0
        switch days {
        case 0: return "Today"
        case 1: return "Yesterday"
        case 2...6: return formatter("EEEE", calendar).string(from: date)
        default:
            let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: now)
            return formatter(sameYear ? "d MMM" : "d MMM yyyy", calendar).string(from: date)
        }
    }

    /// "Thursday, 22 October"
    static func full(_ date: Date, calendar: Calendar = .current) -> String {
        formatter("EEEE, d MMMM", calendar).string(from: date)
    }
}
