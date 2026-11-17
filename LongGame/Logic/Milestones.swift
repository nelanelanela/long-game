import Foundation

enum Milestones {
    /// Update 50: every 1,000 as well, so letters and posters have their moment.
    static let all = [100, 500, 1_000, 2_000, 2_500, 3_000, 4_000, 5_000, 6_000, 7_000, 7_500, 8_000, 9_000, 10_000]
    /// The thousands added in update 50. Someone already past them when they arrive isn't shown them late.
    static let addedThousands = [2_000, 3_000, 4_000, 6_000, 7_000, 8_000, 9_000]

    /// Once, after updating: the added thousands already passed join the seen list.
    static func adoptingThousands(total: Double, seen: [Int]) -> [Int] {
        seen + addedThousands.filter { Double($0) <= total && !seen.contains($0) }
    }

    /// Milestones the total has reached that were not celebrated yet.
    static func newlyCrossed(total: Double, seen: [Int]) -> [Int] {
        all.filter { Double($0) <= total && !seen.contains($0) }
    }

    /// The next milestone a running session will carry the total over, and when. Nil when the timer is paused,
    /// nothing is left to celebrate, or the 12-hour auto-pause comes first.
    static func nextCrossing(baseTotal: Double, state: TimerState, seen: [Int], now: Date) -> (hours: Int, date: Date)? {
        guard !state.isPaused(at: now) else { return nil }
        let elapsed = state.elapsed(at: now)
        let current = baseTotal + elapsed / 3600
        guard let next = all.first(where: { Double($0) > current && !seen.contains($0) }) else { return nil }
        let seconds = (Double(next) - baseTotal) * 3600 - elapsed
        guard seconds > 0, seconds <= TimerState.autoPauseAfter - elapsed else { return nil }
        return (next, now.addingTimeInterval(seconds))
    }

    /// The line under the big number: short, in words. 10,000 keeps its own, longer line.
    static func message(hours: Int, craft: String) -> String {
        switch hours {
        case 100: return "A hundred hours."
        case 500: return "Five hundred hours."
        case 1_000: return "A thousand hours."
        case 2_000: return "Two thousand hours."
        case 2_500: return "Two and a half thousand hours."
        case 3_000: return "Three thousand hours."
        case 4_000: return "Four thousand hours."
        case 5_000: return "Five thousand hours."
        case 6_000: return "Six thousand hours."
        case 7_000: return "Seven thousand hours."
        case 7_500: return "Seven and a half thousand hours."
        case 8_000: return "Eight thousand hours."
        case 9_000: return "Nine thousand hours."
        case 10_000...: return "10,000 hours. The sun has fully risen."
        default: return "\(DurationFormat.grouped(hours)) hours."
        }
    }

    /// The notification for a milestone reached while the app is in the background, as on "A gentle nudge":
    /// "1,000 hours of piano. Sunrise is coming." At 10,000 the sun has risen instead.
    static func notificationMessage(hours: Int, craft: String) -> String {
        let name = craft.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let amount = String(localized: "\(DurationFormat.grouped(hours)) hours")
        let of = name.isEmpty ? amount : String(localized: "\(amount) of \(name)")
        return hours >= 10_000 ? String(localized: "\(of). The sun has fully risen.") : String(localized: "\(of). Sunrise is coming.")
    }

    /// "A thousand hours": the milestone in words, for the share card's VoiceOver label.
    static func words(hours: Int) -> String {
        let line = message(hours: hours, craft: "")
        if hours >= 10_000 { return String(localized: "10,000 hours") }
        return line.hasSuffix(".") ? String(line.dropLast()) : line
    }

    /// The icon has a stage for every whole thousand, so each of those celebrations says it has grown.
    /// 100, 500, 2,500 and 7,500 don't change it.
    static func iconGrows(at hours: Int) -> Bool { hours >= 1_000 && hours <= 10_000 && hours % 1_000 == 0 }
}

/// The milestone card to share (update 42, `design/redesign/MilestoneCard.dc.html`): its words.
enum MilestoneCardText {
    /// "1,000 h"
    static func number(_ hours: Int) -> String { "\(DurationFormat.grouped(hours)) h" }

