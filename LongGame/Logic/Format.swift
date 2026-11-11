import Foundation

/// Date formatters are slow to make (the Calendar's 371 day squares each made one for VoiceOver on every redraw), so
/// each one is made once per pattern, locale, calendar and time zone, then kept. Never change a formatter it returns.
/// Formatting with one `DateFormatter` from several threads is safe.
enum CachedFormatter {
    private final class Store: @unchecked Sendable {
        private let lock = NSLock()
        private var formatters: [String: DateFormatter] = [:]

        func formatter(_ key: String, make: () -> DateFormatter) -> DateFormatter {
            lock.lock()
            defer { lock.unlock() }
            if let f = formatters[key] { return f }
            let f = make()
            formatters[key] = f
            return f
        }
    }

    private static let store = Store()

    private static func key(_ kind: String, _ format: String, _ calendar: Calendar, _ locale: Locale) -> String {
        "\(kind)|\(format)|\(locale.identifier)|\(calendar.identifier)|\(calendar.timeZone.identifier)"
    }

    /// A fixed pattern such as "EEEE d MMMM" (British English unless told otherwise, as on the boards).
    static func pattern(_ format: String, calendar: Calendar, locale: Locale = Locale(identifier: "en_GB")) -> DateFormatter {
        store.formatter(key("p", format, calendar, locale)) {
            let f = DateFormatter()
            f.locale = locale
            f.calendar = calendar
            f.timeZone = calendar.timeZone
            f.dateFormat = format
            return f
        }
    }

    /// A template such as "dMMMM", laid out the way the locale writes dates.
    static func template(_ template: String, calendar: Calendar, locale: Locale) -> DateFormatter {
        store.formatter(key("t", template, calendar, locale)) {
            let f = DateFormatter()
            f.locale = locale
            f.calendar = calendar
            f.timeZone = calendar.timeZone
            f.setLocalizedDateFormatFromTemplate(template)
            return f
        }
    }
}

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

    /// "3,294": whole numbers with commas, the same on every device (the app's copy is English).
    static func grouped(_ n: Int) -> String {
        n.formatted(.number.grouping(.automatic).locale(Locale(identifier: "en_GB")))
    }

    /// "3,294.7": the overall total with one decimal, for the timer.
    static func totalHours(_ hours: Double) -> String {
        max(0, hours).formatted(.number.precision(.fractionLength(1)).locale(Locale(identifier: "en_GB")))
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
}

enum RelativeDay {
    private static func formatter(_ format: String, _ calendar: Calendar) -> DateFormatter {
        CachedFormatter.pattern(format, calendar: calendar)
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

    /// "Thursday 22 October" (no comma, as on the boards)
    static func full(_ date: Date, calendar: Calendar = .current) -> String {
        formatter("EEEE d MMMM", calendar).string(from: date)
    }
}
