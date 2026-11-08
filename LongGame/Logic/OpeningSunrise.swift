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
    /// The whole sunrise, about 0.8 s.
    case full
    /// A 0.3 s cross-fade from the night frame to the app.
    case short
    /// Dark mode: the sunrise stops at dusk and cross-fades into the app.
    case dusk

    /// How long it runs, in seconds.
    var duration: Double {
        switch self {
        case .skip: 0
        case .full, .dusk: OpeningTimeline.total
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

/// Decides which opening plays. Only a cold start from the icon plays one at all; a running session, Reduce Motion
/// and VoiceOver get the short fade; dark mode stops the sunrise at dusk. Before onboarding it ends on Welcome.
func openingStyle(coldStart: Bool, openedFrom: OpeningSource, sessionRunning: Bool, reduceMotion: Bool,
                  voiceOver: Bool, onboarded: Bool, dark: Bool) -> OpeningPlan {
    let landing: OpeningLanding = onboarded ? .home : .welcome
    guard coldStart, openedFrom == .icon else { return OpeningPlan(style: .skip, landing: landing) }
    if sessionRunning || reduceMotion || voiceOver { return OpeningPlan(style: .short, landing: landing) }
    return OpeningPlan(style: dark ? .dusk : .full, landing: landing)
}

/// One moment of the opening. Everything is a number from 0 to 1 that the view turns into colours and positions.
struct OpeningFrame: Equatable, Sendable {
    /// 0 night, 0.5 dusk, 1 morning: the sky, the sea and the sun's height all follow it.
    var sky: Double
    var stars: Double
    /// How far the rays have unfolded (scale 0 → 1), and the glow behind the sun.
    var rays: Double
    var glow: Double
    /// The sun has opened its eyes and smiles.
    var awake: Bool
    /// 0 = sun in its morning place, 1 = on Today's arc on Home.
    var glide: Double
    /// How opaque the sky and sea are (they fade out as Home fades in).
    var scenery: Double
    /// How opaque the sun is.
    var sun: Double
}

enum OpeningTimeline {
    static let sunrise = 0.6
    static let total = 0.8
    static let shortTotal = 0.3

    static func clamp(_ x: Double) -> Double { min(1, max(0, x)) }
    static func ease(_ x: Double) -> Double { let c = clamp(x); return c * c * (3 - 2 * c) }

    /// The frame at `t` seconds. `hasTarget` is false when there is no sun on screen to glide to (Welcome).
    static func frame(at t: Double, style: OpeningStyle, hasTarget: Bool = true) -> OpeningFrame {
        let night = OpeningFrame(sky: 0, stars: 1, rays: 0, glow: 0, awake: false, glide: 0, scenery: 1, sun: 1)
        switch style {
        case .skip:
            return OpeningFrame(sky: 0, stars: 0, rays: 0, glow: 0, awake: false, glide: 1, scenery: 0, sun: 0)
        case .short:
            var f = night
            f.scenery = 1 - ease(t / shortTotal)
            f.sun = f.scenery
            return f
        case .full, .dusk:
            let p = ease(t / sunrise)
            let g = ease((t - sunrise) / (total - sunrise))
            var f = night
            let reach = style == .dusk ? 0.5 : 1.0
            f.sky = p * reach
            f.stars = 1 - f.sky * (style == .dusk ? 1.2 : 1)
            f.rays = style == .dusk ? 0 : p
            f.glow = style == .dusk ? 0 : p
            f.awake = style == .full && t >= sunrise
            f.scenery = 1 - g
            f.glide = style == .full && hasTarget ? g : 0
            f.sun = style == .full && hasTarget ? 1 : 1 - g
            f.stars = clamp(f.stars)
            return f
        }
    }
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
