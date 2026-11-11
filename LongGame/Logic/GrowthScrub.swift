import Foundation

// Scrub the forecast: the Growth chart opens full screen and a finger can be dragged along the line, from the first
// hour to the finish. Pure functions for the milestones, the curve and the crossings, so they can be tested.

/// One of the milestones on the line: 1,000 · 2,500 · 5,000 · 7,500 · 10,000 hours.
struct ScrubMilestone: Equatable, Sendable {
    var hours: Double
    var date: Date
    /// True once the running total got there (the date is real, or an estimate from before tracking began).
    var isReached: Bool
    /// Reached within the onboarding estimate, so the date is only about right.
    var isEstimate: Bool

    var isFinish: Bool { hours >= Totals.goalHours }
}

/// A point on the line: the past (played) or the forecast (if you keep your pace).
struct ScrubPoint: Equatable, Sendable {
    var date: Date
    var hours: Double
    var isFuture: Bool
    /// In the part of the past that comes from the onboarding estimate.
    var isEstimate: Bool
}

enum GrowthScrub {
    static let milestoneHours: [Double] = [1_000, 2_500, 5_000, 7_500, 10_000]

    // MARK: Milestones

    /// Each milestone with its date: the day the running total first reached it (an estimate when that was within
    /// the onboarding estimate), or the forecast month when it is still ahead. A milestone the forecast does not
    /// reach within 30 years is left out, so nothing is shown beyond it.
    static func milestoneDates(past: [CumulativePoint], forecast: ScenarioResult, onboardingDate: Date,
                               now: Date) -> [ScrubMilestone] {
        milestoneHours.compactMap { hours in
            if let reached = reachedDate(hours, past: past, onboardingDate: onboardingDate) {
                return ScrubMilestone(hours: hours, date: reached.date, isReached: true, isEstimate: reached.estimate)
            }
            guard let months = monthsToReach(hours, in: forecast) else { return nil }
            return ScrubMilestone(hours: hours, date: ForecastEngine.date(afterMonths: months, from: now),
                                  isReached: false, isEstimate: false)
        }
    }

    private static func reachedDate(_ hours: Double, past: [CumulativePoint], onboardingDate: Date) -> (date: Date, estimate: Bool)? {
        guard let i = past.firstIndex(where: { $0.hours >= hours }) else { return nil }
        let point = past[i]
        guard i > 0 else { return (point.date, point.date <= onboardingDate) }
        let before = past[i - 1]
        // The estimate grows steadily through each year, so a milestone inside it is placed along that slope;
        // a logged one is the day of the session that took the total over.
        if point.date <= onboardingDate, point.hours > before.hours {
            let share = (hours - before.hours) / (point.hours - before.hours)
            let t = before.date.timeIntervalSince1970 + share * (point.date.timeIntervalSince1970 - before.date.timeIntervalSince1970)
            return (Date(timeIntervalSince1970: t), true)
        }
        return (point.date, false)
    }

    private static func monthsToReach(_ hours: Double, in forecast: ScenarioResult) -> Double? {
        if hours >= Totals.goalHours { return forecast.monthsToGoal }
        guard let i = forecast.points.firstIndex(where: { $0.hours >= hours }) else { return nil }
        guard i > 0 else { return forecast.points[0].monthsFromNow }
        let a = forecast.points[i - 1], b = forecast.points[i]
        guard b.hours > a.hours else { return b.monthsFromNow }
        return a.monthsFromNow + (b.monthsFromNow - a.monthsFromNow) * (hours - a.hours) / (b.hours - a.hours)
    }

    // MARK: The curve

    /// The first and last day that can be scrubbed: the start of the past line to the end of the forecast (the
    /// finish, or the 30-year horizon when the finish is further away).
    static func range(past: [CumulativePoint], forecast: ScenarioResult, now: Date) -> ClosedRange<Date> {
        let start = past.first?.date ?? now
        let months = forecast.monthsToGoal ?? forecast.points.last?.monthsFromNow ?? 0
        return start...max(now, ForecastEngine.date(afterMonths: months, from: now))
    }

    /// The hours at any date, on the past line (day by day, as drawn) or on the forecast, for snapping the scrub
    /// dot to the curve. Dates outside the line are held at its first or last point.
    static func curvePoint(at date: Date, past: [CumulativePoint], forecast: ScenarioResult, onboardingDate: Date,
                           now: Date) -> ScrubPoint {
        let span = range(past: past, forecast: forecast, now: now)
        let d = min(max(date, span.lowerBound), span.upperBound)
        if d <= now {
            return ScrubPoint(date: d, hours: interpolate(past.map { ($0.date, $0.hours) }, at: d),
                              isFuture: false, isEstimate: d < onboardingDate)
        }
        let future = forecast.points.map { (ForecastEngine.date(afterMonths: $0.monthsFromNow, from: now), $0.hours) }
        return ScrubPoint(date: d, hours: interpolate(future, at: d), isFuture: true, isEstimate: false)
    }

