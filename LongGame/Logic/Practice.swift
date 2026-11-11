import Foundation

enum Practice {
    /// Seconds per day, keyed by the start of the day a session began on
    /// (a session crossing midnight counts on the day it started).
    static func dailySeconds(_ sessions: [SessionRecord], calendar: Calendar = .current) -> [Date: Double] {
        perDay(sessions, calendar: calendar, \.durationSec)
    }

    /// Adds up `value` per day a session began on. Sessions come in date order, so the day just worked out is
    /// reused while the next session falls inside it: asking the calendar for each session's day was the slow part.
    static func perDay(_ sessions: [SessionRecord], calendar: Calendar = .current,
                       _ value: (SessionRecord) -> Double) -> [Date: Double] {
        var result: [Date: Double] = [:]
        var day: DateInterval?
        for s in sessions {
            if day.map({ s.start < $0.start || s.start >= $0.end }) ?? true {
                day = calendar.dateInterval(of: .day, for: s.start)
                    ?? DateInterval(start: calendar.startOfDay(for: s.start), duration: 0)
            }
            result[day!.start, default: 0] += value(s)
        }
        return result
    }

    /// Days with any logged time in the inclusive range.
    static func activeDays(daily: [Date: Double], from: Date, to: Date, calendar: Calendar = .current) -> Int {
        let lo = calendar.startOfDay(for: from), hi = calendar.startOfDay(for: to)
        return daily.filter { $0.value > 0 && $0.key >= lo && $0.key <= hi }.count
    }
}

/// The gentle replacement for streaks: how many days a week the user usually
/// practises, and for how many weeks in a row they have kept to it. Nothing ever "breaks".
/// Catch-up sessions count like any other session.
enum Rhythm {
    /// The last 8 complete weeks plus the current one.
    static let lookbackWeeks = 8

    struct Result: Equatable, Sendable {
        /// Typical practice days per week (0 when there is nothing to go on).
        var daysPerWeek: Int
        /// Consecutive weeks with at least `daysPerWeek - 1` practice days (and never fewer than one).
        var steadyWeeks: Int
    }

    static func compute(daily: [Date: Double], since: Date, now: Date, weekStart: WeekStart,
                        calendar: Calendar = .current) -> Result {
        let cal = WeekMath.calendar(calendar, weekStart: weekStart)
        let thisWeek = WeekMath.startOfWeek(now, weekStart: weekStart, calendar: calendar)
        // Weeks before the user began (or first logged anything) are not rest weeks, they are not part of the story.
        let firstDay = min(cal.startOfDay(for: since), daily.filter { $0.value > 0 }.keys.min() ?? .distantFuture)
        let firstWeek = WeekMath.startOfWeek(firstDay, weekStart: weekStart, calendar: calendar)

        func practiceDays(inWeekStarting start: Date) -> Int {
            guard let end = cal.date(byAdding: .day, value: 7, to: start) else { return 0 }
            return daily.filter { $0.value > 0 && $0.key >= start && $0.key < end }.count
        }
        func week(_ back: Int) -> Date? { cal.date(byAdding: .weekOfYear, value: -back, to: thisWeek) }

        var recent: [Int] = []
        for back in 0...lookbackWeeks {
            guard let start = week(back), start >= firstWeek else { break }
            recent.append(practiceDays(inWeekStarting: start))
        }
        let sorted = recent.sorted()
        guard let rhythm = sorted.isEmpty ? nil : sorted[sorted.count / 2], rhythm > 0 else {
            return Result(daysPerWeek: 0, steadyWeeks: 0)
        }

        // At least one practice day, so a rhythm of 1 never counts rest weeks as steady.
        // The week in progress counts when it already keeps to the rhythm; it never ends the run early.
        let needed = max(1, rhythm - 1)
        var steady = 0
        var back = 0
        while let start = week(back), start >= firstWeek {
            if practiceDays(inWeekStarting: start) >= needed {
                steady += 1
            } else if back > 0 {
                break
            }
            back += 1
        }
        return Result(daysPerWeek: rhythm, steadyWeeks: steady)
    }
}

enum CalendarLevel: Int, CaseIterable, Sendable {
    case rest, under1, from1to2, from2to3, over3

    /// 0 = rest, < 1 h, 1–2 h, 2–3 h, 3 h+
    static func level(hours: Double) -> CalendarLevel {
        switch hours {
        case ..<0.0001: .rest
        case ..<1: .under1
        case ..<2: .from1to2
        case ..<3: .from2to3
        default: .over3
        }
    }
}

