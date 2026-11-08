import Foundation
import CoreGraphics

// The Timer's sunrise (update prompt 32, part 6): one sunrise a day. During a session the sun's height follows
// TODAY's stretch, not the session: the first session of the day starts in the dark, a later one picks up where the
// day left off, and once the stretch is covered the sun stays fully up for the rest of the day.
// Numbers are from design/redesign/Timer.dc.html. Pure functions, so every case can be tested.

enum TimerSunrise {
    /// Without a weekly pace there is no stretch to measure against: an hour stands in for it.
    static let fallbackStretch: TimeInterval = 3600

    static func clamp(_ x: Double) -> Double { min(1, max(0, x)) }

    /// Today's progress, 0...1: (saved today + the running session) ÷ today's stretch.
    static func progress(doneSaved: TimeInterval, running: TimeInterval, target: TimeInterval?) -> Double {
        let stretch = (target ?? fallbackStretch)
        guard stretch > 0 else { return 0 }
        return clamp((max(0, doneSaved) + max(0, running)) / stretch)
    }

    /// Where the sun's centre sits: from the horizon at p = 0 up `rise` points at p = 1 (in the 844 pt board:
    /// horizon 470, rise 245). Pausing sinks it 24 pt.
    static func sunCentreY(p: Double, horizonY: CGFloat, rise: CGFloat, paused: Bool = false) -> CGFloat {
        horizonY - rise * CGFloat(clamp(p)) + (paused ? 24 : 0)
    }

    /// The horizon and the climb as fractions of the screen's height (470 and 245 of 844).
    static let horizonFraction: CGFloat = 470.0 / 844
    static let riseFraction: CGFloat = 245.0 / 844

    // MARK: Layers

    /// The night sky fades out over the first half of the climb.
    static func nightOpacity(p: Double) -> Double { clamp(1 - p / 0.5) }

    /// Dawn rises to full at p = 0.5, then fades out by p = 0.95.
    static func dawnOpacity(p: Double) -> Double { p < 0.5 ? clamp(p / 0.5) : clamp(1 - (p - 0.5) / 0.45) }

    /// The day sky fades in from p = 0.5 to 0.95.
    static func dayOpacity(p: Double) -> Double { clamp((p - 0.5) / 0.45) }

    /// The day land and the background-coloured fill fade in on top of the night land from p = 0.45 to 0.85.
    /// The night land and the navy fill underneath never fade: the sea is always opaque.
    static func landDayOpacity(p: Double) -> Double { clamp((p - 0.45) / 0.4) }

    /// 0 (white text) → 1 (navy text) between p = 0.55 and 0.85.
    static func lightness(p: Double) -> Double { clamp((p - 0.55) / 0.3) }

    /// The glow behind the sun: stronger as the day goes, much dimmer while paused.
    static func glowOpacity(p: Double, paused: Bool) -> Double { (0.35 + 0.65 * clamp(p)) * (paused ? 0.4 : 1) }

    // MARK: Colours

    static let white: UInt32 = 0xFFFFFF
    static let navy: UInt32 = 0x16244A
    static let goldStart: UInt32 = 0xFFD66B
    static let ember: UInt32 = 0xB4561A

    /// The text colour: white at night, navy by day.
    static func inkHex(p: Double) -> UInt32 { mixHex(white, navy, lightness(p: p)) }

    /// Today's big number: #FFD66B to ember.
    static func goldHex(p: Double) -> UInt32 { mixHex(goldStart, ember, lightness(p: p)) }

    /// The sky is saturation 0.55 and brightness 0.88 while paused.
    static let pausedSaturation = 0.55
    static let pausedBrightness = 0.88

    // MARK: Moments

    /// How long the celebrate face lasts when the stretch gets covered.
    static let celebrateSeconds: TimeInterval = 1.3

    /// The celebrate face is showing: the stretch got covered during this session, less than 1.3 s ago.
    static func isCelebrating(sinceCovered: TimeInterval?) -> Bool {
        guard let sinceCovered else { return false }
        return sinceCovered >= 0 && sinceCovered < celebrateSeconds
    }

    /// The quiet line under the clock.
    enum Note: Equatable {
        case nextRay(seconds: TimeInterval)
        case covered
        case paused
    }

    static func note(paused: Bool, covered: Bool, secondsToNextRay: TimeInterval) -> Note {
        if paused { return .paused }
        return covered ? .covered : .nextRay(seconds: secondsToNextRay)
    }

    /// Where the progress bar's two parts end: what the day had before this session, and the part played now.
    static func bar(doneSaved: TimeInterval, running: TimeInterval, target: TimeInterval?) -> (before: Double, now: Double) {
        let stretch = (target ?? fallbackStretch)
        guard stretch > 0 else { return (0, 0) }
        let before = clamp(doneSaved / stretch)
        let total = clamp((doneSaved + max(0, running)) / stretch)
        return (before, max(0, total - before))
    }
}
