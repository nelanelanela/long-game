import Foundation

/// A letter to your future self (update 49): written at one point, sealed until the total reaches its milestone.
enum Letters {
    /// The milestones a letter can be written to: 100, 500, 1,000, then every 1,000 up to 10,000.
    static let milestones = [100, 500] + Array(stride(from: 1_000, through: 10_000, by: 1_000))

    /// The most a letter can hold.
    static let maxCharacters = 1_000

    /// A letter as the logic sees it.
    struct Item: Equatable, Sendable {
        var id: UUID
        var milestone: Int
        var totalWhenWritten: Double
        var openedAt: Date?
        var isSealed: Bool { openedAt == nil }
    }

    /// The next milestone above this total (nil at or past 10,000).
    static func next(after total: Double) -> Int? {
        milestones.first { Double($0) > total }
    }

    /// Whether a new letter for this milestone may be written: it must still be ahead.
    static func canWrite(for milestone: Int, total: Double) -> Bool {
        milestones.contains(milestone) && Double(milestone) > total
    }

    /// The sealed letters whose milestone the total has reached, earliest milestone first (a save that passes two
    /// milestones delivers the earlier letter, then the next).
    static func due(_ letters: [Item], total: Double) -> [Item] {
        letters.filter { $0.isSealed && Double($0.milestone) <= total }.sorted { $0.milestone < $1.milestone }
    }

    /// The hours between writing and the milestone, rounded to the nearest 10 below 1,000 and to the nearest 100
    /// from 1,000 up.
    static func hoursBetween(milestone: Int, totalWhenWritten: Double) -> Int {
        let gap = max(0, Double(milestone) - totalWhenWritten)
        let step: Double = gap < 1_000 ? 10 : 100
        return Int((gap / step).rounded() * step)
    }

    /// "You wrote this 1,000 hours ago"
    static func agoLine(milestone: Int, totalWhenWritten: Double) -> String {
        let n = hoursBetween(milestone: milestone, totalWhenWritten: totalWhenWritten)
        return String(localized: "You wrote this \(DurationFormat.grouped(n)) hours ago")
    }

    /// "1,000 hours to go."
    static func toGo(milestone: Int, total: Double) -> String {
        let n = Int(max(0, Double(milestone) - total).rounded(.up))
        return String(localized: "\(DurationFormat.grouped(n)) hours to go.")
    }

    /// "4,000 hours"
    static func hoursName(_ milestone: Int) -> String {
        String(localized: "\(DurationFormat.grouped(milestone)) hours")
    }

    /// "112 / 1,000" on screen, "112 of 1,000 characters" for VoiceOver.
    static func counter(_ count: Int) -> String {
        "\(DurationFormat.grouped(count)) / \(DurationFormat.grouped(maxCharacters))"
    }

    static func spokenCounter(_ count: Int) -> String {
        String(localized: "\(DurationFormat.grouped(count)) of \(DurationFormat.grouped(maxCharacters)) characters")
    }

    /// "3 June 2026 · at 3,000 h"
    static func writtenLine(date: Date, totalWhenWritten: Double, calendar: Calendar = .current) -> String {
        String(localized: "\(ThenAndNow.date(date, calendar: calendar)) · at \(DurationFormat.grouped(Int(totalWhenWritten.rounded(.down)))) h")
    }

    /// When the total should reach the milestone at the chosen weekly pace (nil with no pace).
    static func arrival(milestone: Int, total: Double, weeklyHours: Double?, now: Date) -> Date? {
        guard let pace = weeklyHours, pace > 0 else { return nil }
        let weeks = max(0, Double(milestone) - total) / pace
        return now.addingTimeInterval(weeks * 7 * 86_400)
    }

    /// "Write a few lines to the person you'll be then. The sun keeps it sealed until you get there, around January
    /// 2028 at your pace." Without a pace it ends at "until you get there."
    static func invitation(arrival: Date?, locale: Locale = .current) -> String {
        guard let arrival else {
            return String(localized: "Write a few lines to the person you'll be then. The sun keeps it sealed until you get there.")
        }
        let when = arrival.formatted(Date.FormatStyle(locale: locale).month(.wide).year())
        return String(localized: "Write a few lines to the person you'll be then. The sun keeps it sealed until you get there, around \(when) at your pace.")
    }

    /// The text clipped to the limit.
    static func clamped(_ text: String) -> String {
        text.count > maxCharacters ? String(text.prefix(maxCharacters)) : text
    }
}
