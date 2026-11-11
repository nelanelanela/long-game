import Testing
import Foundation
@testable import LongGame

/// The natural star field (update prompt 37, design/redesign/Sky.dc.html).
struct StarFieldTests {
    private let phone = (w: 390.0, h: 844.0, horizon: 0.6)

    @Test func theSameSizeAlwaysGivesTheSameStars() {
        let a = StarField.stars(width: phone.w, height: phone.h, horizon: phone.horizon)
        let b = StarField.stars(width: phone.w, height: phone.h, horizon: phone.horizon)
        #expect(!a.isEmpty)
        #expect(a == b)
        #expect(StarField.cached(width: phone.w, height: phone.h, horizon: phone.horizon) == a)
    }

    @Test func theSeedKnownValueNeverChanges() {
        // Pinned: (390 × 73856093) XOR (844 × 19349663), wrapped to 32 bits. If it changes, every sky changes.
        #expect(StarField.seed(width: 390, height: 844) == UInt32(truncatingIfNeeded: 28_803_876_270) ^ UInt32(truncatingIfNeeded: 16_331_115_572))
        // The first star of the launch sky, worked out with the design's own JavaScript.
        let first = StarField.stars(width: 390, height: 844, horizon: 0.6)[0]
        #expect(abs(first.x - 46.561970) < 1e-5)
        #expect(abs(first.y - 259.377430) < 1e-5)
        #expect(abs(first.radius - 0.691556) < 1e-5)
        #expect(first.kind == .soft)
    }

    @Test func differentSizesGiveDifferentStars() {
        let a = StarField.stars(width: 390, height: 844, horizon: 0.6)
        let b = StarField.stars(width: 402, height: 874, horizon: 0.6)
        let c = StarField.stars(width: 390, height: 845, horizon: 0.6)
        #expect(a != b)
        #expect(a != c)
        #expect(a.first?.x != c.first?.x)
    }

    @Test func noStarIsBelowTheTopLineOrOutsideTheSky() {
        for (w, h, horizon) in [(390.0, 844.0, 0.6), (170, 170, 0.7), (364, 170, 0.7), (184, 224, 0.7), (1024, 1366, 0.85), (60, 40, 1)] {
            let top = StarField.top(height: h, horizon: horizon)
            for s in StarField.stars(width: w, height: h, horizon: horizon) {
                #expect(s.y >= 0 && s.y <= top)
                #expect(s.x >= 0 && s.x <= w)
            }
        }
    }

    @Test func theCountFollowsTheSkyAreaBetween14And170() {
        #expect(StarField.count(width: 10, top: 10) == 14)
        #expect(StarField.count(width: 2000, top: 2000) == 170)
        #expect(StarField.count(width: 390, top: 455.76) == 118)
        // A phone sky gets close to its full count (a few tries are thrown away near the horizon).
        let stars = StarField.stars(width: 390, height: 844, horizon: 0.6)
        #expect(stars.count <= 118 && stars.count > 100)
    }

    @Test func theClassesComeInRoughly62_26_9_3Percent() {
        var counts = [StarClass: Int]()
        var total = 0
        for w in stride(from: 300, through: 440, by: 4) {
            for h in stride(from: 600, through: 960, by: 40) {
                for s in StarField.stars(width: Double(w), height: Double(h), horizon: 0.8) {
                    counts[s.kind, default: 0] += 1
                    total += 1
                }
            }
        }
        #expect(total > 10_000)
        func share(_ k: StarClass) -> Double { Double(counts[k] ?? 0) / Double(total) }
        #expect(abs(share(.faint) - 0.62) < 0.02)
        #expect(abs(share(.soft) - 0.26) < 0.02)
        #expect(abs(share(.bright) - 0.09) < 0.015)
        #expect(abs(share(.warm) - 0.03) < 0.01)
    }

    @Test func theClassesHaveTheDesignsSizesAndColours() {
        #expect(StarClass.from(0) == .faint)
        #expect(StarClass.from(0.62) == .soft)
        #expect(StarClass.from(0.88) == .bright)
        #expect(StarClass.from(0.97) == .warm)
        #expect(StarClass.allCases.map(\.baseRadius) == [0.45, 0.65, 0.9, 1.3])
        #expect(StarClass.allCases.map(\.opacity) == [0.45, 0.7, 0.9, 1])
        #expect(StarClass.warm.hex == 0xFFF4D6 && StarClass.faint.hex == 0xFFFFFF)
        for s in StarField.stars(width: 390, height: 844, horizon: 0.6) {
            #expect(s.radius >= s.kind.baseRadius * 0.85 - 1e-9 && s.radius <= s.kind.baseRadius * 1.15 + 1e-9)
        }
    }

    @Test func thereAreFewerStarsNearTheHorizonThanAtTheTop() {
        var topFifth = 0, bottomFifth = 0
        for w in stride(from: 300, through: 440, by: 10) {
            let h = 844.0, horizon = 0.7
            let top = StarField.top(height: h, horizon: horizon)
            for s in StarField.stars(width: Double(w), height: h, horizon: horizon) {
                if s.y < top / 5 { topFifth += 1 }
                if s.y > top * 4 / 5 { bottomFifth += 1 }
            }
        }
        #expect(bottomFifth < topFifth)
    }

    @Test func anEmptySkyHasNoStars() {
        #expect(StarField.stars(width: 0, height: 844, horizon: 0.6).isEmpty)
        #expect(StarField.stars(width: 390, height: 844, horizon: 0).isEmpty)
    }
}
