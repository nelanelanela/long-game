import Foundation

/// The app's haptic language: each moment names its meaning, and the meaning picks the pattern. The same feeling
/// always means the same thing, on the iPhone and the Watch. `Haptics` (DesignSystem) plays them.
enum HapticPattern: Int, Comparable, Sendable {
    case none
    /// The system selection feedback.
    case tick
    /// One light impact.
    case softTap
    /// Two light impacts, 0.12 s apart.
    case twoTaps
    /// Three impacts, each a little stronger (light, medium, rigid), over 0.3 s.
    case risingThree

    static func < (a: HapticPattern, b: HapticPattern) -> Bool { a.rawValue < b.rawValue }
}

enum HapticMoment: Equatable, Sendable {
    case rayLit, sessionSaved, timeAdded, undo, thanks, copied
    case stretchCovered
    case hourMilestone, weeklyPaceReached, tenThousand
    case stepper, crown, growthMilestone, tabSwitch, scrub
    case error, deleted, paused, stepperLimit

    var pattern: HapticPattern {
        switch self {
        case .rayLit, .sessionSaved, .timeAdded, .undo, .thanks, .copied: .softTap
        case .stretchCovered: .twoTaps
        case .hourMilestone, .weeklyPaceReached, .tenThousand: .risingThree
        case .stepper, .crown, .growthMilestone, .tabSwitch, .scrub: .tick
        case .error, .deleted, .paused, .stepperLimit: .none
        }
    }
}

enum HapticPlan {
    /// Never two at once: of moments that happen together, only the strongest plays.
    static func strongest(_ moments: [HapticMoment]) -> HapticPattern {
        moments.map(\.pattern).max() ?? .none
    }

    /// What a save plays: risingThree when it reaches an hour milestone or the weekly pace, twoTaps when it covers
    /// today's stretch, otherwise softTap. A milestone's own celebration plays it, so the save itself stays quiet then.
    static func save(timer: Bool, coversStretch: Bool, reachesMilestone: Bool, reachesWeeklyPace: Bool) -> [HapticMoment] {
        var moments: [HapticMoment] = [timer ? .sessionSaved : .timeAdded]
        if coversStretch { moments.append(.stretchCovered) }
        if reachesWeeklyPace { moments.append(.weeklyPaceReached) }
        if reachesMilestone { moments.append(.hourMilestone) }
        return moments
    }
}
