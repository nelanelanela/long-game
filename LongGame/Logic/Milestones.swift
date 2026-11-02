import Foundation

enum Milestones {
    static let all = [100, 500, 1_000, 2_500, 5_000, 7_500, 10_000]

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

    static func message(hours: Int, craft: String) -> String {
        if hours >= 10_000 { return "10,000 hours. The sun has fully risen." }
        let formatted = DurationFormat.grouped(hours)
        return "\(formatted) hours of \(craft.lowercased()). Sunrise is coming."
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
