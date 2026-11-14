import Foundation

/// The sun remembers (update 48): a small, rare line on Home made from the person's own history. Nothing new is
/// stored except the day the last one was shown.
enum Memory: Equatable, Sendable {
    /// The anniversary of the first session logged in the app.
    case firstDay(years: Int)
    /// A session photo taken on this date in an earlier year (the most recent such year).
    case photo(years: Int, sessionId: UUID, day: Date)
    /// Sessions on this calendar date in an earlier year (the most recent such year). `today` is today's time once
    /// it is at least as much; nil before today's first session.
    case yearAgo(years: Int, seconds: TimeInterval, today: TimeInterval?, day: Date)
    /// From the 10th: this month so far is already ahead of the whole of the same month last year.
    case sameMonth(month: Date, lastYear: TimeInterval, thisYear: TimeInterval)
    /// Today is the weekday played on most (at least 10, at least 2 ahead of the next one).
    case weekday(weekday: Int, count: Int)

    /// The opening words (shown in ember bold) and the rest of the line.
    var parts: (lead: String, rest: String) {
        switch self {
        case .firstDay(let years):
            return (Memory.agoToday(years), String(localized: "you played your first session here."))
        case .photo(let years, _, _):
            return (Memory.agoToday(years), String(localized: "you took this photo."))
        case .yearAgo(let years, let seconds, let today, _):
            let then = StretchText.clock(seconds: seconds)
            if let today {
                return (Memory.agoToday(years), String(localized: "you played \(then). Today, \(StretchText.clock(seconds: today))."))
            }
            return (Memory.agoToday(years), String(localized: "you played \(then)."))
        case .sameMonth(let month, let lastYear, let thisYear):
            let name = Memory.monthName(month)
            return (String(localized: "Last \(name):"),
                    String(localized: "\(Memory.hours(lastYear)). This \(name) so far: \(Memory.hours(thisYear))."))
        case .weekday(let weekday, let count):
            return (String(localized: "\(Memory.weekdayPlural(weekday)) are your day."),
                    String(localized: "\(count) of them so far."))
        }
    }

    /// The whole line, for VoiceOver.
    var text: String { parts.lead + " " + parts.rest }

    /// The day History opens on when the card is tapped (nil: today).
    var day: Date? {
        switch self {
        case .photo(_, _, let day), .yearAgo(_, _, _, let day): day
        default: nil
        }
    }

    /// "A year ago today," "Two years ago today,"
    static func agoToday(_ years: Int) -> String {
        years == 1 ? String(localized: "A year ago today,")
                   : String(localized: "\(Anniversary.capitalisedWord(years)) years ago today,")
    }

    /// "18 h", "45 m"
    static func hours(_ seconds: TimeInterval) -> String {
        seconds >= 3600 ? String(localized: "\(Int((seconds / 3600).rounded(.down))) h") : StretchText.clock(seconds: seconds)
    }

    static func monthName(_ date: Date, locale: Locale = .current) -> String {
        date.formatted(Date.FormatStyle(locale: locale).month(.wide))
    }

    /// "Thursdays"
    static func weekdayPlural(_ weekday: Int, locale: Locale = .current) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        let names = calendar.standaloneWeekdaySymbols
        let name = names[(weekday - 1 + 7) % 7]
        return String(localized: "\(name)s")
    }
}

enum Memories {
    /// A saved session, as the memories need it.
    struct Item: Equatable, Sendable {
        var id: UUID
        var start: Date
        var durationSec: TimeInterval
        var hasPhoto: Bool
        /// When it was logged in the app (its first day is "your first day").
        var loggedAt: Date
    }

    struct Input: Equatable, Sendable {
        var sessions: [Item]
        /// The Settings switch "The sun remembers".
        var enabled = true
        /// The day a memory was last shown (start of that day), if ever.
        var lastShownDay: Date?
        /// Today has a small anniversary pill or reached an hour milestone: no memory.
        var anniversaryToday = false
        var milestoneToday = false
    }

    /// The minimum days between two memory days.
    static let quietDays = 7

    /// Today's memory, if any: at most one, at most one day in seven (the day it was shown keeps it all day), never on
    /// a day with an anniversary pill or a milestone, never in the first month, and never a comparison that stings.
    static func today(_ input: Input, now: Date, calendar: Calendar = .current) -> Memory? {
        guard input.enabled, !input.anniversaryToday, !input.milestoneToday else { return nil }
        let today = calendar.startOfDay(for: now)
        if let last = input.lastShownDay.map({ calendar.startOfDay(for: $0) }), last != today,
           let days = calendar.dateComponents([.day], from: last, to: today).day, days < quietDays {
            return nil
        }
        guard let firstLogged = input.sessions.map(\.loggedAt).min(),
              let monthIn = calendar.date(byAdding: .month, value: 1, to: calendar.startOfDay(for: firstLogged)),
              today >= monthIn else { return nil }
        return candidates(input.sessions, now: now, calendar: calendar).first
    }

