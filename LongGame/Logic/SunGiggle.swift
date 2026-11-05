import Foundation

// The sun's giggle (spec section 18). Everything here is a pure function of time or a small value type, so it is
// all tested without a screen or a speaker. Distances are in the sun's own 200 × 200 drawing space.

enum GiggleKind: Equatable, Sendable {
    /// The normal giggle, about one second.
    case small
    /// Five quick taps: the longest clip and one full spin of the rays.
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
    /// Extra turn of the rays, in degrees (the big laugh makes one full spin).
    var raysSpin = 0.0
    var sparkles = Array(repeating: GiggleSparkle(), count: 4)
    /// 0 before the first haptic, then 1 (soft, at 0 s), 2 (light, 0.25 s), 3 (light, 0.45 s).
    var hapticStep = 0

    static let rest = GigglePose()
}

enum GiggleMotion {
    // The spec's timing table.
    static let squashEnd = 0.08
    static let laughEnd = 0.70
    static let smallDuration = 1.0
    static let bigDuration = 1.5
    static let winkDuration = 0.6
    /// Reduce Motion: the laughing face for this long, nothing moving.
    static let reducedDuration = 0.8
    static let hapticTimes: [TimeInterval] = [0, 0.25, 0.45]
    static let sparkleSpots: [(x: Double, y: Double)] = [(28, 40), (174, 34), (180, 152), (20, 156)]

    static func duration(of kind: GiggleKind, reduceMotion: Bool) -> TimeInterval {
        switch kind {
        case .wink: winkDuration
        case .small: reduceMotion ? reducedDuration : smallDuration
        case .big: reduceMotion ? reducedDuration : bigDuration
        }
    }

    /// Where the sun is at `t` seconds into the giggle; nil once it has finished.
    static func pose(at t: TimeInterval, kind: GiggleKind, reduceMotion: Bool) -> GigglePose? {
        let t = max(0, t)
        guard t < duration(of: kind, reduceMotion: reduceMotion) else { return nil }
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

        // The big laugh stretches the laughing part so it lasts as long as the longer clip; the rest of the
        // sequence is the small one, played on a stretched clock.
        let end = kind == .big ? bigDuration - (smallDuration - laughEnd) : laughEnd
        let tt = t < squashEnd ? t
            : t < end ? squashEnd + (t - squashEnd) * (laughEnd - squashEnd) / (end - squashEnd)
            : laughEnd + (t - end)

        // Face
        if t < squashEnd { pose.face = .surprised }
        else if t < end { pose.face = .laughing }
        else if t >= end + 0.02, t < end + 0.22 { pose.face = .wink }

        // Squash, wiggle and hops
        let q = squash(tt)
        pose.scaleX = 1 + 0.07 * q
        pose.scaleY = 1 - 0.08 * q
        let (rotation, dy) = wiggle(tt)
        pose.rotation = rotation
        pose.dy = dy

        // Rays flick out and back
        let laughFraction = clamp((tt - squashEnd) / (laughEnd - squashEnd))
        pose.raysScale = 1 + 0.08 * sin(laughFraction * .pi)
        if kind == .big {
            pose.raysSpin = 360 * easeInOut(clamp((t - squashEnd) / (end - squashEnd)))
        }

        // Sparkles
        let life = kind == .big ? 0.9 : 0.55
        for i in 0..<4 {
            let u = (t - (0.10 + 0.04 * Double(i))) / life
            guard u > 0, u < 1 else { continue }
            pose.sparkles[i] = u < 0.2
                ? GiggleSparkle(scale: 0.3 + 0.7 * (u / 0.2), opacity: u / 0.2)
                : GiggleSparkle(scale: 1 + 0.3 * ((u - 0.2) / 0.8), opacity: 1 - (u - 0.2) / 0.8)
        }
        return pose
    }

    // MARK: Pieces of the small sequence (clock `tt` in seconds)

    /// 0 → 1 while the sun squashes down (0 – 0.04 s), held until 0.08 s, then released by 0.14 s.
    static func squash(_ tt: Double) -> Double {
        if tt < 0.04 { return smooth(tt / 0.04) }
        if tt < squashEnd { return 1 }
        if tt < 0.14 { return 1 - smooth((tt - squashEnd) / 0.06) }
        return 0
    }

    /// Turn in degrees and vertical offset: −8°, +7°, −5°, +3°, −1° with hops of 6 and 5, then a spring back.
    static let wiggleKeys: [(t: Double, rotation: Double, dy: Double)] = [
        (0, 0, 0), (0.04, 0, 6), (squashEnd, 0, 6),
        (0.14, -8, -6), (0.26, 7, -2), (0.38, -5, -5), (0.50, 3, 0), (0.62, -1, 0), (laughEnd, 0, -2),
    ]

    static func wiggle(_ tt: Double) -> (rotation: Double, dy: Double) {
        if tt >= laughEnd { return (0, wiggleKeys.last!.dy * spring(tt - laughEnd)) }
        for i in 1..<wiggleKeys.count where tt <= wiggleKeys[i].t {
            let a = wiggleKeys[i - 1], b = wiggleKeys[i]
            let f = smooth((tt - a.t) / (b.t - a.t))
            return (a.rotation + (b.rotation - a.rotation) * f, a.dy + (b.dy - a.dy) * f)
        }
        return (0, 0)
    }

    /// The spring back: how much of the leftover is still there `t` seconds later (1 → 0, a little bounce).
    /// Response 0.35 s, damping 0.6.
    static func spring(_ t: Double, response: Double = 0.35, damping: Double = 0.6) -> Double {
        let omega = 2 * .pi / response
        let wd = omega * (1 - damping * damping).squareRoot()
        return exp(-damping * omega * t) * (cos(wd * t) + damping * omega / wd * sin(wd * t))
    }

    private static func clamp(_ x: Double) -> Double { min(max(x, 0), 1) }
    private static func smooth(_ x: Double) -> Double { let c = clamp(x); return c * c * (3 - 2 * c) }
    private static func easeInOut(_ x: Double) -> Double { smooth(x) }
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
