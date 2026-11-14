import Foundation

/// The weekly look-back: last week's numbers, worked out from the stored sessions (nothing here is stored).
struct WeekLookBack: Equatable, Sendable {
    /// A session as the look-back needs it.
    struct Entry: Equatable, Sendable {
        var id: UUID
        var start: Date
        var seconds: TimeInterval
        var hasPhoto = false
        var viewCount = 0
        var note: String?
    }

    /// The part of the day the most hours fell in ("Mostly"). Same hours as the session pictures: night before 5:30
    /// or from 21:30, then morning, midday, afternoon and evening; midday is split at noon between mornings and
    /// afternoons, since the figure only has four words.
    enum Part: Int, Comparable, CaseIterable, Sendable {
        // In the order of the day, so "later part wins" a tie.
        case morning, afternoon, evening, night

        static func < (a: Part, b: Part) -> Bool { a.rawValue < b.rawValue }

        static func at(_ date: Date, calendar: Calendar) -> Part {
            let c = calendar.dateComponents([.hour, .minute], from: date)
            let hour = Double(c.hour ?? 0) + Double(c.minute ?? 0) / 60
            switch SessionDaypart.at(startHour: hour) {
            case .night: return .night
            case .morning: return .morning
            case .midday: return hour < 12 ? .morning : .afternoon
            case .afternoon: return .afternoon
            case .evening: return .evening
            }
        }

        /// "Mornings", the figure.
        var plural: String {
            switch self {
            case .morning: String(localized: "Mornings")
            case .afternoon: String(localized: "Afternoons")
            case .evening: String(localized: "Evenings")
            case .night: String(localized: "Nights")
            }
        }

        /// "evening", as in "A moment from Thursday evening".
        var singular: String {
            switch self {
            case .morning: String(localized: "morning")
            case .afternoon: String(localized: "afternoon")
            case .evening: String(localized: "evening")
            case .night: String(localized: "night")
            }
        }
    }

    /// The one moment shown: a photo (most viewed, else most recent), else the longest session's picture.
    struct Moment: Equatable, Sendable {
        enum Kind: Equatable, Sendable { case photo, sessionPicture }
        var sessionId: UUID
        var kind: Kind
        var start: Date
        var seconds: TimeInterval
        var note: String?
        var part: Part
    }

    /// The first day of last week, and the seven days.
    var weekStart: Date
    var days: [Date]
    var dayHours: [Double]
    var hours: Double
    var previousHours: Double
    var daysPlayed: Int
    /// Index into `days` of the longest day (ties: the later day).
    var longestDay: Int?
    var mostly: Part?
    var moment: Moment?

    /// "1 h 15 more than the week before." only when the week was up; nil when level or down.
    var moreThanBefore: TimeInterval? {
        let diff = ((hours - previousHours) * 3600).rounded()
        return diff >= 60 ? diff : nil
    }

