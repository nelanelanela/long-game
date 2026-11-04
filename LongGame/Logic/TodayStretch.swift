import Foundation
import CoreGraphics

// Today's stretch: the weekly target turned into today's distance. Pure functions, nothing stored.
// The fixed part (the stretch itself) comes only from sessions before today, so playing today never moves it.

/// What Home's Today tab and the Timer's strip show.
enum StretchState: Equatable, Sendable {
    /// On the way: `done` of `target`, both in seconds.
    case stretch(target: TimeInterval, done: TimeInterval)
    /// Today's stretch is done; anything more is a bonus.
    case covered(target: TimeInterval, done: TimeInterval)
    /// Today is not one of the user's practice days. `done` is any time played anyway.
    case restDay(done: TimeInterval)
    /// This week's target was already reached when today began.
    case weekCovered(done: TimeInterval)
    /// No weekly target chosen yet.
    case noTarget

    /// Seconds played today (0 when there is no target).
    var done: TimeInterval {
        switch self {
        case .stretch(_, let d), .covered(_, let d), .restDay(let d), .weekCovered(let d): d
        case .noTarget: 0
        }
    }

    var target: TimeInterval? {
        switch self {
        case .stretch(let t, _), .covered(let t, _): t
        default: nil
        }
    }

    /// How far along the arc the sun is, 0...1. Rest days stay at the start; a covered week sits at the end.
    var fraction: Double {
        switch self {
        case .stretch(let t, let d): t > 0 ? min(1, max(0, d / t)) : 0
        case .covered, .weekCovered: 1
        case .restDay, .noTarget: 0
        }
    }

    /// The whole arc is drawn gold.
    var isCovered: Bool {
        switch self {
        case .covered, .weekCovered: true
        default: false
        }
    }

    var isWeekCovered: Bool {
        if case .weekCovered = self { return true }
        return false
    }

    /// The Timer shows its strip only while there is a stretch to cover (or just covered).
    var showsOnTimer: Bool { target != nil }
}

/// The fixed part of today's stretch, worked out from what was saved before the app was opened today.
struct StretchPlan: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case stretch(target: TimeInterval)
        case restDay
        case weekCovered
        case noTarget
    }

    var kind: Kind
    /// Seconds from sessions that started today and are already saved.
    var doneSaved: TimeInterval

    /// The state with the running timer's elapsed time added (it counts towards the day it started).
    func state(running: TimeInterval = 0) -> StretchState {
        let done = doneSaved + max(0, running)
        switch kind {
        case .noTarget: return .noTarget
        case .restDay: return .restDay(done: done)
        case .weekCovered: return .weekCovered(done: done)
        case .stretch(let target): return done >= target ? .covered(target: target, done: done) : .stretch(target: target, done: done)
        }
    }

    /// Whether a session of this length, added to what was saved, takes the stretch from open to covered.
    func isCovered(byAdding seconds: TimeInterval) -> Bool {
        guard case .stretch(let target) = kind else { return false }
        return doneSaved < target && doneSaved + seconds >= target
    }

    /// Seconds into a running session at which the stretch got covered, nil when it was covered before it began
    /// or there is no stretch.
    func coveredAfter() -> TimeInterval? {
        guard case .stretch(let target) = kind, doneSaved < target else { return nil }
        return target - doneSaved
    }
}

enum Stretch {
    /// The stretch is rounded to the nearest 5 minutes, and is never shorter than 15.
    static let rounding: TimeInterval = 5 * 60
    static let minimum: TimeInterval = 15 * 60
    /// A weekday counts when the user practised on it in at least this many of the last `lookbackWeeks` full weeks.
    static let lookbackWeeks = 4
    static let weeksNeeded = 2
    static let minimumHistoryWeeks = 2

    /// Round to the nearest 5 minutes, at least 15.
    static func rounded(_ seconds: TimeInterval) -> TimeInterval {
        max(minimum, (seconds / rounding).rounded() * rounding)
    }

