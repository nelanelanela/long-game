import Foundation
import CoreGraphics

// A cloudy sky (update 52, `design/redesign/HomeCloudy.dc.html` and the Cloud card on SunMoods.dc.html): every cloud
// different, built from a seeded mulberry32 stream. Two depths (small flat clouds low and far, bigger ones higher and
// near) and one or two thin wisps high up. Seeded by the day, so the sky changes each day but never jumps.
//
// The shapes are made in each cloud's own space (its box starts at 0, 0), so the app can draw each one once into a
// picture per day and only move it. Where they sit is worked out separately, from the sun's place.

enum CloudDepth: Sendable {
    case far, near

    /// How strong the cloud is: far ones are fainter.
    var opacity: Double { self == .far ? 0.6 : 0.92 }
    /// Soft edges: far ones are softer.
    var blur: CGFloat { self == .far ? 1.4 : 0.6 }
    /// The underside colour from the low sun: warm far away, cooler near.
    var undersideHex: UInt32 { self == .far ? 0xEDDCD3 : 0xDCDDEC }
    /// Where the base line sits, as a share of the way down to the horizon.
    var heightRange: ClosedRange<Double> { self == .far ? 0.66...0.84 : 0.30...0.55 }
    /// How wide, as a share of the scene's width.
    var widthRange: ClosedRange<Double> { self == .far ? 0.14...0.24 : 0.24...0.40 }
    /// How many of them.
    var countRange: ClosedRange<Int> { self == .far ? 2...3 : 1...3 }
    /// Side-to-side drift: the most any cloud of this depth swings each way, in points (placement keeps this much
    /// clear of the sun). Each cloud has its own swing and speed (`CloudDrift`).
    var driftAmplitude: CGFloat { self == .far ? 8 : 14 }
}

/// How one cloud drifts: its own swing, time and starting point, so every cloud moves at its own speed.
struct CloudDrift: Equatable, Sendable {
    /// Half the full swing, in points (never more than the depth's `driftAmplitude`).
    var amplitude: CGFloat
    /// How long one swing takes, in seconds.
    var period: Double
    /// Where in its swing it is at time 0, from 0 to 2 (one swing there and back).
    var phase: Double
    /// Near clouds go right first, far ones left, so the two depths pass each other.
    var rightFirst: Bool

    /// The day's top speeds, in points a second: spread evenly from slow to fast, so every cloud is clearly different.
    static let speeds: ClosedRange<Double> = 0.35...1.25

    /// The drift for each of the day's clouds (far ones first, then near): every cloud gets its own slot of `speeds`,
    /// with a little jitter; far clouds get the slower slots, in a random order, near ones the faster. Drawn from its
    /// own seeded stream, so it changes nothing about where the day's clouds sit.
    static func make(seed: UInt32, depths: [CloudDepth]) -> [CloudDrift] {
        var random = Mulberry32(seed: seed ^ 0x9E37_79B9)
        let n = depths.count
        guard n > 0 else { return [] }
        var slots = Array(0..<n)
        let farCount = depths.filter { $0 == .far }.count
        func shuffle(_ range: Range<Int>) {
            for i in stride(from: range.upperBound - 1, to: range.lowerBound, by: -1) {
                slots.swapAt(i, range.lowerBound + Int(random.next() * Double(i - range.lowerBound + 1)))
            }
        }
        shuffle(0..<farCount)
        shuffle(farCount..<n)
        let gap = (speeds.upperBound - speeds.lowerBound) / Double(n)
        return depths.indices.map { i in
            let depth = depths[i]
            let speed = speeds.lowerBound + gap * (Double(slots[i]) + 0.5 + 0.3 * (random.next() - 0.5))
            let amplitude = depth.driftAmplitude * CGFloat(0.65 + 0.35 * random.next())
            return CloudDrift(amplitude: amplitude, period: Double(amplitude) * .pi / speed,
                              phase: 2 * random.next(), rightFirst: depth == .near)
        }
    }

    /// The fastest it moves, in points a second (mid-swing).
    var topSpeed: Double { Double(amplitude) * .pi / period }
}

/// One cloud's shape, in its own space: its box is (0, 0, size).
struct CloudShape: Equatable, Sendable {
    struct Puff: Equatable, Sendable { var x: CGFloat; var y: CGFloat; var r: CGFloat }
    var depth: CloudDepth
    var size: CGSize
    /// The first row along the base line.
    var row: [Puff]
    /// The small puffs on top of the two humps.
    var top: [Puff]
    /// The wide, thin ellipse along the base line.
    var base: CGRect
    /// The base line's height in the box.
    var baseY: CGFloat

