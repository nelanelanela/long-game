import Foundation
import CoreGraphics

/// A keepsake poster (update 49): every day since the first session, as a field of the calendar's own marks.
enum Keepsake {
    /// Each row of the field is four weeks.
    static let perRow = 28

    enum Paper: String, CaseIterable, Sendable {
        case a4, a3, cm50x70, in18x24

        /// The page in points (1/72 in).
        var size: CGSize {
            switch self {
            case .a4: CGSize(width: Keepsake.mm(210), height: Keepsake.mm(297))
            case .a3: CGSize(width: Keepsake.mm(297), height: Keepsake.mm(420))
            case .cm50x70: CGSize(width: Keepsake.mm(500), height: Keepsake.mm(700))
            case .in18x24: CGSize(width: 18 * 72, height: 24 * 72)
            }
        }

        var title: String {
            switch self {
            case .a4: "A4"
            case .a3: "A3"
            case .cm50x70: "50 × 70"
            case .in18x24: String(localized: "18 × 24 in")
            }
        }
    }

    enum Look: String, CaseIterable, Sendable { case paper, night }

    /// 15 mm all round, for framing.
    static let margin = mm(15)

    static func mm(_ value: Double) -> CGFloat { CGFloat(value / 25.4 * 72) }

    /// A3, or 18 × 24 in where the region measures in inches.
    static func defaultPaper(locale: Locale = .current) -> Paper {
        locale.measurementSystem == .us ? .in18x24 : .a3
    }

    /// The hours a poster is for: the milestone just reached, or from Growth the last 1,000 passed (nil below 1,000).
    static func lastThousand(total: Double) -> Int? {
        let n = Int(total / 1_000) * 1_000
        return n >= 1_000 ? n : nil
    }

    /// The day the total first reached `hours`: what came before the app, then the sessions in order.
    static func dayReached(_ hours: Int, sessions: [SessionRecord], baseline: Double, calendar: Calendar = .current) -> Date? {
        var total = baseline
        for s in sessions.sorted(by: { $0.start < $1.start }) {
            total += s.hours
            if total >= Double(hours) { return calendar.startOfDay(for: s.start) }
        }
        return nil
    }

    /// The days the poster runs between; always an answer, so the poster is never blank.
    /// From the first session (or the day the craft began, when nothing is logged yet) to the day `hours` was reached.
    /// Reached with the hours from before the app, or not reached in the log at all: it runs to today.
    static func span(_ hours: Int, sessions: [SessionRecord], baseline: Double, began: Date, today: Date,
                     calendar: Calendar = .current) -> (first: Date, last: Date) {
        let todayStart = calendar.startOfDay(for: today)
        let last = baseline >= Double(hours)
            ? todayStart
            : (dayReached(hours, sessions: sessions, baseline: baseline, calendar: calendar) ?? todayStart)
        let first = calendar.startOfDay(for: sessions.map(\.start).min() ?? began)
        return (min(first, last), last)
    }

    /// One level for every day from the first session to `last` (both included), rest days too.
    static func days(sessions: [SessionRecord], through last: Date, calendar: Calendar = .current) -> [CalendarLevel] {
        guard let firstStart = sessions.map(\.start).min() else { return [] }
        let first = calendar.startOfDay(for: firstStart)
        let end = calendar.startOfDay(for: last)
        guard first <= end else { return [] }
        var hours: [Date: Double] = [:]
        for s in sessions { hours[calendar.startOfDay(for: s.start), default: 0] += s.hours }
        var out: [CalendarLevel] = []
        var day = first
        while day <= end {
            out.append(CalendarLevel.level(hours: hours[day] ?? 0))
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return out
    }

    static func daysPlayed(_ days: [CalendarLevel]) -> Int { days.filter { $0 != .rest }.count }

    /// The size of one cell so the whole field fits the box, 28 to a row; never cuts days.
    static func cell(dayCount: Int, in box: CGSize) -> CGFloat {
        let rows = max(1, Int((Double(dayCount) / Double(perRow)).rounded(.up)))
        return max(0.5, min(box.width / CGFloat(perRow), box.height / CGFloat(rows)))
    }

    /// "Long Game – 3,000 hours of piano.pdf"
    static func fileName(hours: Int, craft: String) -> String {
        let name = craft.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            .replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        return "Long Game – \(DurationFormat.grouped(hours)) hours of \(name).pdf"
    }

    /// "2,190 hours came before"; nil when nothing came before the app.
    static func before(_ baseline: Double) -> String? {
        let n = Int(baseline.rounded(.down))
        return n > 0 ? String(localized: "\(DurationFormat.grouped(n)) hours came before") : nil
    }

    /// "653 days played · each row is four weeks"
    static func playedLine(_ played: Int) -> String {
        String(localized: "\(DurationFormat.grouped(played)) days played · each row is four weeks")
    }

    /// "Poster: 3,000 hours of piano, 653 days played."
    static func spoken(hours: Int, craft: String, played: Int) -> String {
        String(localized: "Poster: \(DurationFormat.grouped(hours)) hours of \(craft.lowercased()), \(DurationFormat.grouped(played)) days played.")
    }
}