    /// The week that ended before `now`'s week, or nil when it had no session.
    static func make(_ entries: [Entry], now: Date, weekStart ws: WeekStart, calendar: Calendar = .current) -> WeekLookBack? {
        let cal = WeekMath.calendar(calendar, weekStart: ws)
        let thisWeek = WeekMath.startOfWeek(now, weekStart: ws, calendar: calendar)
        guard let start = cal.date(byAdding: .day, value: -7, to: thisWeek),
              let before = cal.date(byAdding: .day, value: -14, to: thisWeek) else { return nil }
        let week = entries.filter { $0.start >= start && $0.start < thisWeek }
        guard !week.isEmpty else { return nil }
        let previous = entries.filter { $0.start >= before && $0.start < start }

        let days = (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
        var dayHours = Array(repeating: 0.0, count: days.count)
        var partHours: [Part: Double] = [:]
        for e in week {
            let day = cal.startOfDay(for: e.start)
            if let i = days.firstIndex(of: day) { dayHours[i] += e.seconds / 3600 }
            partHours[Part.at(e.start, calendar: cal), default: 0] += e.seconds
        }
        let best = dayHours.max() ?? 0
        let longest = best > 0 ? dayHours.lastIndex(of: best) : nil
        let topPart = partHours.values.max() ?? 0
        let mostly = topPart > 0 ? partHours.filter { $0.value == topPart }.keys.max() : nil

        return WeekLookBack(weekStart: start, days: days, dayHours: dayHours,
                            hours: week.reduce(0) { $0 + $1.seconds } / 3600,
                            previousHours: previous.reduce(0) { $0 + $1.seconds } / 3600,
                            daysPlayed: dayHours.filter { $0 > 0 }.count,
                            longestDay: longest, mostly: mostly,
                            moment: moment(week, calendar: cal))
    }

    /// The week's most-viewed photo, else its most recent photo, else the longest session (its session picture).
    static func moment(_ week: [Entry], calendar: Calendar) -> Moment? {
        let photos = week.filter(\.hasPhoto)
        if let viewed = photos.filter({ $0.viewCount > 0 }).max(by: { ($0.viewCount, $0.start) < ($1.viewCount, $1.start) }) {
            return make(viewed, .photo, calendar)
        }
        if let recent = photos.max(by: { $0.start < $1.start }) {
            return make(recent, .photo, calendar)
        }
        if let longest = week.max(by: { ($0.seconds, $0.start) < ($1.seconds, $1.start) }) {
            return make(longest, .sessionPicture, calendar)
        }
        return nil
    }

    private static func make(_ e: Entry, _ kind: Moment.Kind, _ calendar: Calendar) -> Moment {
        Moment(sessionId: e.id, kind: kind, start: e.start, seconds: e.seconds, note: e.note,
               part: Part.at(e.start, calendar: calendar))
    }

    // MARK: When

    /// Whether to show the look-back now: the first open in a new week, once per week, never in the very first week
    /// (the week of onboarding), and not while a session runs or a sheet is up (it waits for the next open).
    static func shouldShow(now: Date, weekStart ws: WeekStart, onboardingDate: Date, lastShownWeek: Date?,
                           lastWeekHadSession: Bool, sessionRunning: Bool, sheetOpen: Bool,
                           calendar: Calendar = .current) -> Bool {
        guard lastWeekHadSession, !sessionRunning, !sheetOpen else { return false }
        let thisWeek = WeekMath.startOfWeek(now, weekStart: ws, calendar: calendar)
        guard thisWeek > WeekMath.startOfWeek(onboardingDate, weekStart: ws, calendar: calendar) else { return false }
        if let lastShownWeek, lastShownWeek >= thisWeek { return false }
        return true
    }

    // MARK: Words

    /// "2 – 8 November", or "29 October – 4 November" across months.
    func dates(calendar: Calendar = .current) -> String {
        guard let last = days.last, let first = days.first else { return "" }
        let sameMonth = calendar.component(.month, from: first) == calendar.component(.month, from: last)
        let day = CachedFormatter.pattern("d", calendar: calendar)
        let dayMonth = CachedFormatter.pattern("d MMMM", calendar: calendar)
        let from = sameMonth ? day.string(from: first) : dayMonth.string(from: first)
        return "\(from) – \(dayMonth.string(from: last))"
    }

    /// "Thu · 2 h 10".
    func longestDayText(calendar: Calendar = .current) -> String? {
        guard let i = longestDay else { return nil }
        let name = CachedFormatter.pattern("EEE", calendar: calendar).string(from: days[i])
        return "\(name) · \(StretchText.clock(seconds: (dayHours[i] * 3600).rounded()))"
    }

    /// "Monday 1 hour 30, Tuesday 1 hour 50, Wednesday rest, Thursday 2 hours 10, the longest day, …".
    func spokenBars(calendar: Calendar = .current) -> String {
        let names = CachedFormatter.pattern("EEEE", calendar: calendar)
        let parts = days.indices.map { i -> String in
            let name = names.string(from: days[i])
            guard dayHours[i] > 0 else { return String(localized: "\(name) rest") }
            let amount = StretchText.spoken(seconds: (dayHours[i] * 3600).rounded())
            return i == longestDay ? String(localized: "\(name) \(amount), the longest day") : "\(name) \(amount)"
        }
        return String(localized: "Last week, day by day: \(parts.joined(separator: ", ")).")
    }

    /// "A moment from Thursday evening".
    func momentWhen(calendar: Calendar = .current) -> String? {
        guard let moment else { return nil }
        let day = CachedFormatter.pattern("EEEE", calendar: calendar).string(from: moment.start)
        return String(localized: "A moment from \(day) \(moment.part.singular)")
    }

    /// The moment's second line: its note, or its time and length ("19:40 · 1 h 10").
    func momentLine(calendar: Calendar = .current) -> String? {
        guard let moment else { return nil }
        if let note = moment.note, !note.isEmpty { return note }
        let time = CachedFormatter.pattern("HH:mm", calendar: calendar).string(from: moment.start)
        return "\(time) · \(StretchText.clock(seconds: moment.seconds))"
    }
}