    private static func interpolate(_ points: [(Date, Double)], at date: Date) -> Double {
        guard let first = points.first else { return 0 }
        guard let upper = points.firstIndex(where: { $0.0 >= date }) else { return points.last?.1 ?? first.1 }
        if upper == 0 { return first.1 }
        let a = points[upper - 1], b = points[upper]
        let span = b.0.timeIntervalSince(a.0)
        guard span > 0 else { return b.1 }
        return a.1 + (b.1 - a.1) * date.timeIntervalSince(a.0) / span
    }

    // MARK: Crossings

    /// The index of the milestone that lies between two scrub positions, in either direction: not the one the
    /// finger is leaving, but the one it arrives on or passes. When several are passed, the one nearest the new
    /// position. Today is a milestone like any other when one falls exactly on it.
    static func crossedMilestone(from: Date, to: Date, milestones: [ScrubMilestone]) -> Int? {
        guard from != to else { return nil }
        let goingRight = to > from
        let lo = min(from, to), hi = max(from, to)
        let hits = milestones.indices.filter { i in
            let d = milestones[i].date
            return goingRight ? (d > lo && d <= hi) : (d >= lo && d < hi)
        }
        return goingRight ? hits.last : hits.first
    }

    /// Whether Today lies between two positions (the same rule as for milestones).
    static func crossedToday(from: Date, to: Date, now: Date) -> Bool {
        guard from != to else { return false }
        return to > from ? (now > from && now <= to) : (now >= to && now < from)
    }

    // MARK: Following a finger

    /// What a scrub just did, for the haptics: a light tap for a milestone, a soft tick for Today and both ends.
    enum Event: Equatable, Sendable {
        case milestone(Int)
        case tick
    }

    /// Follows the finger and says when something happened. A milestone only taps once while the finger rests on it
    /// or stays close (`tolerance`); moving well away re-arms it.
    struct Tracker: Sendable {
        var milestones: [ScrubMilestone]
        var now: Date
        var range: ClosedRange<Date>
        /// How close counts as "still on it".
        var tolerance: TimeInterval
        private(set) var last: Date?
        /// The milestone the finger is on (or just passed and has not left), nil when none.
        private(set) var active: Int?

        init(milestones: [ScrubMilestone], now: Date, range: ClosedRange<Date>, tolerance: TimeInterval) {
            self.milestones = milestones
            self.now = now
            self.range = range
            self.tolerance = tolerance
        }

        mutating func move(to position: Date) -> Event? {
            let to = min(max(position, range.lowerBound), range.upperBound)
            defer { last = to }
            guard let from = last else { return nil }
            if let i = active, abs(milestones[i].date.timeIntervalSince(to)) > tolerance { active = nil }
            if let i = GrowthScrub.crossedMilestone(from: from, to: to, milestones: milestones) {
                if active == i { return nil }
                active = i
                return .milestone(i)
            }
            if GrowthScrub.crossedToday(from: from, to: to, now: now) { return .tick }
            if from != to, (to == range.lowerBound || to == range.upperBound) { return .tick }
            return nil
        }

        /// The finger lifted.
        mutating func end() {
            last = nil
            active = nil
        }

        /// The milestone the position is on (within the tolerance), for snapping the dot to it.
        func milestone(near position: Date) -> Int? {
            milestones.indices
                .filter { abs(milestones[$0].date.timeIntervalSince(position)) <= tolerance }
                .min { abs(milestones[$0].date.timeIntervalSince(position)) < abs(milestones[$1].date.timeIntervalSince(position)) }
        }
    }
}

// MARK: Draw-in

/// How much of each line is drawn while the full-screen chart opens: the past line first (0.8 s, ease-out), then the
/// dashed chosen-pace line (0.5 s), then the dotted actual-pace line (0.3 s), then the sun pops onto the finish.
struct DrawProgress: Equatable, Sendable {
    var past: Double
    var chosen: Double
    var actual: Double
    var sun: Bool

    static let complete = DrawProgress(past: 1, chosen: 1, actual: 1, sun: true)
    static let empty = DrawProgress(past: 0, chosen: 0, actual: 0, sun: false)

    static let pastDuration = 0.8
    static let chosenDuration = 0.5
    static let actualDuration = 0.3
    static var total: Double { pastDuration + chosenDuration + actualDuration }

    /// The progress `t` seconds after the chart opened.
    static func at(_ t: Double) -> DrawProgress {
        func phase(_ start: Double, _ length: Double) -> Double { min(1, max(0, (t - start) / length)) }
        func easeOut(_ x: Double) -> Double { 1 - (1 - x) * (1 - x) }
        func easeInOut(_ x: Double) -> Double { x < 0.5 ? 2 * x * x : 1 - pow(-2 * x + 2, 2) / 2 }
        return DrawProgress(past: easeOut(phase(0, pastDuration)),
                            chosen: easeInOut(phase(pastDuration, chosenDuration)),
                            actual: easeInOut(phase(pastDuration + chosenDuration, actualDuration)),
                            sun: t >= total)
    }
}

