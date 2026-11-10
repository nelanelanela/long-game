import Foundation

// The opening sunrise (spec section 21): which version plays, and where everything is at each moment.
// Pure functions, no SwiftUI, so every case can be tested.

/// How the app was opened.
enum OpeningSource: Equatable, Sendable {
    case icon, widget, liveActivity, notification, url
}

/// Which version of the opening plays.
enum OpeningStyle: Equatable, Sendable {
    /// Nothing at all: straight to the app.
    case skip
    /// The whole sunrise, about 1 s.
    case full
    /// A 0.3 s cross-fade from the night frame to the app.
    case short

    /// How long it runs, in seconds.
    var duration: Double {
        switch self {
        case .skip: 0
        case .full: OpeningTimeline.total
        case .short: OpeningTimeline.shortTotal
        }
    }
}

/// Where the opening ends: on Home, or on Welcome before onboarding.
enum OpeningLanding: Equatable, Sendable {
    case home, welcome
}

struct OpeningPlan: Equatable, Sendable {
    var style: OpeningStyle
    var landing: OpeningLanding
}

/// Decides which opening plays. Only a cold start from the icon plays one at all; Reduce Motion and VoiceOver get the
/// short fade; everyone else sees the whole sunrise, a running session and dark mode included (the Launch board makes no
/// exception for them, and the sunrise is only a second). Before onboarding it ends on Welcome.
func openingStyle(coldStart: Bool, openedFrom: OpeningSource, sessionRunning: Bool, reduceMotion: Bool,
                  voiceOver: Bool, onboarded: Bool) -> OpeningPlan {
    let landing: OpeningLanding = onboarded ? .home : .welcome
    guard coldStart, openedFrom == .icon else { return OpeningPlan(style: .skip, landing: landing) }
    if reduceMotion || voiceOver { return OpeningPlan(style: .short, landing: landing) }
    return OpeningPlan(style: .full, landing: landing)
}

/// One moment of the opening. Everything is a number from 0 to 1 that the view turns into opacities and positions.
struct OpeningFrame: Equatable, Sendable {
    /// 0 night, 1 dawn: how far the night sky and night land have faded to reveal the dawn sky and day land.
    var sky: Double
    /// How far the sun has risen from the shoreline to its morning spot (120 pt above it on an 844 pt screen).
    var rise: Double
    /// 0 = the sleeping sun (faint rays, closed eyes, "z"), 1 = the happy sun with all its rays lit.
    var awake: Double
    /// 0...1: the happy sun's eyes wide open for a moment ("Good morning").
    var eyesOpen: Double
    /// 0 = sun in its morning place, 1 = on Today's arc on Home (its size follows).
    var glide: Double
    /// How opaque the whole scene is, sun included; it fades out as Home shows underneath.
    var scenery: Double
}

/// The timings of `design/redesign/Launch.dc.html`. The board plays it as a 7 s loop (night held 0-20%, home held
/// 72-92%); its note gives the app's real times: sunrise 0-0.5 s, good morning 0.5-0.65 s, settle 0.65-1 s.
/// Each keyframe of the board maps onto those three phases:
///
/// | Board  | App      | What happens                                                         |
/// | ------ | -------- | -------------------------------------------------------------------- |
/// | 20-50% | 0-0.5 s  | night sky and land fade to dawn; the sun rises 120 pt                |
/// | 35-45% | 0.25-0.42| the sleeping sun becomes the happy sun (its rays light up)           |
/// | 50-52% | 0.5-0.54 | its eyes open...                                                     |
/// | 56-58% | 0.61-0.65| ...and close again                                                   |
/// | 58-72% | 0.65-1 s | it glides and shrinks onto Today's arc                               |
/// | 62-72% | 0.75-1 s | the scenery fades and Home shows underneath                          |
enum OpeningTimeline {
    static let sunrise = 0.5
    static let glideStart = 0.65
    static let total = 1.0
    static let shortTotal = 0.3

    /// Board percentage → app seconds, piecewise along the three phases.
    static func boardTime(_ percent: Double) -> Double {
        switch percent {
        case ..<50: (percent - 20) / 30 * sunrise
        case ..<58: sunrise + (percent - 50) / 8 * (glideStart - sunrise)
        default: glideStart + (percent - 58) / 14 * (total - glideStart)
        }
    }