    /// The weekdays (`Calendar` numbers, 1 = Sunday … 7 = Saturday) the user usually practises on: those with
    /// practice in at least 2 of the last 4 full weeks. With fewer than 2 full weeks of history, or when no day
    /// qualifies, every day counts.
    static func practiceDays(sessions: [SessionRecord], today: Date, weekStart: WeekStart,
                             calendar: Calendar = .current) -> Set<Int> {
        let everyDay = Set(1...7)
        let cal = WeekMath.calendar(calendar, weekStart: weekStart)
        guard let firstSession = sessions.map(\.start).min() else { return everyDay }
        let thisWeek = WeekMath.startOfWeek(today, weekStart: weekStart, calendar: calendar)
        let firstDay = cal.startOfDay(for: firstSession)

        // Full weeks only: weeks that are over, and that began on or after the first logged day.
        var weeks: [Date] = []
        for back in 1...lookbackWeeks {
            guard let start = cal.date(byAdding: .weekOfYear, value: -back, to: thisWeek), start >= firstDay else { break }
            weeks.append(start)
        }
        guard weeks.count >= minimumHistoryWeeks else { return everyDay }

        let daily = Practice.dailySeconds(sessions, calendar: cal)
        var weeksPerWeekday: [Int: Int] = [:]
        for start in weeks {
            var seen = Set<Int>()
            for offset in 0..<7 {
                guard let day = cal.date(byAdding: .day, value: offset, to: start), (daily[day] ?? 0) > 0 else { continue }
                seen.insert(cal.component(.weekday, from: day))
            }
            for weekday in seen { weeksPerWeekday[weekday, default: 0] += 1 }
        }
        let usual = Set(weeksPerWeekday.filter { $0.value >= weeksNeeded }.keys)
        return usual.isEmpty ? everyDay : usual
    }

    /// Today's stretch, with the saved part of today's time. `weeklyTargetHours` is the target that applies this
    /// week (nil or 0 = none). `hoursBeforeToday` and `forceRestDay` exist so the debug options can show every state.
    static func plan(sessions: [SessionRecord], weeklyTargetHours: Double?, now: Date, weekStart: WeekStart,
                     calendar: Calendar = .current, hoursBeforeToday: Double? = nil, forceRestDay: Bool = false) -> StretchPlan {
        let cal = WeekMath.calendar(calendar, weekStart: weekStart)
        let today = cal.startOfDay(for: now)
        let tomorrow = cal.date(byAdding: .day, value: 1, to: today) ?? today.addingTimeInterval(86_400)
        let doneSaved = sessions.filter { $0.start >= today && $0.start < tomorrow }.reduce(0) { $0 + $1.durationSec }

        guard let weeklyTargetHours, weeklyTargetHours > 0 else { return StretchPlan(kind: .noTarget, doneSaved: doneSaved) }

        let practice = practiceDays(sessions: sessions, today: today, weekStart: weekStart, calendar: calendar)
        let todayWeekday = cal.component(.weekday, from: today)
        if forceRestDay || !practice.contains(todayWeekday) { return StretchPlan(kind: .restDay, doneSaved: doneSaved) }

        let weekFirst = WeekMath.startOfWeek(now, weekStart: weekStart, calendar: calendar)
        let before = hoursBeforeToday
            ?? sessions.filter { $0.start >= weekFirst && $0.start < today }.reduce(0) { $0 + $1.hours }
        let remaining = weeklyTargetHours - before
        if remaining <= 0 { return StretchPlan(kind: .weekCovered, doneSaved: doneSaved) }

        // Practice days left this week, including today (today is one, so at least 1).
        let dayOfWeek = cal.dateComponents([.day], from: weekFirst, to: today).day ?? 0
        var left = 0
        for offset in dayOfWeek..<7 {
            guard let day = cal.date(byAdding: .day, value: offset - dayOfWeek, to: today) else { continue }
            if practice.contains(cal.component(.weekday, from: day)) { left += 1 }
        }
        let stretch = rounded(remaining * 3600 / Double(max(1, left)))
        return StretchPlan(kind: .stretch(target: stretch), doneSaved: doneSaved)
    }

    /// The state in one go: the plan plus the running timer's elapsed time.
    static func todayStretch(sessions: [SessionRecord], weeklyTargetHours: Double?, now: Date, weekStart: WeekStart,
                             running: TimeInterval = 0, calendar: Calendar = .current,
                             hoursBeforeToday: Double? = nil, forceRestDay: Bool = false) -> StretchState {
        plan(sessions: sessions, weeklyTargetHours: weeklyTargetHours, now: now, weekStart: weekStart,
             calendar: calendar, hoursBeforeToday: hoursBeforeToday, forceRestDay: forceRestDay).state(running: running)
    }