    var puffs: [Puff] { row + top }

    /// Everything that is filled, as one shape.
    var path: CGPath {
        let p = CGMutablePath()
        for puff in puffs { p.addEllipse(in: CGRect(x: puff.x - puff.r, y: puff.y - puff.r, width: puff.r * 2, height: puff.r * 2)) }
        p.addEllipse(in: base)
        return p
    }
}

/// A cloud placed in the scene.
struct PlacedCloud: Equatable, Sendable {
    var shape: CloudShape
    /// Where its box sits in the scene, before drifting.
    var origin: CGPoint
    /// A number unique to this cloud for the day (to cache its picture).
    var index: Int
    /// Its own side-to-side drift.
    var drift: CloudDrift
    var frame: CGRect { CGRect(origin: origin, size: shape.size) }
}

/// A thin, long stroke high in the sky, with a shorter, fainter line just under it.
struct Wisp: Equatable, Sendable {
    var start: CGPoint
    var control: CGPoint
    var end: CGPoint
    var underStart: CGPoint
    var underEnd: CGPoint
    static let lineWidth: CGFloat = 2.7
    static let underWidth: CGFloat = 1.6
    static let opacity = 0.7
    static let underOpacity = 0.45
    static let blur: CGFloat = 1.4
    /// Its box, with room for the stroke and the blur.
    var frame: CGRect {
        let xs = [start.x, end.x, underStart.x, underEnd.x], ys = [start.y, control.y, end.y, underStart.y]
        return CGRect(x: xs.min()!, y: ys.min()!, width: xs.max()! - xs.min()!, height: ys.max()! - ys.min()!)
            .insetBy(dx: -2, dy: -3)
    }
}

struct CloudSky: Equatable, Sendable {
    /// Far clouds first, then near ones, the order they are drawn in.
    var clouds: [PlacedCloud]
    var wisps: [Wisp]

    /// The gradient over each cloud, top to bottom: white, warm white at 55%, #EBEAF2 at 85%, the underside at 100%.
    static func shading(_ depth: CloudDepth) -> [(hex: UInt32, at: Double)] {
        [(0xFFFFFF, 0), (0xFDFCFA, 0.55), (0xEBEAF2, 0.85), (depth.undersideHex, 1)]
    }
    /// The bottom 20% of each cloud fades out (to 15%), so the base has no hard edge.
    static let fadeFrom = 0.8
    static let fadeTo = 0.15

    /// How far clouds and wisps keep from the sun's centre: 1.3 × its ray radius.
    static func clearance(rayRadius: CGFloat) -> CGFloat { rayRadius * 1.3 }

    /// The day's seed: the same all day, different the next.
    static func seed(for date: Date, calendar: Calendar = .current) -> UInt32 {
        let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        // In 32 bits, so the watch (whose whole numbers are 32-bit) gets the same seed as the phone.
        return UInt32(truncatingIfNeeded: day) &* 2_654_435_761
    }

    // MARK: Shapes

