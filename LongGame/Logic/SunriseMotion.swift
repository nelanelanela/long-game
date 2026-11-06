import Foundation
import CoreGraphics

/// Timings for the sunrise hero (Home, the intro pages and the "Meet your future self" sheet), taken from the
/// spec's animation table and the CSS keyframes in `design/Home.dc.html`. Everything is a pure function of the
/// clock, so the hero can be frozen at any moment for previews and tests.
enum SunriseMotion {
    /// One wave is two arches (up, then down), 40 pt long. Moving by exactly one wavelength loops seamlessly.
    /// (The design file moves by 20 px, half a wavelength, which would jump at the loop point.)
    static let wavelength: CGFloat = 40
    static let waveRightPeriod: TimeInterval = 3.2
    static let waveLeftPeriod: TimeInterval = 5
    static let breathePeriod: TimeInterval = 4
    static let turnPeriod: TimeInterval = 90
    static let peekPeriod: TimeInterval = 7
    static let riseDuration: TimeInterval = 1.6
    static let riseDistance: CGFloat = 34

    private static func fraction(_ x: Double) -> Double { x - x.rounded(.down) }
    private static func smooth(_ x: Double) -> Double { x * x * (3 - 2 * x) }

    /// Navy wave and the sea fill: drift right.
    static func wavePhaseRight(_ t: TimeInterval) -> CGFloat {
        CGFloat(fraction(t / waveRightPeriod)) * wavelength
    }

    /// Pale wave: drifts left.
    static func wavePhaseLeft(_ t: TimeInterval) -> CGFloat {
        CGFloat(1 - fraction(t / waveLeftPeriod)) * wavelength
    }

    /// 0...1, ease-in-out: up 3 pt and 103% at 1.
    static func breathe(_ t: TimeInterval) -> Double {
        (1 - cos(2 * .pi * t / breathePeriod)) / 2
    }

    static func rotationDegrees(_ t: TimeInterval) -> Double {
        360 * fraction(t / turnPeriod)
    }

    /// 0...1: how far the sun's eyes are open. Every 7 s both eyes open for about 0.35 s, then close again.
    static func eyesOpen(_ t: TimeInterval) -> Double {
        let f = fraction(t / peekPeriod)
        let keys: [(at: Double, value: Double)] = [(0, 0), (0.88, 0), (0.90, 1), (0.95, 1), (1, 0)]
        for i in 1..<keys.count where f <= keys[i].at {
            let a = keys[i - 1], b = keys[i]
            let p = (f - a.at) / (b.at - a.at)
            return a.value + (b.value - a.value) * smooth(p)
        }
        return 0
    }

    /// The glow pulses with the breath: opacity .55 → .8 (as a share of its strength), scale 1 → 1.06.
    static func glowOpacity(_ t: TimeInterval) -> Double { 0.55 + 0.25 * breathe(t) }
    static func glowScale(_ t: TimeInterval) -> Double { 1 + 0.06 * breathe(t) }

    /// How far below its place on the horizon the sun still is, `seconds` after the sheet opened (1.6 s ease-out).
    static func rise(after seconds: TimeInterval) -> CGFloat {
        let p = min(1, max(0, seconds / riseDuration))
        return riseDistance * CGFloat(pow(1 - p, 4))
    }
}
