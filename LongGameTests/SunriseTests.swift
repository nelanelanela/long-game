import Testing
import SwiftUI
import UIKit
@testable import LongGame

struct SunriseMotionTests {
    @Test func wavesLoopSeamlesslyByExactlyOneWavelength() {
        // Both waves are back where they started after one period: a whole wavelength (40 pt) of drift.
        for t in [0.0, 1.3, 77.7] {
            let right = SunriseMotion.wavePhaseRight(t), later = SunriseMotion.wavePhaseRight(t + SunriseMotion.waveRightPeriod)
            #expect(abs(right - later) < 0.001)
            let left = SunriseMotion.wavePhaseLeft(t), laterLeft = SunriseMotion.wavePhaseLeft(t + SunriseMotion.waveLeftPeriod)
            #expect(abs(left - laterLeft) < 0.001)
        }
        #expect(SunriseMotion.wavePhaseRight(1.6) == 20)
        #expect(abs(SunriseMotion.wavePhaseLeft(2.5) - 20) < 0.001)
    }

    @Test func navyWaveDriftsRightAndPaleWaveLeft() {
        #expect(SunriseMotion.wavePhaseRight(0.8) > SunriseMotion.wavePhaseRight(0.4))
        #expect(SunriseMotion.wavePhaseLeft(1.0) < SunriseMotion.wavePhaseLeft(0.5))
    }

    @Test func sunBreathesOverFourSeconds() {
        #expect(SunriseMotion.breathe(0) < 0.0001)
        #expect(abs(SunriseMotion.breathe(2) - 1) < 0.0001)
        #expect(SunriseMotion.breathe(4) < 0.0001)
    }

    @Test func raysTurnOnceEveryNinetySeconds() {
        #expect(SunriseMotion.rotationDegrees(0) == 0)
        #expect(abs(SunriseMotion.rotationDegrees(45) - 180) < 0.0001)
        #expect(abs(SunriseMotion.rotationDegrees(90 + 22.5) - 90) < 0.0001)
    }

    @Test func eyesOpenForAboutAThirdOfASecondEverySevenSeconds() {
        #expect(SunriseMotion.eyesOpen(0) == 0)
        #expect(SunriseMotion.eyesOpen(5) == 0)
        #expect(SunriseMotion.eyesOpen(6.4) == 1)
        #expect(SunriseMotion.eyesOpen(6.6) == 1)
        #expect(SunriseMotion.eyesOpen(7.0) == 0)
        #expect(SunriseMotion.eyesOpen(7 + 3) == 0)
        // fully open from 90% to 95% of the cycle: 0.35 s
        let open = stride(from: 0.0, to: 7.0, by: 0.005).filter { SunriseMotion.eyesOpen($0) > 0.999 }.count
        #expect(abs(Double(open) * 0.005 - 0.35) < 0.02)
    }

    @Test func glowPulsesWithTheBreath() {
        #expect(abs(SunriseMotion.glowOpacity(0) - 0.55) < 0.0001)
        #expect(abs(SunriseMotion.glowOpacity(2) - 0.8) < 0.0001)
        #expect(abs(SunriseMotion.glowScale(2) - 1.06) < 0.0001)
    }

    @Test func futureSelfSunRisesIntoPlaceInOnePointSixSeconds() {
        #expect(SunriseMotion.rise(after: 0) == 34)
        #expect(SunriseMotion.rise(after: 0.8) < 34 && SunriseMotion.rise(after: 0.8) > 0)
        #expect(SunriseMotion.rise(after: 1.6) == 0)
        #expect(SunriseMotion.rise(after: 10) == 0)
        #expect(SunriseMotion.rise(after: 0.4) > SunriseMotion.rise(after: 0.9))
    }
}

struct SunriseLayoutTests {
    private func tip(_ layout: SunriseLayout) -> (top: CGFloat, bottom: CGFloat) {
        let reach = 82 * layout.sunSize / 200
        let centre = layout.sunTop + layout.sunSize / 2
        return (centre - reach, centre + reach)
    }

