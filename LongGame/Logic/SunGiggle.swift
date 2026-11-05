import Foundation

// The sun's giggle (spec section 18). Everything here is a pure function of time or a small value type, so it is
// all tested without a screen or a speaker. Distances are in the sun's own 200 × 200 drawing space.

enum GiggleKind: Equatable, Sendable {
    /// The normal baby laugh: five bounces, a bit over a second.
    case small
    /// Five quick taps: eight bounces, the longest clip and one full spin of the rays.
    case big
    /// Only the wink: the Timer, and the rest after a big laugh. No sound, no wiggle.
    case wink
}

/// One of the four little gold sparkles that pop out around the sun.
struct GiggleSparkle: Equatable, Sendable {
    var scale = 0.0
    var opacity = 0.0
}

/// What the sun looks like at one moment of a giggle.
struct GigglePose: Equatable, Sendable {
    /// Replaces the sun's own face while the giggle runs; nil leaves it alone.
    var face: SunFace?
    var scaleX = 1.0
    var scaleY = 1.0
    /// Down is positive.
    var dy = 0.0
    var rotation = 0.0
    var raysScale = 1.0
    /// Extra turn of the rays, in degrees (the long belly laugh makes one full spin).
    var raysSpin = 0.0
    var sparkles = Array(repeating: GiggleSparkle(), count: 4)
    /// 0 before the first haptic, then 1 (soft, at the gasp), 2, 3, 4 (light, on the first three bounces, each softer).
    var hapticStep = 0
    /// How much deeper the cheeks are, 0 (normal) to 1; it fades back during the contented end.
    var blush = 0.0

    static let rest = GigglePose()
}

enum GiggleMotion {
    // The spec's timing table (section 18).
    static let gaspEnd = 0.10
    static let bounceLength = 0.16
    static let contentedLength = 0.35
    static let smallBounces = 5
    static let bigBounces = 8
    /// A tap during the laugh adds this many bounces, up to `maxBounces` in all (the long laugh stays the longest).
    static let extraPerTap = 2
    static let maxBounces = 7
    static let winkDuration = 0.6
    /// Reduce Motion: the baby-laugh face for this long, nothing moving.
    static let reducedDuration = 0.8
    static let hapticTimes: [TimeInterval] = [0, 0.12, 0.28, 0.44]
    static let sparkleSpots: [(x: Double, y: Double)] = [(28, 40), (174, 34), (180, 152), (20, 156)]
    static let maxTilt = 5.0

    static var smallDuration: TimeInterval { duration(bounces: smallBounces) }
    static var bigDuration: TimeInterval { duration(bounces: bigBounces) }

    private static func duration(bounces: Int) -> TimeInterval {
        gaspEnd + Double(bounces) * bounceLength + contentedLength
    }

    static func baseBounces(of kind: GiggleKind) -> Int {
        switch kind {
        case .small: smallBounces
        case .big: bigBounces
        case .wink: 0
        }
    }

    static func duration(of kind: GiggleKind, reduceMotion: Bool, extraBounces: Int = 0) -> TimeInterval {
        if kind == .wink { return winkDuration }
        return reduceMotion ? reducedDuration : duration(bounces: baseBounces(of: kind) + extraBounces)
    }

    /// When the bouncing stops and the contented end begins, in seconds from the tap.
    static func laughEnd(of kind: GiggleKind, extraBounces: Int = 0) -> TimeInterval {
        gaspEnd + Double(baseBounces(of: kind) + extraBounces) * bounceLength
    }