enum CalendarGrid {
    /// `count` week columns ending with the week that contains `today`,
    /// each with 7 days starting on the chosen first weekday.
    static func weeks(endingOn today: Date, count: Int = 53, weekStart: WeekStart, calendar: Calendar = .current) -> [[Date]] {
        let cal = WeekMath.calendar(calendar, weekStart: weekStart)
        let thisWeek = WeekMath.startOfWeek(today, weekStart: weekStart, calendar: calendar)
        guard let first = cal.date(byAdding: .weekOfYear, value: -(count - 1), to: thisWeek) else { return [] }
        return (0..<count).map { w in
            (0..<7).compactMap { d in
                cal.date(byAdding: .day, value: w * 7 + d, to: first)
            }
        }
    }
}

// MARK: Sample year

/// A small, fast random generator that gives the same numbers every time for the same seed (SplitMix64).
/// Used for sample data, so previews and the debug option look natural but never change between runs.
struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// A number in 0..<1.
    mutating func unit() -> Double { Double(next() >> 11) * 0x1.0p-53 }
}

/// A made-up year of practice that looks like a real person's: busy weeks and quiet ones, quieter weekends, the odd
/// week off, and a photo on about one practice day in seven. The same year always gives the same days.
/// The designs (`design/redesign/Calendar.dc.html`, `YearCard.dc.html`) use the same rule.
enum SampleYear {
    struct Day: Equatable, Sendable {
        var date: Date
        var level: CalendarLevel
        /// Minutes played (0 on a rest day), inside the level's range.
        var minutes: Int
        var hasPhoto: Bool
    }

    /// Share of weeks that are a break.
    static let breakChance = 0.08
    /// On a break week, the share of days that are rest.
    static let breakRest = 0.85
    static let photoChance = 1.0 / 7

    /// Every day of `year`, in order, weeks starting on Monday.
    static func days(year: Int, calendar: Calendar = .current) -> [Day] {
        var cal = calendar
        cal.firstWeekday = 2
        var rng = SeededRandom(seed: UInt64(max(0, year)))
        guard let first = cal.date(from: DateComponents(year: year, month: 1, day: 1)) else { return [] }
        var result: [Day] = []
        var day = first
        var energy = 0.0, isBreak = false
        var started = false
        while cal.component(.year, from: day) == year {
            let weekday = cal.component(.weekday, from: day)   // 1 = Sunday … 7 = Saturday
            if !started || weekday == 2 {
                energy = rng.unit()
                isBreak = rng.unit() < breakChance
                started = true
            }
            result.append(self.day(day, weekend: weekday == 1 || weekday == 7, energy: energy, isBreak: isBreak, rng: &rng))
            guard let next = cal.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return result
    }

    /// One day from the week's energy (0–1) and whether the week is a break.
    static func day(_ date: Date, weekend: Bool, energy: Double, isBreak: Bool, rng: inout SeededRandom) -> Day {
        if rng.unit() < restChance(weekend: weekend, energy: energy, isBreak: isBreak) {
            return Day(date: date, level: .rest, minutes: 0, hasPhoto: false)
        }
        let level = level(x: rng.unit() * 0.75 + energy * 0.42)
        let range = minutes(level)
        let minutes = range.lowerBound + Int(rng.unit() * Double(range.count))
        return Day(date: date, level: level, minutes: minutes, hasPhoto: rng.unit() < photoChance)
    }

    /// 0.20, plus 0.14 at the weekend, minus energy × 0.14; 0.85 in a break week.
    static func restChance(weekend: Bool, energy: Double, isBreak: Bool) -> Double {
        isBreak ? breakRest : 0.20 + (weekend ? 0.14 : 0) - energy * 0.14
    }

    /// 1 below 0.33, 2 below 0.58, 3 below 0.84, otherwise 4.
    static func level(x: Double) -> CalendarLevel {
        switch x {
        case ..<0.33: .under1
        case ..<0.58: .from1to2
        case ..<0.84: .from2to3
        default: .over3
        }
    }

    /// The minutes a sample session can have at each level (the calendar's hour bands).
    static func minutes(_ level: CalendarLevel) -> Range<Int> {
        switch level {
        case .rest: 0..<1
        case .under1: 15..<60
        case .from1to2: 60..<120
        case .from2to3: 120..<180
        case .over3: 180..<241
        }
    }
}