    /// Every memory that applies today, in the order of preference: first day, a photo's anniversary, a year ago
    /// today, the same month a year on, your day of the week.
    static func candidates(_ sessions: [Item], now: Date, calendar: Calendar = .current) -> [Memory] {
        let today = calendar.startOfDay(for: now)
        let todaySeconds = sessions.filter { calendar.isDate($0.start, inSameDayAs: now) }.reduce(0) { $0 + $1.durationSec }
        var out: [Memory] = []

        // Your first day.
        if let first = sessions.map(\.loggedAt).min(), let years = yearsAgo(first, today: today, calendar: calendar) {
            out.append(.firstDay(years: years))
        }

        // A photo's anniversary: the most recent earlier year with a photo on this date.
        let photos = sessions.filter(\.hasPhoto).compactMap { s in yearsAgo(s.start, today: today, calendar: calendar).map { (s, $0) } }
        if let (s, years) = photos.min(by: { $0.1 < $1.1 || ($0.1 == $1.1 && $0.0.start > $1.0.start) }) {
            out.append(.photo(years: years, sessionId: s.id, day: calendar.startOfDay(for: s.start)))
        }

        // A year ago today: the most recent earlier year with sessions on this date. With today's time only when it is
        // at least as much; after today's first session, a smaller day isn't remembered at all.
        let past = sessions.compactMap { s in yearsAgo(s.start, today: today, calendar: calendar).map { (s, $0) } }
        if let years = past.map(\.1).min() {
            let then = past.filter { $0.1 == years }
            let seconds = then.reduce(0) { $0 + $1.0.durationSec }
            if seconds >= 60 {
                let day = calendar.startOfDay(for: then[0].0.start)
                if todaySeconds == 0 {
                    out.append(.yearAgo(years: years, seconds: seconds, today: nil, day: day))
                } else if todaySeconds >= seconds {
                    out.append(.yearAgo(years: years, seconds: seconds, today: todaySeconds, day: day))
                }
            }
        }

        // The same month, a year on: from the 10th, when this month so far already beats all of last year's.
        if calendar.component(.day, from: today) >= 10,
           let monthStart = calendar.dateInterval(of: .month, for: today)?.start,
           let lastYearDate = calendar.date(byAdding: .year, value: -1, to: monthStart),
           let lastYearMonth = calendar.dateInterval(of: .month, for: lastYearDate) {
            let thisYear = sessions.filter { $0.start >= monthStart && $0.start <= now }.reduce(0) { $0 + $1.durationSec }
            let lastYear = sessions.filter { lastYearMonth.contains($0.start) && $0.start < lastYearMonth.end }
                .reduce(0) { $0 + $1.durationSec }
            if lastYear >= 3600, thisYear > lastYear {
                out.append(.sameMonth(month: monthStart, lastYear: lastYear, thisYear: thisYear))
            }
        }

        // Your day of the week: today's weekday has the most days played, at least 10, at least 2 ahead.
        let days = Set(sessions.filter { $0.start <= now }.map { calendar.startOfDay(for: $0.start) })
        var perWeekday: [Int: Int] = [:]
        for d in days { perWeekday[calendar.component(.weekday, from: d), default: 0] += 1 }
        let weekday = calendar.component(.weekday, from: today)
        let mine = perWeekday[weekday] ?? 0
        let others = perWeekday.filter { $0.key != weekday }.map(\.value).max() ?? 0
        if mine >= 10, mine >= others + 2 {
            out.append(.weekday(weekday: weekday, count: mine))
        }
        return out
    }

    /// How many years ago `date` fell on today's calendar date (1 or more), else nil. A 29 February is remembered on
    /// 28 February in the years without one.
    static func yearsAgo(_ date: Date, today: Date, calendar: Calendar) -> Int? {
        let d = calendar.dateComponents([.year, .month, .day], from: date)
        let t = calendar.dateComponents([.year, .month, .day], from: today)
        guard let dy = d.year, let ty = t.year, dy < ty else { return nil }
        if d.month == t.month && d.day == t.day { return ty - dy }
        if d.month == 2, d.day == 29, t.month == 2, t.day == 28, !isLeap(ty, calendar: calendar) { return ty - dy }
        return nil
    }

    private static func isLeap(_ year: Int, calendar: Calendar) -> Bool {
        guard let feb = calendar.date(from: DateComponents(year: year, month: 2, day: 1)),
              let range = calendar.range(of: .day, in: .month, for: feb) else { return false }
        return range.count == 29
    }
}