    /// Where the sun is at `t` seconds into the giggle; nil once it has finished.
    static func pose(at t: TimeInterval, kind: GiggleKind, reduceMotion: Bool, extraBounces: Int = 0) -> GigglePose? {
        let t = max(0, t)
        guard t < duration(of: kind, reduceMotion: reduceMotion, extraBounces: extraBounces) else { return nil }
        var pose = GigglePose()
        if kind == .wink {
            pose.face = .wink
            return pose
        }
        pose.hapticStep = hapticTimes.lastIndex(where: { t >= $0 }).map { $0 + 1 } ?? 0
        if reduceMotion {
            pose.face = .laughing
            return pose
        }
        let end = laughEnd(of: kind, extraBounces: extraBounces)

        // The gasp: stretch to 94% × 108% and up 4 pt. It melts away as the first bounce begins.
        let gasp = t < gaspEnd ? smooth(t / gaspEnd) : 1 - smooth((t - gaspEnd) / 0.06)
        pose.scaleX = 1 - 0.06 * gasp
        pose.scaleY = 1 + 0.08 * gasp
        pose.dy = -4 * gasp

        if t < gaspEnd {
            pose.face = .surprised
            pose.blush = 0
        } else if t < end {
            pose.face = .laughing
            pose.blush = smooth((t - gaspEnd) / 0.05)

            // Five quick bounces, each a little smaller: squash 106% × 94%, down 3 pt, then stretch 97% × 104%, up 5 pt.
            let k = (t - gaspEnd) / bounceLength
            let index = Int(k)
            let phase = k - Double(index)
            let amp = max(0.4, 1 - 0.12 * Double(index))
            let v = sin(2 * .pi * phase)
            pose.scaleX += v > 0 ? 0.06 * v * amp : 0.03 * v * amp
            pose.scaleY += v > 0 ? -0.06 * v * amp : -0.04 * v * amp
            pose.dy += v > 0 ? 3 * v * amp : 5 * v * amp
            pose.rotation = -maxTilt * smooth((t - gaspEnd) / 0.10)
            pose.raysScale = 1 + 0.08 * amp * abs(v)
            if kind == .big {
                pose.raysSpin = 360 * smooth((t - gaspEnd) / (end - gaspEnd))
            }
        } else {
            // Contented: spring back to the happy face with eyes closed, one tiny hiccup, the blush fades.
            let u = t - end
            pose.face = .happy
            pose.rotation = -maxTilt * spring(u, response: 0.4, damping: 0.55)
            pose.blush = 1 - clamp(u / contentedLength)
            let hiccup = (u - 0.10) / 0.10
            if hiccup > 0, hiccup < 1 { pose.dy += -2 * sin(hiccup * .pi) }
            if kind == .big { pose.raysSpin = 360 }
        }

        // Four small gold sparkles pop out and fade.
        let life = kind == .big ? 0.9 : 0.55
        for i in 0..<4 {
            let u = (t - (gaspEnd + 0.04 * Double(i))) / life
            guard u > 0, u < 1 else { continue }
            pose.sparkles[i] = u < 0.2
                ? GiggleSparkle(scale: 0.3 + 0.7 * (u / 0.2), opacity: u / 0.2)
                : GiggleSparkle(scale: 1 + 0.3 * ((u - 0.2) / 0.8), opacity: 1 - (u - 0.2) / 0.8)
        }
        return pose
    }

    /// The spring back: how much of the leftover is still there `t` seconds later (1 → 0, a little bounce).
    static func spring(_ t: Double, response: Double = 0.4, damping: Double = 0.55) -> Double {
        let omega = 2 * .pi / response
        let wd = omega * (1 - damping * damping).squareRoot()
        return exp(-damping * omega * t) * (cos(wd * t) + damping * omega / wd * sin(wd * t))
    }

    private static func clamp(_ x: Double) -> Double { min(max(x, 0), 1) }
    private static func smooth(_ x: Double) -> Double { let c = clamp(x); return c * c * (3 - 2 * c) }
}

// MARK: Which clip

/// Picks a clip at random, never the same one twice in a row.
struct GiggleClipPicker: Equatable, Sendable {
    let count: Int
    private(set) var last: Int?

    init(count: Int) { self.count = count }

    mutating func next<G: RandomNumberGenerator>(using generator: inout G) -> Int? {
        guard count > 0 else { return nil }
        guard count > 1, let previous = last else {
            let pick = Int.random(in: 0..<count, using: &generator)
            last = pick
            return pick
        }
        // Draw from the other clips only: skip over the one just played.
        var pick = Int.random(in: 0..<(count - 1), using: &generator)
        if pick >= previous { pick += 1 }
        last = pick
        return pick
    }
}

// MARK: Taps

/// What one tap on the sun should do.
struct GiggleTapResponse: Equatable, Sendable {
    enum Action: Equatable, Sendable {
        /// The big laugh is still going: the tap changes nothing.
        case ignore
        case wink
        case giggle
        case bigLaugh
    }
    var action: Action
    var playsSound: Bool
    /// The big laugh may cut a clip short; two clips are never heard together.
    var interruptsSound = false
}

/// The rules for tapping the sun, with no clock of its own: every call says what time it is.
struct GiggleTaps: Equatable, Sendable {
    static let bigTapCount = 5
    static let bigWindow: TimeInterval = 2
    static let rest: TimeInterval = 3

    private(set) var recent: [Date] = []
    private(set) var bigEndsAt: Date?
    private(set) var restUntil: Date?
    private(set) var soundEndsAt: Date?

    init() {}

    mutating func tap(at now: Date, soundAllowed: Bool) -> GiggleTapResponse {
        if let bigEndsAt, now < bigEndsAt { return GiggleTapResponse(action: .ignore, playsSound: false) }
        if let restUntil, now < restUntil { return GiggleTapResponse(action: .wink, playsSound: false) }

        recent = recent.filter { now.timeIntervalSince($0) <= Self.bigWindow } + [now]
        if recent.count >= Self.bigTapCount {
            recent = []
            bigEndsAt = now.addingTimeInterval(GiggleMotion.bigDuration)
            restUntil = now.addingTimeInterval(GiggleMotion.bigDuration + Self.rest)
            soundEndsAt = nil
            return GiggleTapResponse(action: .bigLaugh, playsSound: soundAllowed, interruptsSound: true)
        }
        let busy = soundEndsAt.map { now < $0 } ?? false
        return GiggleTapResponse(action: .giggle, playsSound: soundAllowed && !busy)
    }

    /// The app reports a clip that really started, so the next tap knows to leave the sound alone.
    mutating func soundStarted(at now: Date, length: TimeInterval) {
        soundEndsAt = now.addingTimeInterval(length)
    }
}