    /// "Reached on 5 November 2026 · started in 2019"; without the start when it's the same year.
    static func reached(on date: Date, startYear: Int, calendar: Calendar = .current, locale: Locale = .current) -> String {
        let day = longDate(date, calendar: calendar, locale: locale)
        let year = calendar.component(.year, from: date)
        let first = String(localized: "Reached on \(day)")
        guard startYear > 0, startYear < year else { return first }
        return first + " · " + String(localized: "started in \(String(startYear))")
    }

    /// "A thousand hours of piano. Reached on 5 November 2026."
    static func spoken(hours: Int, craft: String, on date: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        let name = craft.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let words = Milestones.words(hours: hours)
        let first = name.isEmpty ? words : String(localized: "\(words) of \(name)")
        return first + ". " + String(localized: "Reached on \(longDate(date, calendar: calendar, locale: locale)).")
    }

    /// The file's name in the share sheet.
    static func fileName(hours: Int, craft: String) -> String {
        let safe = craft.components(separatedBy: CharacterSet(charactersIn: "/\\:?%*|\"<>")).joined()
        return "Long Game – \(DurationFormat.grouped(hours)) hours of \(safe.isEmpty ? "practice" : safe)"
    }

    static func longDate(_ date: Date, calendar: Calendar, locale: Locale) -> String {
        var style = Date.FormatStyle(date: .long, time: .omitted, locale: locale, calendar: calendar)
        style.timeZone = calendar.timeZone
        return date.formatted(style)
    }
}

enum ReminderPlanner {
    static let nudgeHour = 19
    static let nudgeLookbackWeeks = 4
    static let nudgeMinPracticeWeeks = 3
    static let nudgesPerWeek = 2

    struct RhythmNudge: Equatable {
        var date: Date
        var weekday: Int   // Calendar weekday: 1 = Sunday … 7 = Saturday
    }

    /// 7 pm on days in the coming week that the user usually practises (they practised on that weekday in at
    /// least 3 of the last 4 weeks) and has not practised yet. At most two a week, earliest first.
    /// Planned again whenever sessions change, so a nudge for a day already played is dropped.
    static func rhythmNudges(daily: [Date: Double], now: Date, calendar: Calendar = .current) -> [RhythmNudge] {
        let today = calendar.startOfDay(for: now)
        var result: [RhythmNudge] = []
        for offset in 0..<7 {
            guard result.count < nudgesPerWeek,
                  let day = calendar.date(byAdding: .day, value: offset, to: today),
                  (daily[day] ?? 0) <= 0,
                  let at = calendar.date(bySettingHour: nudgeHour, minute: 0, second: 0, of: day), at > now
            else { continue }
            let practised = (1...nudgeLookbackWeeks).filter { week in
                guard let earlier = calendar.date(byAdding: .day, value: -7 * week, to: day) else { return false }
                return (daily[earlier] ?? 0) > 0
            }.count
            if practised >= nudgeMinPracticeWeeks {
                result.append(RhythmNudge(date: at, weekday: calendar.component(.weekday, from: day)))
            }
        }
        return result
    }

    /// "Tuesdays usually get a little piano. The sun is up whenever you are."
    static func nudgeMessage(weekday: Int, craftName: String, calendar: Calendar = .current) -> String {
        let names = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]   // the app's copy is English
        let name = names[(weekday - 1 + 7) % 7]
        return "\(name)s usually get a little \(craftName.lowercased()). The sun is up whenever you are."
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

    /// A letter in the export. A sealed letter's text stays sealed here too.
    struct LetterRow {
        var craft: String
        var written: Date
        var milestone: Int
        var opened: Date?
        var text: String
    }

    /// `Craft,Written,For,Opened,Letter`: the letters, a second file next to the sessions.
    static func letters(_ rows: [LetterRow], calendar: Calendar = .current) -> String {
        let day = DateFormatter()
        day.calendar = calendar
        day.timeZone = calendar.timeZone
        day.locale = Locale(identifier: "en_GB")
        day.dateFormat = "yyyy-MM-dd"
        var lines = ["Craft,Written,For,Opened,Letter"]
        for r in rows.sorted(by: { $0.written < $1.written }) {
            let text = r.opened == nil ? "(sealed until \(r.milestone) h)" : r.text
            lines.append([escape(r.craft), day.string(from: r.written), "\(r.milestone) h",
                          r.opened.map { day.string(from: $0) } ?? "", escape(text)].joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
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