    /// One cloud `width` wide, every one different.
    static func shape(_ depth: CloudDepth, width: CGFloat, random: inout Mulberry32) -> CloudShape {
        func r(_ a: Double, _ b: Double) -> CGFloat { CGFloat(a + (b - a) * random.next()) }
        let n = 7 + Int(random.next() * 5)                       // 7…11 puffs
        // Two soft humps at random places, one taller than the other.
        let firstLeft = random.next() < 0.5
        let c1 = r(0.22, 0.42), c2 = r(0.58, 0.80)
        let s1 = r(0.13, 0.2), s2 = r(0.12, 0.19)
        let tall: CGFloat = 1, short = r(0.55, 0.8)
        let a1 = firstLeft ? tall : short, a2 = firstLeft ? short : tall
        func profile(_ u: CGFloat) -> CGFloat {
            let h1 = a1 * exp(-pow((u - c1) / s1, 2) / 2), h2 = a2 * exp(-pow((u - c2) / s2, 2) / 2)
            return max(h1, h2)
        }
        // Near clouds are taller for their width; far ones flat.
        let maxR = width * (depth == .far ? r(0.11, 0.14) : r(0.16, 0.2))
        func radius(_ u: CGFloat) -> CGFloat {
            let ends = min(u, 1 - u)
            let taper = 0.4 + 0.6 * min(1, ends / 0.25)          // puffs near the ends are smaller
            return maxR * (0.22 + 0.78 * profile(u)) * taper
        }
        // The first row, left to right. Each puff overlaps the one before it (no loose dots at the ends); then the
        // whole row is scaled so its outer edges are exactly the cloud's sides.
        var us = (0..<n).map { i in CGFloat(i) / CGFloat(n - 1) }
        for i in 1..<(n - 1) { us[i] += r(-0.35, 0.35) / CGFloat(n - 1) }
        var radii = us.map(radius)
        var xs = [radii[0]]
        for i in 1..<n {
            let even = (us[i] - us[i - 1]) * width
            xs.append(xs[i - 1] + min(even, (radii[i - 1] + radii[i]) * 0.75))
        }
        let leftEdge = zip(xs, radii).map { $0 - $1 }.min()!, rightEdge = zip(xs, radii).map { $0 + $1 }.max()!
        let fit = width / (rightEdge - leftEdge)
        xs = xs.map { ($0 - leftEdge) * fit }
        radii = radii.map { $0 * fit }
        let lift = maxR * 0.45
        var row = (0..<n).map { i in
            CloudShape.Puff(x: xs[i], y: -radii[i] * 0.45 + r(-0.06, 0.06) * radii[i], r: radii[i])
        }
        // The surface of the first row above x: where a puff on top sits.
        func surface(_ x: CGFloat) -> CGFloat {
            var top = CGFloat.infinity
            for p in row where abs(x - p.x) < p.r { top = min(top, p.y - (p.r * p.r - (x - p.x) * (x - p.x)).squareRoot()) }
            return top.isFinite ? top : 0
        }
        // A few small puffs on top of the two humps, about 60% as many, for texture.
        let m = max(2, Int((Double(n) * 0.6).rounded()))
        var top: [CloudShape.Puff] = []
        for k in 0..<m {
            let onTall = k % 3 != 2
            let useFirst = onTall == firstLeft
            let c = useFirst ? c1 : c2, s = useFirst ? s1 : s2
            let u = min(0.9, max(0.1, c + r(-1, 1) * s * 0.8))
            let x = width * u
            let rad = radius(u) * fit * r(0.3, 0.48)
            top.append(.init(x: x, y: surface(x) + rad * r(0.25, 0.6), r: rad))
        }
        // Into the box: the highest point is at 0.
        let highest = (row + top).map { $0.y - $0.r }.min() ?? -lift
        let baseRY = max(1.2, width * 0.028)
        let baseY = -highest
        for i in row.indices { row[i].y -= highest }
        for i in top.indices { top[i].y -= highest }
        let base = CGRect(x: width / 2 - width * 0.42, y: baseY - baseRY, width: width * 0.84, height: baseRY * 2)
        // The box ends just under the base ellipse; below it nothing is drawn.
        let height = baseY + baseRY * 2 + 1
        return CloudShape(depth: depth, size: CGSize(width: width, height: height), row: row, top: top, base: base, baseY: baseY)
    }

    // MARK: The day's sky