enum LineDraw {
    /// The first part of a straight line, `fraction` of the way along it (points are in order).
    static func partial(_ points: [CumulativePoint], fraction: Double) -> [CumulativePoint] {
        guard points.count >= 2 else { return fraction > 0 ? points : [] }
        guard fraction > 0 else { return [] }
        guard fraction < 1, let first = points.first, let last = points.last else { return points }
        let span = last.date.timeIntervalSince(first.date)
        let cutoff = first.date.addingTimeInterval(span * fraction)
        var out = points.filter { $0.date < cutoff }
        let hours: Double
        if let before = out.last, let after = points.first(where: { $0.date >= cutoff }), after.date > before.date {
            hours = before.hours + (after.hours - before.hours) * cutoff.timeIntervalSince(before.date) / after.date.timeIntervalSince(before.date)
        } else {
            hours = last.hours
        }
        out.append(CumulativePoint(date: cutoff, hours: hours))
        return out
    }
}

// MARK: Words

/// The texts of the scrub: the headline block and the floating label.
struct ScrubReadout: Equatable {
    /// "Played" or "At your chosen pace".
    var small: String
    /// "14 Sep 2022 · 1,000 h" (day precision) or "Feb 2029 · 5,000 h" (month precision).
    var big: String
    /// "Milestone reached", "Milestone · halfway", "Milestone · 7,500 h", "The finish line", or nothing.
    var accent: String
    /// The chip in the floating label: "Played" or "Forecast".
    var chip: String
    /// The short line in the floating label.
    var blurb: String
    var date: String
    var hours: String

    /// Said by VoiceOver for a stop on the line.
    var spoken: String { [small, big, accent].filter { !$0.isEmpty }.joined(separator: ". ") }
}

enum ScrubText {
    private static func formatter(_ template: String, calendar: Calendar, locale: Locale) -> DateFormatter {
        CachedFormatter.template(template, calendar: calendar, locale: locale)
    }

    static func day(_ date: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        formatter("dMMMyyyy", calendar: calendar, locale: locale).string(from: date)
    }

    static func month(_ date: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        formatter("MMMyyyy", calendar: calendar, locale: locale).string(from: date)
    }

    static func hours(_ value: Double, locale: Locale = .current) -> String {
        Int(max(0, value).rounded(.down)).formatted(.number.grouping(.automatic).locale(locale)) + " h"
    }

    /// The headline and label for a point on the line. `milestone` is the milestone the dot is snapped to, if any.
    static func readout(for point: ScrubPoint, milestone: ScrubMilestone?, calendar: Calendar = .current,
                        locale: Locale = .current) -> ScrubReadout {
        let amount = milestone.map { hours($0.hours, locale: locale) } ?? hours(point.hours, locale: locale)
        let date = point.isFuture || point.isEstimate ? month(point.date, calendar: calendar, locale: locale)
                                                     : day(point.date, calendar: calendar, locale: locale)
        // A date inside the estimate is only about right.
        let shownDate = (!point.isFuture && point.isEstimate) ? String(localized: "about \(date)") : date
        let small = point.isFuture ? String(localized: "At your chosen pace") : String(localized: "Played")
        let chip = point.isFuture ? String(localized: "Forecast") : String(localized: "Played")

        var accent = ""
        var blurb = ""
        if let milestone {
            let label = hours(milestone.hours, locale: locale)
            if milestone.isFinish {
                accent = String(localized: "The finish line")
                blurb = milestone.isReached ? String(localized: "Reached 10,000 hours") : String(localized: "The finish line.")
            } else if milestone.isReached {
                accent = milestone.isEstimate ? String(localized: "Milestone reached · estimate") : String(localized: "Milestone reached")
                blurb = String(localized: "Reached \(label.replacingOccurrences(of: " h", with: "")) hours")
            } else {
                accent = milestone.hours == 5_000 ? String(localized: "Milestone · halfway") : String(localized: "Milestone · \(label)")
                blurb = ahead(milestone.hours)
            }
        } else if !point.isFuture && point.isEstimate {
            accent = String(localized: "Estimate")
        }
        return ScrubReadout(small: small, big: "\(shownDate) · \(amount)", accent: accent, chip: chip, blurb: blurb,
                            date: shownDate, hours: amount)
    }

    /// The short line for a milestone that is still ahead.
    private static func ahead(_ hours: Double) -> String {
        switch hours {
        case 1_000: String(localized: "The first thousand.")
        case 2_500: String(localized: "A quarter of the way.")
        case 5_000: String(localized: "Halfway. The sun's at its height.")
        case 7_500: String(localized: "Three quarters of the way.")
        default: ""
        }
    }

    /// The stops VoiceOver steps through: Start, each milestone, Today, the finish line, in date order.
    enum Stop: Equatable {
        case start
        case milestone(Int)
        case today
        case end
    }

    static func stops(milestones: [ScrubMilestone], range: ClosedRange<Date>, now: Date) -> [(stop: Stop, date: Date)] {
        var all: [(stop: Stop, date: Date)] = [(.start, range.lowerBound)]
        all += milestones.enumerated().map { (Stop.milestone($0.offset), $0.element.date) }
        all.append((.today, now))
        // The finish line is the 10,000 milestone when there is one; otherwise the end of the line.
        if !milestones.contains(where: \.isFinish) { all.append((.end, range.upperBound)) }
        return all.sorted { $0.date < $1.date }
    }
}
