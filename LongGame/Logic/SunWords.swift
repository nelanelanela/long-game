import Foundation

// The sun described in words, for VoiceOver (spec section 20). Everything here is plain text from plain numbers,
// so it can be tested without drawing anything.

/// Where the sun is, as a short phrase ("just over halfway", "a third of the way", "almost there").
struct SunPhrase: Equatable, Sendable {
    enum Step: Equatable, Sendable {
        case horizon, rising, quarter, third, half, twoThirds, threeQuarters, almostThere, there
    }
    /// How close the sun is to the step: on it, a little past it, a little short of it, or only roughly there.
    enum Qualifier: Equatable, Sendable {
        case none, justOver, justUnder, about
    }

    var step: Step
    var qualifier: Qualifier = .none

    /// True for the steps that read "<words> to <destination>" (a quarter of the way to…, halfway to…).
    var isPositional: Bool {
        switch step {
        case .quarter, .third, .half, .twoThirds, .threeQuarters: true
        default: false
        }
    }

    /// "just over halfway", "a third of the way", "on the horizon", "just rising", "almost there", "there".
    var words: String {
        let base: String
        switch step {
        case .horizon: return String(localized: "on the horizon")
        case .rising: return String(localized: "just rising")
        case .almostThere: return String(localized: "almost there")
        case .there: return String(localized: "there")
        case .quarter: base = String(localized: "a quarter of the way")
        case .third: base = String(localized: "a third of the way")
        case .half: base = String(localized: "halfway")
        case .twoThirds: base = String(localized: "two thirds of the way")
        case .threeQuarters: base = String(localized: "three quarters of the way")
        }
        switch qualifier {
        case .none: return base
        case .justOver: return String(localized: "just over \(base)")
        case .justUnder: return String(localized: "just under \(base)")
        case .about: return String(localized: "about \(base)")
        }
    }

    /// "The sun is just over halfway to your weekly target."
    func sentence(to destination: String) -> String {
        switch step {
        case .horizon: String(localized: "The sun is on the horizon.")
        case .rising: String(localized: "The sun is just rising.")
        case .almostThere: String(localized: "The sun is almost at \(destination).")
        case .there: String(localized: "The sun has reached \(destination).")
        default: String(localized: "The sun is \(words) to \(destination).")
        }
    }
}

/// The words for a fraction `p` of the way: 0 is the horizon, under 0.15 just rising, then the nearest of a quarter,
/// a third, halfway, two thirds and three quarters, from 0.9 almost there, and 1 or more there. Within 0.05 of a step
/// but not on it (0.01 or less counts as on it) it is "just over" or "just under"; further from every step, "about".
func sunPositionWords(fraction: Double) -> SunPhrase {
    let p = fraction.isNaN ? 0 : fraction
    let tolerance = 1e-9
    if p <= 0 { return SunPhrase(step: .horizon) }
    if p >= 1 - tolerance { return SunPhrase(step: .there) }
    if p >= 0.9 - tolerance { return SunPhrase(step: .almostThere) }
    if p < 0.15 { return SunPhrase(step: .rising) }

    let steps: [(Double, SunPhrase.Step)] = [(0.25, .quarter), (0.33, .third), (0.5, .half), (0.67, .twoThirds), (0.75, .threeQuarters)]
    let nearest = steps.min { abs(p - $0.0) < abs(p - $1.0) }!
    let gap = p - nearest.0
    let qualifier: SunPhrase.Qualifier
    if abs(gap) <= 0.01 + tolerance { qualifier = .none }
    else if abs(gap) <= 0.05 + tolerance { qualifier = gap > 0 ? .justOver : .justUnder }
    else { qualifier = .about }
    return SunPhrase(step: nearest.1, qualifier: qualifier)
}

/// What VoiceOver says for a sun gauge: the `label` leads with the sun's place in words, the `value` carries the
/// numbers (and changes without moving focus).
struct SpokenGauge: Equatable, Sendable {
    var label: String
    var value: String
    var text: String { value.isEmpty ? label : label + " " + value }
}

enum SunSpeech {
    /// "6.5", "12", "1": no decimals when whole.
    private static func number(_ hours: Double) -> String { WeeklyTarget.number(hours) }

    /// "hour" for exactly 1, otherwise "hours".
    private static func unit(_ hours: Double) -> String {
        number(hours) == "1" ? String(localized: "hour") : String(localized: "hours")
    }

    // MARK: Home

    /// This week. "The sun is just over halfway to your weekly target." / "6.5 of 12 hours, 5.5 to go, 3 days left."
    /// Above the target: "The sun is above your weekly target." / "13.5 of 12 hours."
    static func week(hours: Double, target: Double, daysLeft: Int) -> SpokenGauge {
        let target = max(0.5, target)
        let hours = max(0, hours)
        let shown = number(hours), goal = number(target), unit = unit(target)
        if hours > target + 0.0001 {
            return SpokenGauge(label: String(localized: "The sun is above your weekly target."),
                               value: String(localized: "\(shown) of \(goal) \(unit)."))
        }
        let label = sunPositionWords(fraction: hours / target).sentence(to: String(localized: "your weekly target"))
        if hours >= target - 0.0001 {
            return SpokenGauge(label: label, value: String(localized: "\(shown) of \(goal) \(unit)."))
        }
        let togo = number(target - hours)
        let left = daysLeft <= 0 ? String(localized: "last day of the week") : String(localized: "\(Labels.days(daysLeft)) left")
        return SpokenGauge(label: label, value: String(localized: "\(shown) of \(goal) \(unit), \(togo) to go, \(left)."))
    }

