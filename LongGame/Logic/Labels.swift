import Foundation

/// Labels that mix a number with words, built as one string so the String Catalog
/// can pluralise them ("1 hour", "24 hours"). Keys live in Localizable.xcstrings.
enum Labels {
    static func hours(_ n: Int) -> String { String(localized: "\(n) hours") }
    static func minutes(_ n: Int) -> String { String(localized: "\(n) minutes") }
    static func seconds(_ n: Int) -> String { String(localized: "\(n) seconds") }
    static func days(_ n: Int) -> String { String(localized: "\(n) days") }
    static func weeks(_ n: Int) -> String { String(localized: "\(n) weeks") }
    static func months(_ n: Int) -> String { String(localized: "\(n) months") }
    static func yearsAgo(_ n: Int) -> String { String(localized: "\(n) years ago") }
    static func weeksAgo(_ n: Int) -> String { String(localized: "\(n) weeks ago") }
    static func sessions(_ n: Int) -> String { String(localized: "\(n) sessions") }
    static func addHours(_ n: Int) -> String { String(localized: "Add \(n) hours") }
    static func addMinutes(_ n: Int) -> String { String(localized: "Add \(n) minutes") }
    static func weeksHavePassed(_ n: Int) -> String { String(localized: "\(n) weeks have passed") }
    static func goldenHoursSoFar(_ n: Int) -> String { String(localized: "\(n) golden hours so far") }

    /// "24 h" (no plural: it is an abbreviation).
    static func shortHours(_ n: Int) -> String { String(localized: "\(n) h") }
    /// "+2 h/wk"
    static func extraPerWeek(_ n: Int) -> String { String(localized: "+\(n) h/wk") }
    /// "12 h per week"
    static func hoursPerWeek(_ n: Int) -> String { String(localized: "\(n) h per week") }

    /// "2 hours 30 minutes", "1 hour", "45 seconds": spoken durations for VoiceOver.
    static func spoken(seconds total: Int, includeSeconds: Bool) -> String {
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        var parts: [String] = []
        if h > 0 { parts.append(hours(h)) }
        if m > 0 { parts.append(minutes(m)) }
        if includeSeconds && h == 0 { parts.append(seconds(s)) }
        return parts.joined(separator: " ")
    }

    /// "Add 2 hours", "Add 1 h 30 m", "Add 45 minutes", or "Add hours" at zero.
    static func addLabel(seconds: Double) -> String {
        let total = Int((seconds / 60).rounded())
        let h = total / 60, m = total % 60
        if total == 0 { return String(localized: "Add hours") }
        if m == 0 { return addHours(h) }
        if h == 0 { return addMinutes(m) }
        return String(localized: "Add \(h) h \(m) m")
    }

    /// "about 1 h 05 m a day", "about 25 m a day"
    static func aboutPerDay(minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        if h == 0 { return String(localized: "about \(m) m a day") }
        return String(localized: "about \(h) h \(String(format: "%02d", m)) m a day")
    }
}
