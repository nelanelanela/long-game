import Testing
import Foundation
import CoreGraphics
@testable import LongGame

// Update 52: natural, varied clouds, built from a seeded generator.

struct CloudSkyTests {
    let scene = CGSize(width: 390, height: 236)
    /// The sun far away, so nothing is moved or left out.
    let nowhere = CGPoint(x: -10_000, y: -10_000)
    let seeds: [UInt32] = [1, 0xC10D, 739_000]

    @Test func sameSeedSameClouds() {
        for seed in seeds {
            let a = CloudSky.make(seed: seed, size: scene, sun: CGPoint(x: 200, y: 90), rayRadius: 50)
            let b = CloudSky.make(seed: seed, size: scene, sun: CGPoint(x: 200, y: 90), rayRadius: 50)
            #expect(a == b)
        }
    }

    @Test func differentSeedsDifferentClouds() {
        let skies = seeds.map { CloudSky.make(seed: $0, size: scene, sun: nowhere, rayRadius: 0) }
        #expect(skies[0] != skies[1] && skies[1] != skies[2] && skies[0] != skies[2])
        // And within one sky, no two clouds are the same shape.
        for sky in skies {
            let shapes = sky.clouds.map(\.shape)
            for i in shapes.indices { for j in shapes.indices where j > i { #expect(shapes[i] != shapes[j]) } }
        }
    }

    @Test func theDaySetsTheSeed() {
        let cal = Calendar(identifier: .gregorian)
        let morning = cal.date(from: DateComponents(year: 2026, month: 11, day: 16, hour: 7))!
        let evening = cal.date(from: DateComponents(year: 2026, month: 11, day: 16, hour: 21))!
        let tomorrow = cal.date(from: DateComponents(year: 2026, month: 11, day: 17, hour: 7))!
        #expect(CloudSky.seed(for: morning, calendar: cal) == CloudSky.seed(for: evening, calendar: cal))
        #expect(CloudSky.seed(for: morning, calendar: cal) != CloudSky.seed(for: tomorrow, calendar: cal))
    }

    @Test func countsAndSizesStayInTheirLimits() {
        for seed in UInt32(0)..<200 {
            let sky = CloudSky.make(seed: seed, size: scene, sun: nowhere, rayRadius: 0)
            let far = sky.clouds.filter { $0.shape.depth == .far }, near = sky.clouds.filter { $0.shape.depth == .near }
            #expect((2...3).contains(far.count) && (1...3).contains(near.count) && (1...2).contains(sky.wisps.count))
            // Far ones drawn first, then near ones.
            #expect(sky.clouds.map(\.shape.depth) == far.map { _ in CloudDepth.far } + near.map { _ in .near })
            for cloud in sky.clouds {
                let depth = cloud.shape.depth
                let width = cloud.shape.size.width / scene.width
                #expect(width >= depth.widthRange.lowerBound - 0.001 && width <= depth.widthRange.upperBound + 0.001)
                let base = (cloud.origin.y + cloud.shape.baseY) / scene.height
                #expect(base >= depth.heightRange.lowerBound - 0.001 && base <= depth.heightRange.upperBound + 0.001)
                #expect((7...11).contains(cloud.shape.row.count))
                // About 60% as many small puffs on top.
                #expect(abs(Double(cloud.shape.top.count) - Double(cloud.shape.row.count) * 0.6) <= 1)
                // Puffs near the ends are smaller than the biggest one.
                let radii = cloud.shape.row.map(\.r)
                #expect(radii.first! < radii.max()! && radii.last! < radii.max()!)
                // Each puff overlaps the one before it: no loose dots.
                let row = cloud.shape.row
                for i in 1..<row.count { #expect(row[i].x - row[i - 1].x < row[i].r + row[i - 1].r) }
                // Everything inside its box.
                for p in cloud.shape.row { #expect(p.x - p.r >= -0.01 && p.x + p.r <= cloud.shape.size.width + 0.01 && p.y - p.r >= -0.01) }
            }
            for wisp in sky.wisps {
                let length = (wisp.end.x - wisp.start.x) / scene.width
                #expect(length >= 0.25 - 0.001 && length <= 0.45 + 0.001)
                let y = wisp.end.y / scene.height
                #expect(y >= 0.06 - 0.001 && y <= 0.30 + 0.001)
                // The line under it is shorter.
                #expect(wisp.underEnd.x - wisp.underStart.x < wisp.end.x - wisp.start.x)
            }
        }
    }

    @Test func nothingTouchesTheSunAlongItsArc() {
        let rays: CGFloat = 50
        let clear = CloudSky.clearance(rayRadius: rays)
        for seed in seeds {
            // Morning (low left) to high noon to evening (low right).
            for i in 0...24 {
                let t = Double(i) / 24
                let sun = CGPoint(x: 40 + 310 * t, y: 210 - 160 * sin(.pi * t))
                let sky = CloudSky.make(seed: seed, size: scene, sun: sun, rayRadius: rays)
                for cloud in sky.clouds {
                    // Wherever it is in its drift.
                    for step in 0...8 {
                        let dx = CloudSky.drift(cloud.shape.depth, t: Double(step) * cloud.shape.depth.driftPeriod / 4)
                        #expect(!SceneWeather.overlaps(cloud.frame.offsetBy(dx: dx, dy: 0), sun: sun, radius: clear),
                                "seed \(seed), sun at \(sun)")
                    }
                }
                for wisp in sky.wisps {
                    #expect(!SceneWeather.overlaps(wisp.frame, sun: sun, radius: clear), "seed \(seed), sun at \(sun)")
                }
            }
        }
    }

    @Test func driftSwingsGentlyBothWays() {
        // Near: 28 pt over 40 s; far: the other way, 16 pt over 60 s.
        #expect(abs(CloudSky.drift(.near, t: 0) + 14) < 0.01 && abs(CloudSky.drift(.near, t: 40) - 14) < 0.01)
        #expect(abs(CloudSky.drift(.far, t: 0) - 8) < 0.01 && abs(CloudSky.drift(.far, t: 60) + 8) < 0.01)
        #expect(abs(CloudSky.drift(.near, t: 80) + 14) < 0.01)
    }
}
