import Foundation

/// Then and now (update 48): an early session photo next to a recent one, so progress can be seen. Made only from
/// sessions already saved; the two ids of a pair the person chose are the only thing stored.
enum ThenAndNow {
    /// A session that has a photo.
    struct Photo: Equatable, Sendable {
        var sessionId: UUID
        var start: Date
    }

    struct Pair: Equatable, Sendable {
        var then: Photo
        var now: Photo
    }

    /// The person's own choice of Then and Now (two session ids).
    struct Choice: Equatable, Sendable {
        var then: UUID
        var now: UUID
    }

    /// The earliest and latest photo must be at least this many days apart for the feature to appear.
    static let minimumDays = 90

    /// Then and Now. A remembered choice wins while both its photos still exist and Now is later than Then;
    /// otherwise the earliest and the latest photo, when they are at least 90 days apart. Nil: nothing to show.
    static func pair(photos: [Photo], chosen: Choice? = nil, calendar: Calendar = .current) -> Pair? {
        if let chosen, let pair = valid(chosen, in: photos) { return pair }
        return automatic(photos: photos, calendar: calendar)
    }

    /// Whether a remembered choice can still be used (both photos exist, Now later than Then).
    static func valid(_ chosen: Choice, in photos: [Photo]) -> Pair? {
        guard let then = photos.first(where: { $0.sessionId == chosen.then }),
              let now = photos.first(where: { $0.sessionId == chosen.now }),
              now.start > then.start else { return nil }
        return Pair(then: then, now: now)
    }

    /// The earliest and the latest photo, at least 90 calendar days apart.
    static func automatic(photos: [Photo], calendar: Calendar = .current) -> Pair? {
        let sorted = photos.sorted { $0.start < $1.start }
        guard sorted.count >= 2, let first = sorted.first, let last = sorted.last else { return nil }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: first.start),
                                           to: calendar.startOfDay(for: last.start)).day ?? 0
        guard days >= minimumDays else { return nil }
        return Pair(then: first, now: last)
    }

    /// The overall total at the end of a session: what came before the app, plus every session that started no later
    /// than this one (this one included).
    static func total(atEndOf sessionId: UUID, sessions: [(id: UUID, start: Date, hours: Double)], baseline: Double) -> Double {
        guard let mine = sessions.first(where: { $0.id == sessionId }) else { return baseline }
        let logged = sessions.filter { $0.start < mine.start || $0.id == mine.id }.reduce(0) { $0 + $1.hours }
        return baseline + logged
    }

    /// The time between the two photos, in the largest sensible unit: "2 years 8 months later", "5 months later",
    /// under two months "3 weeks later", under a week "4 days later".
    static func gap(from: Date, to: Date, calendar: Calendar = .current) -> String {
        let start = calendar.startOfDay(for: from), end = calendar.startOfDay(for: to)
        let c = calendar.dateComponents([.year, .month], from: start, to: end)
        let years = max(0, c.year ?? 0), months = max(0, c.month ?? 0)
        let days = max(0, calendar.dateComponents([.day], from: start, to: end).day ?? 0)
        if years >= 1 {
            return months == 0
                ? inflected("^[\(years) year](inflect: true) later")
                : inflected("^[\(years) year](inflect: true) ^[\(months) month](inflect: true) later")
        }
        if months >= 2 { return inflected("^[\(months) month](inflect: true) later") }
        if days >= 7 { return inflected("^[\(days / 7) week](inflect: true) later") }
        return inflected("^[\(max(1, days)) day](inflect: true) later")
    }

    /// "12 March 2024", in the person's own order and month names.
    static func date(_ date: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        var style = Date.FormatStyle(date: .long, time: .omitted, locale: locale, calendar: calendar)
        style.timeZone = calendar.timeZone
        return date.formatted(style)
    }

    /// "at 2,310 h"
    static func atHours(_ hours: Double) -> String {
        String(localized: "at \(DurationFormat.grouped(Int(hours.rounded(.down)))) h")
    }

    /// "984 hours of piano between these two." (the craft in lower case).
    static func between(hours: Double, craft: String) -> String {
        let n = Int(max(0, hours).rounded(.down))
        let name = craft.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return inflected("^[\(n) hour](inflect: true) of \(name) between these two.")
    }

    /// "984 hours between these two" (the shared image).
    static func betweenShort(hours: Double) -> String {
        inflected("^[\(Int(max(0, hours).rounded(.down))) hour](inflect: true) between these two")
    }

    /// "Then. 12 March 2024, at 2,310 hours. First try at the nocturne. Photo."
    static func spoken(isThen: Bool, date: String, hours: Double, note: String?) -> String {
        let label = isThen ? String(localized: "Then") : String(localized: "Now")
        let h = DurationFormat.grouped(Int(hours.rounded(.down)))
        var parts = [label, String(localized: "\(date), at \(h) hours")]
        if let note = note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty { parts.append(note) }
        parts.append(String(localized: "Photo"))
        return parts.joined(separator: ". ") + "."
    }

    private static func inflected(_ key: String.LocalizationValue) -> String {
        String(AttributedString(localized: key).characters)
    }
}