    static let wakeStart = boardTime(35), wakeEnd = boardTime(45)
    static let eyesOpenStart = boardTime(50), eyesOpenEnd = boardTime(52)
    static let eyesCloseStart = boardTime(56), eyesCloseEnd = boardTime(58)
    static let homeStart = boardTime(62)

    static func clamp(_ x: Double) -> Double { min(1, max(0, x)) }
    /// Progress through [a, b] at `t`, clamped to 0...1.
    static func progress(_ t: Double, _ a: Double, _ b: Double) -> Double { clamp((t - a) / (b - a)) }
    /// CSS `ease-in-out`, used for every fade on the board.
    static func easeInOut(_ x: Double) -> Double { cubicBezier(clamp(x), 0.42, 0, 0.58, 1) }
    /// The board's motion curve for the sun, `cubic-bezier(.45,0,.25,1)`.
    static func sunEase(_ x: Double) -> Double { cubicBezier(clamp(x), 0.45, 0, 0.25, 1) }

    /// The frame at `t` seconds. `hasTarget` is false when there is no sun on screen to glide to (Welcome).
    static func frame(at t: Double, style: OpeningStyle, hasTarget: Bool = true) -> OpeningFrame {
        let night = OpeningFrame(sky: 0, rise: 0, awake: 0, eyesOpen: 0, glide: 0, scenery: 1)
        switch style {
        case .skip:
            return OpeningFrame(sky: 0, rise: 0, awake: 0, eyesOpen: 0, glide: 1, scenery: 0)
        case .short:
            var f = night
            f.scenery = 1 - easeInOut(t / shortTotal)
            return f
        case .full:
            var f = night
            f.sky = easeInOut(progress(t, 0, sunrise))
            f.rise = sunEase(progress(t, 0, sunrise))
            f.awake = easeInOut(progress(t, wakeStart, wakeEnd))
            f.eyesOpen = t < eyesCloseStart ? easeInOut(progress(t, eyesOpenStart, eyesOpenEnd))
                                            : 1 - easeInOut(progress(t, eyesCloseStart, eyesCloseEnd))
            f.glide = hasTarget ? sunEase(progress(t, glideStart, total)) : 0
            f.scenery = 1 - easeInOut(progress(t, homeStart, total))
            return f
        }
    }
}

/// A CSS `cubic-bezier(x1, y1, x2, y2)` timing curve: the y for a given x (time), both 0...1.
func cubicBezier(_ x: Double, _ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) -> Double {
    func bez(_ s: Double, _ a: Double, _ b: Double) -> Double {
        let u = 1 - s
        return 3 * u * u * s * a + 3 * u * s * s * b + s * s * s
    }
    if x <= 0 { return 0 }
    if x >= 1 { return 1 }
    // x(s) is increasing for valid CSS curves, so bisection always finds s.
    var lo = 0.0, hi = 1.0, s = x
    for _ in 0..<40 {
        s = (lo + hi) / 2
        if bez(s, x1, x2) < x { lo = s } else { hi = s }
    }
    return bez(s, y1, y2)
}

/// Mixes two #RRGGBB colours (in sRGB), `t` from 0 to 1.
func mixHex(_ a: UInt32, _ b: UInt32, _ t: Double) -> UInt32 {
    let k = OpeningTimeline.clamp(t)
    func channel(_ shift: UInt32) -> UInt32 {
        let x = Double((a >> shift) & 0xFF), y = Double((b >> shift) & 0xFF)
        return UInt32((x + (y - x) * k).rounded())
    }
    return channel(16) << 16 | channel(8) << 8 | channel(0)
}

/// A colour that passes through three anchors (night, dusk, morning) as `sky` goes 0 → 0.5 → 1.
func openingMix(_ night: UInt32, _ dusk: UInt32, _ morning: UInt32, sky: Double) -> UInt32 {
    sky < 0.5 ? mixHex(night, dusk, sky * 2) : mixHex(dusk, morning, (sky - 0.5) * 2)
}
