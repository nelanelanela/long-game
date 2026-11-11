import Foundation

// The night sky's stars (update prompt 37): a natural star field like a dark sky over the Alentejo, from
// design/redesign/Sky.dc.html. Many faint stars, a few bright ones, a soft band of the Milky Way, thinning
// towards the horizon. Seeded by the sky's size, so each sky size has its own stars that never move or change.
// SkyView draws them on every screen; Tools/MakeLaunchAssets.swift keeps a copy for the launch screen's bitmap.

/// The four brightness classes. Opacities are for the night sky; SkyView scales them for dawn.
enum StarClass: Int, CaseIterable, Sendable {
    case faint, soft, bright, warm

    /// The radius before the ×0.85–1.15 jitter.
    var baseRadius: Double {
        switch self {
        case .faint: 0.45
        case .soft: 0.65
        case .bright: 0.9
        case .warm: 1.3
        }
    }

    var opacity: Double {
        switch self {
        case .faint: 0.45
        case .soft: 0.7
        case .bright: 0.9
        case .warm: 1
        }
    }

    /// The colour: white, except the brightest class, which is a warm #FFF4D6.
    var hex: UInt32 { self == .warm ? 0xFFF4D6 : 0xFFFFFF }

    /// Which class a uniform number in 0..<1 falls in: 62% faint, 26% soft, 9% bright, 3% warm.
    static func from(_ u: Double) -> StarClass {
        u < 0.62 ? .faint : u < 0.88 ? .soft : u < 0.97 ? .bright : .warm
    }
}

struct Star: Equatable, Sendable {
    var x: Double
    var y: Double
    var radius: Double
    var kind: StarClass
}

enum StarField {
    /// JavaScript's Math.round for the positive sizes we get (halves go up).
    private static func jsRound(_ v: Double) -> Double { (v + 0.5).rounded(.down) }

    /// `(round(w) × 73856093) XOR (round(h) × 19349663)`, wrapped to 32 bits as the design's `>>> 0` does.
    static func seed(width w: Double, height h: Double) -> UInt32 {
        let a = UInt32(truncatingIfNeeded: Int64(jsRound(w)) &* 73_856_093)
        let b = UInt32(truncatingIfNeeded: Int64(jsRound(h)) &* 19_349_663)
        return a ^ b
    }

    /// Stars live above this line: 90% of the way down to the horizon.
    static func top(height h: Double, horizon: Double) -> Double { h * horizon * 0.9 }

    /// How many stars the sky tries to place: one per 1,500 square points of sky, 14 to 170.
    static func count(width w: Double, top: Double) -> Int {
        Int(min(170, max(14, jsRound(w * top / 1500))))
    }

    /// The stars for a sky of this size, in points from the top left. Pure and repeatable.
    static func stars(width w: Double, height h: Double, horizon: Double) -> [Star] {
        guard w > 0, h > 0, horizon > 0 else { return [] }
        var random = Mulberry32(seed: seed(width: w, height: h))
        let top = top(height: h, horizon: horizon)
        let n = count(width: w, top: top)
        let spread = min(w, top) * 0.1
        // A gaussian-ish number: the average of three uniform numbers, centred and scaled to -1...1.
        func gauss() -> Double {
            let a = random.next(), b = random.next(), c = random.next()
            return (a + b + c - 1.5) / 1.5
        }
        var stars: [Star] = []
        stars.reserveCapacity(n)
        var tries = 0
        while stars.count < n && tries < n * 6 {
            tries += 1
            var x: Double, y: Double
            if random.next() < 0.32 {
                // The Milky Way: a soft band from the top left to near the horizon on the right.
                let t = random.next()
                x = w * (0.08 + 0.9 * t) + gauss() * spread
                y = top * (0.02 + 0.95 * t) + gauss() * spread
            } else {
                x = random.next() * w
                y = random.next() * top
            }
            if x < 0 || x > w || y < 0 || y > top { continue }
            // Thinner towards the horizon, as the air gets thicker.
            if random.next() < (y / top) * (y / top) * 0.7 { continue }
            let kind = StarClass.from(random.next())
            let radius = kind.baseRadius * (0.85 + random.next() * 0.3)
            stars.append(Star(x: x, y: y, radius: radius, kind: kind))
        }
        return stars
    }

    /// The same as `stars`, remembered per size, so skies redrawn every frame (the timer, the opening sunrise)
    /// do not work them out again.
    static func cached(width w: Double, height h: Double, horizon: Double) -> [Star] {
        cache.value(for: Key(w: w, h: h, horizon: horizon)) { stars(width: w, height: h, horizon: horizon) }
    }

    private struct Key: Hashable { var w: Double, h: Double, horizon: Double }

    private final class Cache: @unchecked Sendable {
        private let lock = NSLock()
        private var stored: [Key: [Star]] = [:]
        func value(for key: Key, make: () -> [Star]) -> [Star] {
            lock.lock(); defer { lock.unlock() }
            if let hit = stored[key] { return hit }
            if stored.count > 64 { stored.removeAll() }
            let made = make()
            stored[key] = made
            return made
        }
    }

    private static let cache = Cache()
}

/// mulberry32, exactly as Sky.dc.html writes it.
struct Mulberry32 {
    private var a: UInt32
    init(seed: UInt32) { a = seed }
    mutating func next() -> Double {
        a = a &+ 0x6D2B79F5
        var t = a
        t = (t ^ (t >> 15)) &* (t | 1)
        t ^= t &+ ((t ^ (t >> 7)) &* (t | 61))
        return Double(t ^ (t >> 14)) / 4_294_967_296
    }
}