    /// The target in force this week from the history of weekly targets (nil before the first).
    static func weeklyTarget(now: Date, weekStart: WeekStart, periods: [TargetRecord], current: TargetRecord?,
                             calendar: Calendar = .current) -> Double? {
        let first = WeekMath.startOfWeek(now, weekStart: weekStart, calendar: calendar)
        return TargetHistory.hours(forWeekStarting: first, periods: periods, current: current, calendar: calendar)
    }
}

/// Where the sun sits on today's arc, and the wording for it. Plain numbers, so the picture can be tested.
enum StretchArc {
    /// A half-ellipse from the sea on the left to the moon on the right. Fraction 0 is the left end (on the
    /// horizon), 1 the right end. The sun is at angle `fraction × 180°`.
    static func point(fraction: Double, centreX: CGFloat, baseY: CGFloat, radiusX: CGFloat, radiusY: CGFloat) -> CGPoint {
        let theta = CGFloat(GaugeGeometry.clamped(fraction)) * .pi
        return CGPoint(x: centreX - radiusX * cos(theta), y: baseY - radiusY * sin(theta))
    }
}

enum StretchText {
    /// "1 h 05" or "40 m". Minutes are cut down (a sun at 59 m 50 s still says 59 m).
    static func clock(seconds: TimeInterval) -> String { format(minutes: Int(max(0, seconds) / 60)) }

    /// Same, but a part-minute counts as a whole one, so "to go" never says 0 m while there is time left.
    static func clockUp(seconds: TimeInterval) -> String { format(minutes: Int((max(0, seconds) / 60).rounded(.up))) }

    private static func format(minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        return h > 0 ? String(format: "%d h %02d", h, m) : "\(m) m"
    }

    /// "of today's 1 h 45"
    static func ofToday(_ target: TimeInterval) -> String { String(localized: "of today's \(clock(seconds: target))") }

    /// "today's 1 h 45 · covered"
    static func coveredToday(_ target: TimeInterval) -> String { String(localized: "today's \(clock(seconds: target)) · covered") }

    /// "40 m to today's resting place"
    static func toGo(_ remaining: TimeInterval) -> String { String(localized: "\(clockUp(seconds: remaining)) to today's resting place") }

    /// "1 h 05 of 1 h 45", the Timer strip.
    static func progress(done: TimeInterval, target: TimeInterval) -> String {
        String(localized: "\(clock(seconds: done)) of \(clock(seconds: target))")
    }

    /// "1 h 45 · covered", the Timer strip once the stretch is done.
    static func stripCovered(_ target: TimeInterval) -> String { String(localized: "\(clock(seconds: target)) · covered") }

    /// "1 hour 5 minutes" (spoken), whole minutes.
    static func spoken(seconds: TimeInterval) -> String { Labels.spoken(seconds: Int(max(0, seconds) / 60) * 60, includeSeconds: false) }
    static func spokenUp(seconds: TimeInterval) -> String {
        Labels.spoken(seconds: Int((max(0, seconds) / 60).rounded(.up)) * 60, includeSeconds: false)
    }

    /// What VoiceOver reads for the whole picture.
    static func description(_ state: StretchState) -> String {
        switch state {
        case .stretch(let target, let done):
            return String(localized: "Today's stretch: \(spoken(seconds: done)) of \(spoken(seconds: target)). \(spokenUp(seconds: target - done)) to go.")
        case .covered(let target, let done):
            return String(localized: "Today's stretch covered: \(spoken(seconds: done)) of \(spoken(seconds: target)). Anything more is a bonus.")
        case .weekCovered(let done):
            return String(localized: "This week is covered. Today: \(spoken(seconds: done)). Anything more is a bonus.")
        case .restDay(let done):
            return done > 0 ? String(localized: "Rest day: the sun is resting on the horizon. Played anyway: \(spoken(seconds: done)).")
                            : String(localized: "Rest day: the sun is resting on the horizon.")
        case .noTarget:
            return String(localized: "No weekly target yet.")
        }
    }
}