    @Test func theSunRisesAsTheValueGrows() {
        let tops = [0.0, 0.01, 0.1, 0.3294, 0.5, 1].map { SunriseLayout.gauge(fraction: $0).sunTop }
        #expect(tops == tops.sorted(by: >))
        #expect(tops.first! > tops.last!)
    }

    @Test func atZeroTheSunsCentreSitsJustAboveTheWater() {
        let l = SunriseLayout.gauge(fraction: 0)
        let centre = l.sunTop + l.sunSize / 2
        #expect(centre == GaugeGeometry.zeroY)
        #expect(centre < l.waterY && l.waterY - centre < 10)
        // the lower half, rays included, is under the sea
        #expect(tip(l).bottom > l.waterY + 40)
    }

    @Test func atTheTopTheWholeSunIsAboveTheWaterAndInsideTheHero() {
        let l = SunriseLayout.gauge(fraction: 1)
        #expect(tip(l).bottom < l.waterY - 6)
        #expect(tip(l).top > 0)
        #expect(l.sunTop + l.sunSize / 2 == GaugeGeometry.topY)
    }

    @Test func theValueIsCappedAndNeverNegative() {
        #expect(SunriseLayout.gauge(fraction: -5).sunTop == SunriseLayout.gauge(fraction: 0).sunTop)
        #expect(SunriseLayout.gauge(fraction: 2.5).sunTop == SunriseLayout.gauge(fraction: 1).sunTop)
    }

    @Test func theSunSitsRightOfCentreToMakeRoomForTheScale() {
        #expect(SunriseLayout.gauge(fraction: 0.5).sunOffsetX == 20)
        #expect(SunriseLayout.intro(page: 0).sunOffsetX == 0)
    }

    @Test func theCelebrateFaceDoesNotPeek() {
        #expect(SunriseLayout.gauge(fraction: 0.5, face: .happy).peeks)
        #expect(!SunriseLayout.gauge(fraction: 1, face: .celebrate).peeks)
    }

    @Test func introPagesUseTheDesignPositions() {
        #expect(SunriseLayout.intro(page: 0).sunTop == 70)
        #expect(SunriseLayout.intro(page: 1).sunTop == 150)
        #expect(SunriseLayout.intro(page: 2).sunTop == 96)
        #expect(SunriseLayout.intro(page: 2).litRays == 8)
        #expect(SunriseLayout.intro(page: 0).litRays == 12)
        #expect(SunriseLayout.intro(page: 1).waterY == 244)
    }

    @Test func futureSelfSunSitsAboveTheWater() {
        let l = SunriseLayout.futureSelf
        #expect(tip(l).bottom <= l.waterY)
    }
}