    /// The clouds and wisps for a scene `size` big (its height is the horizon), with the sun at `sun` and its rays
    /// reaching `rayRadius`. Nothing comes nearer the sun's centre than 1.3 × `rayRadius`, at any point of the drift.
    static func make(seed: UInt32, size: CGSize, sun: CGPoint, rayRadius: CGFloat) -> CloudSky {
        guard size.width > 0, size.height > 0 else { return CloudSky(clouds: [], wisps: []) }
        var random = Mulberry32(seed: seed)
        let clear = clearance(rayRadius: rayRadius)
        var clouds: [PlacedCloud] = []
        var index = 0
        for depth in [CloudDepth.far, .near] {
            let span = depth.countRange
            let count = span.lowerBound + Int(random.next() * Double(span.count))
            // Spread them out: one slot of the width each, at a random place in it.
            var order = Array(0..<count)
            for i in stride(from: count - 1, to: 0, by: -1) { order.swapAt(i, Int(random.next() * Double(i + 1))) }
            for slot in order {
                let w = size.width * CGFloat(depth.widthRange.lowerBound + (depth.widthRange.upperBound - depth.widthRange.lowerBound) * random.next())
                let shape = shape(depth, width: w, random: &random)
                let slotW = size.width / CGFloat(count)
                let mid = slotW * (CGFloat(slot) + 0.2 + 0.6 * CGFloat(random.next()))
                let baseLine = size.height * CGFloat(depth.heightRange.lowerBound
                                                     + (depth.heightRange.upperBound - depth.heightRange.lowerBound) * random.next())
                let origin = CGPoint(x: mid - w / 2, y: baseLine - shape.baseY)
                if let placed = clearOfSun(CGRect(origin: origin, size: shape.size), sun: sun, clear: clear,
                                           drift: depth.driftAmplitude, scene: size) {
                    clouds.append(PlacedCloud(shape: shape, origin: placed, index: index,
                                              drift: CloudDrift(amplitude: 0, period: 1, phase: 0, rightFirst: true)))
                }
                index += 1
            }
        }
        // Each cloud's own drift, once we know which made it into the sky.
        for (cloud, drift) in zip(clouds.indices, CloudDrift.make(seed: seed, depths: clouds.map(\.shape.depth))) {
            clouds[cloud].drift = drift
        }
        var wisps: [Wisp] = []
        let wispCount = 1 + Int(random.next() * 2)
        for k in 0..<wispCount {
            let len = size.width * CGFloat(0.25 + 0.2 * random.next())
            let y = size.height * CGFloat(0.06 + 0.24 * random.next())
            let half = size.width / CGFloat(wispCount)
            let x = half * CGFloat(k) + CGFloat(random.next()) * max(0, half - len * 0.6) - len * 0.15
            let rise = len * CGFloat(0.02 + 0.03 * random.next())
            let bow = len * CGFloat(0.03 + 0.04 * random.next())
            let under0 = x + len * CGFloat(0.15 + 0.15 * random.next())
            let wisp = Wisp(start: CGPoint(x: x, y: y + rise), control: CGPoint(x: x + len / 2, y: y - bow),
                            end: CGPoint(x: x + len, y: y), underStart: CGPoint(x: under0, y: y + 5),
                            underEnd: CGPoint(x: under0 + len * 0.55, y: y + 5))
            guard let origin = clearOfSun(wisp.frame, sun: sun, clear: clear, drift: 0, scene: size) else { continue }
            let dx = origin.x - wisp.frame.minX, dy = origin.y - wisp.frame.minY
            func move(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x + dx, y: p.y + dy) }
            wisps.append(Wisp(start: move(wisp.start), control: move(wisp.control), end: move(wisp.end),
                              underStart: move(wisp.underStart), underEnd: move(wisp.underEnd)))
        }
        return CloudSky(clouds: clouds, wisps: wisps)
    }

    /// Slides a box sideways away from the sun (lifting it a little as it goes) until no point of it, anywhere in its
    /// drift, comes within `clear` of the sun's centre. Nil when it can't be cleared: leave it out.
    static func clearOfSun(_ box: CGRect, sun: CGPoint, clear: CGFloat, drift: CGFloat, scene: CGSize) -> CGPoint? {
        var rect = box
        let away: CGFloat = rect.midX < sun.x ? -1 : 1
        let maxLift = min(14, max(0, rect.minY - 2))
        for step in 0...40 {
            if !touches(rect, sun: sun, clear: clear, drift: drift) { return rect.origin }
            rect.origin.x = box.minX + away * CGFloat(step + 1) * 6
            rect.origin.y = box.minY - maxLift * min(1, CGFloat(step + 1) / 10)
            // No further than mostly off the side of the scene.
            if rect.maxX < rect.width * 0.4 || rect.minX > scene.width - rect.width * 0.4 { return nil }
        }
        return nil
    }

    /// Whether a box, anywhere in its side-to-side drift, comes within `clear` of the sun's centre.
    static func touches(_ rect: CGRect, sun: CGPoint, clear: CGFloat, drift: CGFloat) -> Bool {
        SceneWeather.overlaps(rect.insetBy(dx: -drift, dy: 0), sun: sun, radius: clear)
    }

    /// How far a cloud has drifted at time `t`: an ease in and out from one side to the other and back, at its own
    /// speed.
    static func drift(_ drift: CloudDrift, t: Double) -> CGFloat {
        var p = (t / drift.period + drift.phase).truncatingRemainder(dividingBy: 2)
        if p < 0 { p += 2 }
        let leg = p < 1 ? p : 2 - p                                 // 0→1→0, like `alternate`
        let eased = 0.5 - 0.5 * cos(.pi * leg)
        let x = CGFloat(-1 + 2 * eased) * drift.amplitude
        return drift.rightFirst ? x : -x
    }
}
