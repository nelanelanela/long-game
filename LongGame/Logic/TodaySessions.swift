import Foundation

// "Today's sessions": the rows under the quiet line on the Today tab. Pure functions, nothing stored.

/// One saved session as the Today tab lists it.
struct TodaySession: Equatable, Identifiable, Sendable {
    var id: UUID
    var start: Date
    var end: Date
    var durationSec: Double
    var note: String?
    var photo: Data?
    /// Where today's sunrise stood when the session ended (for its picture, when it has no photo).
    var sunriseProgress: Double = 0
    /// The default picture was removed for this session: the row shows the quiet clock tile instead.
    var hidesDefaultPicture = false

    var hasPhoto: Bool { photo != nil }
}

enum TodaySessions {
    /// The items that started today (a session crossing midnight counts on the day it started), oldest first.
    static func startedToday<T>(_ items: [T], start: (T) -> Date, now: Date, calendar: Calendar = .current) -> [T] {
        let today = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today.addingTimeInterval(86_400)
        return items.filter { start($0) >= today && start($0) < tomorrow }
            .enumerated()
            .sorted { start($0.element) == start($1.element) ? $0.offset < $1.offset : start($0.element) < start($1.element) }
            .map(\.element)
    }

    private static func formatter(_ format: String, calendar: Calendar) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_GB")
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.dateFormat = format
        return f
    }

    /// "07:40 – 08:20"
    static func timeRange(start: Date, end: Date, calendar: Calendar = .current) -> String {
        let f = formatter("HH:mm", calendar: calendar)
        return "\(f.string(from: start)) – \(f.string(from: end))"
    }

    /// The note on one line: the text up to its first line break, trimmed. Nil when there is none ("No note").
    static func noteLine(_ note: String?) -> String? {
        guard let first = note?.split(whereSeparator: \.isNewline).first else { return nil }
        let trimmed = first.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// "40 m" or "1 h 05"
    static func duration(_ seconds: Double) -> String { StretchText.clock(seconds: seconds) }

    /// "Now · 12 m"
    static func nowLabel(seconds: Double) -> String { String(localized: "Now · \(StretchText.clock(seconds: seconds))") }

    /// What VoiceOver reads: "7:40 to 8:20, 40 minutes, Scales and arpeggios. Has a photo."
    static func spoken(_ s: TodaySession, calendar: Calendar = .current) -> String {
        let f = formatter("H:mm", calendar: calendar)
        var text = String(localized: "\(f.string(from: s.start)) to \(f.string(from: s.end)), \(StretchText.spoken(seconds: s.durationSec))")
        if let note = noteLine(s.note) { text += ", " + note }
        text += "."
        if s.hasPhoto { text += " " + String(localized: "Has a photo.") }
        return text
    }

    /// "Now, 12 minutes. Session running."
    static func spokenNow(seconds: Double) -> String {
        String(localized: "Now, \(StretchText.spoken(seconds: seconds)). Session running.")
    }
}