/// The strict rule: whatever the wave phase, progress, breathing, rising or size, no part of the sun shows below
/// the waterline. These tests draw the real hero and look at the pixels.
@MainActor
struct SunriseWaterlineTests {
    private func pixels(_ layout: SunriseLayout, _ frame: SunriseFrame, width: CGFloat = 390) -> (data: [UInt8], w: Int, h: Int, scale: Int) {
        let view = SunriseCanvas(layout: layout, frame: frame)
            .frame(width: width, height: layout.height)
            .background(Color.white)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let cg = renderer.uiImage?.cgImage else { return ([], 0, 0, 2) }
        let w = cg.width, h = cg.height
        var data = [UInt8](repeating: 0, count: w * h * 4)
        let ctx = CGContext(data: &data, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        ctx?.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        return (data, w, h, 2)
    }

    /// Sun body and rays (yellows and oranges), cheeks (pink) or the navy face lines.
    private func isSun(_ r: Int, _ g: Int, _ b: Int) -> Bool {
        let yellow = r > 235 && g > 150 && g < 220 && b < 140
        let pink = r > 225 && g > 140 && g < 190 && b > 160 && b < 205
        let navy = r < 60 && g < 70 && b < 110
        return yellow || pink || navy
    }

    private func sunPixels(_ shot: (data: [UInt8], w: Int, h: Int, scale: Int), fromY: CGFloat, toY: CGFloat) -> Int {
        var count = 0
        let y0 = max(0, Int(fromY) * shot.scale), y1 = min(shot.h, Int(toY) * shot.scale)
        guard y0 < y1 else { return 0 }
        for y in y0..<y1 {
            for x in 0..<shot.w {
                let i = (y * shot.w + x) * 4
                if isSun(Int(shot.data[i]), Int(shot.data[i + 1]), Int(shot.data[i + 2])) { count += 1 }
            }
        }
        return count
    }

    private var layouts: [(String, SunriseLayout, CGFloat)] {
        [("home 0%", .gauge(fraction: 0), 0), ("home 1%", .gauge(fraction: 0.01), 0), ("home 5%", .gauge(fraction: 0.05), 0),
         ("home 25%", .gauge(fraction: 0.25), 0), ("home 54%", .gauge(fraction: 6.5 / 12), 0),
         ("home 80%", .gauge(fraction: 0.8), 0), ("home 100%", .gauge(fraction: 1, face: .celebrate), 0),
         ("home 150%", .gauge(fraction: 1.5, face: .celebrate), 0),
         ("intro 1", .intro(page: 0), 0), ("intro 2", .intro(page: 1), 0), ("intro 3", .intro(page: 2), 0),
         ("future rising", .futureSelf, 34), ("future halfway", .futureSelf, 17), ("future risen", .futureSelf, 0)]
    }

    @Test func noPartOfTheSunShowsBelowTheWaterlineAtAnyPhase() {
        var rendered = 0
        for (name, layout, rise) in layouts {
            for phase in [CGFloat(0), 6, 13, 20, 27, 33, 39.9] {
                for breathe in [0.0, 1.0] {
                    for eyes in [0.0, 1.0] {
                        let shot = pixels(layout, .frozen(phase: phase, breathe: breathe, rise: rise, eyesOpen: eyes))
                        guard shot.w > 0 else { Issue.record("Could not render \(name)"); return }
                        rendered += 1
                        // 3.5 pt crest or trough plus the 2 pt line and anti-aliasing: 7 pt below the middle is water.
                        let leaked = sunPixels(shot, fromY: layout.waterY + 7, toY: layout.height)
                        #expect(leaked == 0, "\(name), phase \(phase), breathe \(breathe), eyes \(eyes): \(leaked) sun pixels below the water")
                    }
                }
            }
        }
        #expect(rendered > 100)
    }

    @Test func theSunReallyIsDrawnAboveTheWater() {
        // Guards the test above against passing because nothing was drawn.
        let layout = SunriseLayout.gauge(fraction: 1, face: .celebrate)
        let shot = pixels(layout, .frozen(phase: 10))
        #expect(sunPixels(shot, fromY: 0, toY: layout.waterY - 8) > 2_000)
    }

    @Test func atZeroTheUpperHalfShowsAndTheLowerHalfIsUnderTheSea() {
        let layout = SunriseLayout.gauge(fraction: 0)
        let shot = pixels(layout, .frozen(phase: 10))
        #expect(sunPixels(shot, fromY: 0, toY: layout.waterY - 4) > 5_000)
        #expect(sunPixels(shot, fromY: layout.waterY + 7, toY: layout.height) == 0)
    }

    @Test func noPartOfTheSunShowsBelowTheWaterlineOnANarrowScreen() {
        for (name, layout, rise) in layouts where name.hasPrefix("home") {
            let shot = pixels(layout, .frozen(phase: 17, rise: rise), width: 320)
            #expect(sunPixels(shot, fromY: layout.waterY + 7, toY: layout.height) == 0, "\(name) at 320 pt wide")
        }
    }
}