    /// The long game. "The sun is a third of the way to the finish line." / "3,294 of 10,000 hours. At your pace, around
    /// November 2035." `pace` is that last sentence, or nil.
    static func longGame(total: Double, pace: String?) -> SpokenGauge {
        let whole = Totals.wholeHours(total: total)
        let label = sunPositionWords(fraction: total / Totals.goalHours).sentence(to: String(localized: "the finish line"))
        let shown = DurationFormat.grouped(whole), goal = DurationFormat.grouped(Int(Totals.goalHours))
        var value = String(localized: "\(shown) of \(goal) hours.")
        if let pace, whole < Int(Totals.goalHours) { value += " " + pace }
        return SpokenGauge(label: label, value: value)
    }

    /// "At your pace, around November 2035." or, when it is further away than the forecast looks, "At your pace, after 2051."
    static func pace(_ result: ScenarioResult, now: Date, calendar: Calendar = .current) -> String {
        if result.monthsToGoal == nil {
            return String(localized: "At your pace, after \(calendar.component(.year, from: now) + ForecastEngine.horizonYears).")
        }
        return String(localized: "At your pace, around \(ForecastText.headline(result, now: now, calendar: calendar)).")
    }

    /// Today. "The sun is almost two thirds of the way to today's resting place." / "1 hour 5 minutes of 1 hour 45 minutes,
    /// 40 minutes to go." Rest day: "Rest day. The sun is resting on the horizon."
    static func today(_ state: StretchState) -> SpokenGauge {
        switch state {
        case .stretch(let target, let done):
            let label = sunPositionWords(fraction: state.fraction).sentence(to: String(localized: "today's resting place"))
            return SpokenGauge(label: label, value: String(localized: "\(StretchText.spoken(seconds: done)) of \(StretchText.spoken(seconds: target)), \(StretchText.spokenUp(seconds: target - done)) to go."))
        case .covered(let target, let done):
            return SpokenGauge(label: String(localized: "Today's stretch is covered. The sun has reached today's resting place."),
                               value: String(localized: "\(StretchText.spoken(seconds: done)) of \(StretchText.spoken(seconds: target)). Anything more is a bonus."))
        case .weekCovered(let done):
            return SpokenGauge(label: String(localized: "This week is covered. The sun is at the top."),
                               value: String(localized: "Today: \(StretchText.spoken(seconds: done)). Anything more is a bonus."))
        case .restDay(let done):
            return SpokenGauge(label: String(localized: "Rest day. The sun is resting on the horizon."),
                               value: done > 0 ? String(localized: "Played anyway: \(StretchText.spoken(seconds: done)).") : "")
        case .noTarget:
            return SpokenGauge(label: String(localized: "No weekly target yet."), value: "")
        }
    }

    // MARK: Timer

    /// "Session 25 minutes. 5 of 12 rays lit, next ray in 2 minutes 42 seconds. Total 3,294.7 hours."
    static func timer(elapsed: TimeInterval, total: Double) -> String {
        let sun = SunHour(elapsed: elapsed)
        let session = Labels.spoken(seconds: Int(max(0, elapsed)), includeSeconds: elapsed < 60)
        let next = Labels.spoken(seconds: Int(sun.secondsToNextRay.rounded(.up)), includeSeconds: true)
        let hours = DurationFormat.totalHours(total)
        return String(localized: "Session \(session). \(sun.litRays) of 12 rays lit, next ray in \(next). Total \(hours) hours.")
    }

    /// The quiet announcement when a ray lights: "Ray 6 lit". At the full hour: "Golden hour, all 12 rays lit".
    static func rayLit(_ sun: SunHour) -> String {
        sun.litRays == 0 ? String(localized: "Golden hour, all 12 rays lit") : String(localized: "Ray \(sun.litRays) lit")
    }

    // MARK: Calendar

    /// rest day / a little / some / a good day / a full day
    static func words(for level: CalendarLevel) -> String {
        switch level {
        case .rest: String(localized: "rest day")
        case .under1: String(localized: "a little")
        case .from1to2: String(localized: "some")
        case .from2to3: String(localized: "a good day")
        case .over3: String(localized: "a full day")
        }
    }

    /// "Thursday 22 October. 2 hours, a good day. Has a photo." A rest day: "Thursday 22 October. Rest day."
    static func calendarDay(date: String, seconds: Double, hasPhoto: Bool) -> String {
        let level = CalendarLevel.level(hours: seconds / 3600)
        var text: String
        if level == .rest {
            text = String(localized: "\(date). Rest day.")
        } else {
            let duration = Labels.spoken(seconds: Int((seconds / 60).rounded()) * 60, includeSeconds: false)
            text = String(localized: "\(date). \(duration), \(words(for: level)).")
        }
        if hasPhoto { text += " " + String(localized: "Has a photo.") }
        return text
    }
}
