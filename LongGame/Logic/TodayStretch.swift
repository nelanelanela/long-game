import Foundation
import CoreGraphics

// Today's stretch: the weekly pace divided by seven. Pure functions, nothing stored.
// It is the same every day, so playing today never moves it.

/// What Home's Today tab and the Timer's strip show.
enum StretchState: Equatable, Sendable {
    /// On the way: `done` of `target`, both in seconds.
    case inProgress(target: TimeInterval, done: TimeInterval)
    /// Today's stretch is done; anything more is a bonus.
    case covered(target: TimeInterval, done: TimeInterval)
    /// No weekly pace chosen yet (shouldn't happen after onboarding; Home shows This week instead).
    case noTarget

    /// Seconds played today (0 when there is no target).
    var done: TimeInterval {
        switch self {
        case .inProgress(_, let d), .covered(_, let d): d
        case .noTarget: 0
        }
    }

    var target: TimeInterval? {
        switch self {
        case .inProgress(let t, _), .covered(let t, _): t
        case .noTarget: nil
        }
    }

    /// How far along the arc the sun is, 0...1.
    var fraction: Double {
        switch self {
        case .inProgress(let t, let d): t > 0 ? min(1, max(0, d / t)) : 0
        case .covered: 1
        case .noTarget: 0
        }
    }

    /// The whole arc is drawn gold.
    var isCovered: Bool {
        if case .covered = self { return true }
        return false
    }

    /// The Timer shows its strip only while there is a stretch to cover (or just covered).
    var showsOnTimer: Bool { target != nil }
}

/// Today's stretch together with the time already saved today.
struct StretchPlan: Equatable, Sendable {
    /// Today's stretch in seconds, nil when there is no weekly pace.
    var target: TimeInterval?
    /// Seconds from sessions that started today and are already saved.
    var doneSaved: TimeInterval

    /// The state with the running timer's elapsed time added (it counts towards the day it started).
    func state(running: TimeInterval = 0) -> StretchState {
        guard let target else { return .noTarget }
        let done = doneSaved + max(0, running)
        return done >= target ? .covered(target: target, done: done) : .inProgress(target: target, done: done)
    }

    /// Whether a session of this length, added to what was saved, takes the stretch from open to covered.
    func isCovered(byAdding seconds: TimeInterval) -> Bool {
        guard let target else { return false }
        return doneSaved < target && doneSaved + seconds >= target
    }

    /// Seconds into a running session at which the stretch got covered, nil when it was covered before it began
    /// or there is no stretch.
    func coveredAfter() -> TimeInterval? {
        guard let target, doneSaved < target else { return nil }
        return target - doneSaved
    }
}

enum Stretch {
    /// The stretch is rounded to the nearest 5 minutes (and is never 0).
    static let rounding: TimeInterval = 5 * 60

    /// Weekly pace ÷ 7, rounded to the nearest 5 minutes, at least 5. 7 h → 1 h, 12 h → 1 h 45, 3 h → 25 m.
    static func stretch(weeklyHours: Double) -> TimeInterval {
        max(rounding, (weeklyHours * 3600 / 7 / rounding).rounded() * rounding)
    }

    /// Today's stretch, with the saved part of today's time. `weeklyTargetHours` is the pace that applies this
    /// week (nil or 0 = none).
    static func plan(sessions: [SessionRecord], weeklyTargetHours: Double?, now: Date, weekStart: WeekStart,
                     calendar: Calendar = .current) -> StretchPlan {
        let cal = WeekMath.calendar(calendar, weekStart: weekStart)
        let today = cal.startOfDay(for: now)
        let tomorrow = cal.date(byAdding: .day, value: 1, to: today) ?? today.addingTimeInterval(86_400)
        let doneSaved = sessions.filter { $0.start >= today && $0.start < tomorrow }.reduce(0) { $0 + $1.durationSec }
        guard let weeklyTargetHours, weeklyTargetHours > 0 else { return StretchPlan(target: nil, doneSaved: doneSaved) }
        return StretchPlan(target: stretch(weeklyHours: weeklyTargetHours), doneSaved: doneSaved)
    }

    /// The state in one go: the plan plus the running timer's elapsed time.
    static func todayStretch(sessions: [SessionRecord], weeklyTargetHours: Double?, now: Date, weekStart: WeekStart,
                             running: TimeInterval = 0, calendar: Calendar = .current) -> StretchState {
        plan(sessions: sessions, weeklyTargetHours: weeklyTargetHours, now: now, weekStart: weekStart,
             calendar: calendar).state(running: running)
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

    /// "40 m to go"
    static func toGo(_ remaining: TimeInterval) -> String { String(localized: "\(clockUp(seconds: remaining)) to go") }

    /// "Done for today"
    static var doneForToday: String { String(localized: "Done for today") }

    /// "25 m extra today"
    static func extraToday(_ extra: TimeInterval) -> String { String(localized: "\(clock(seconds: extra)) extra today") }

    /// Whole minutes beyond today's stretch: 0 until a full minute over (30 s over is still just "done").
    static func extraMinutes(target: TimeInterval, done: TimeInterval) -> Int { max(0, Int((done - target) / 60)) }

    /// The quiet line once the stretch is covered: "Done for today", or "25 m extra today".
    static func covered(target: TimeInterval, done: TimeInterval) -> String {
        let extra = extraMinutes(target: target, done: done)
        return extra > 0 ? extraToday(TimeInterval(extra * 60)) : doneForToday
    }

    /// The line under Today's number for any state ("" with no target).
    static func quietLine(_ state: StretchState) -> String {
        switch state {
        case .inProgress(let target, let done): toGo(target - done)
        case .covered(let target, let done): covered(target: target, done: done)
        case .noTarget: ""
        }
    }

    /// The iPad Today card: "1 h 05 of 1 h 45 · 40 m to go", "1 h 45 of 1 h 45 · Done for today" or
    /// "2 h 10 of 1 h 45 · 25 m extra today".
    static func cardLine(_ state: StretchState) -> String {
        guard let target = state.target else { return "" }
        return "\(clock(seconds: state.done)) of \(clock(seconds: target)) · \(quietLine(state))"
    }

    /// "1 hour 5 minutes" (spoken), whole minutes.
    static func spoken(seconds: TimeInterval) -> String { Labels.spoken(seconds: Int(max(0, seconds) / 60) * 60, includeSeconds: false) }
    static func spokenUp(seconds: TimeInterval) -> String {
        Labels.spoken(seconds: Int((max(0, seconds) / 60).rounded(.up)) * 60, includeSeconds: false)
    }

    /// What VoiceOver reads for the whole picture: the label and value of `SunSpeech.today` in one sentence pair.
    static func description(_ state: StretchState) -> String {
        let spoken = SunSpeech.today(state)
        return spoken.value.isEmpty ? spoken.label : "\(spoken.label) \(spoken.value)"
    }
}
