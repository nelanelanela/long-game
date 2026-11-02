import Testing
import CoreGraphics
@testable import LongGame

struct WindowShapeTests {
    @Test func phoneIsCompact() {
        #expect(WindowShape.make(width: 393, height: 852, isRegularWidth: false) == .compact)
    }

    @Test func duoClosedAndSmallPhonesAreShort() {
        #expect(WindowShape.make(width: 405, height: 567, isRegularWidth: false) == .short)
        #expect(WindowShape.make(width: 375, height: 667, isRegularWidth: false) == .short)
    }

    @Test func duoOpenIsWide() {
        #expect(WindowShape.make(width: 802, height: 573, isRegularWidth: true) == .wide)
    }

    @Test func splitViewHalfWidthIsNotWide() {
        // Half of the open Duo: compact width, 401 × 573.
        #expect(WindowShape.make(width: 401, height: 573, isRegularWidth: false) == .short)
    }

    @Test func regularButTallStaysOnePhoneColumn() {
        #expect(WindowShape.make(width: 744, height: 1133, isRegularWidth: true) == .compact)
    }

    @Test func aPhoneTurnedSidewaysCountsAsWideWithoutARegularClass() {
        #expect(WindowShape.make(width: 852, height: 393, isRegularWidth: false) == .wide)
        #expect(WindowShape.make(width: 667, height: 375, isRegularWidth: false) == .short)
    }
}

struct GaugeMetricsTests {
    @Test func standardMatchesThePhone() {
        let m = GaugeMetrics.standard
        #expect(m.centreY(fraction: 0) == GaugeGeometry.zeroY)
        #expect(m.centreY(fraction: 1) == GaugeGeometry.topY)
        #expect(m.height == GaugeGeometry.height)
    }

    @Test func shortHeroIs212WithA120Sun() {
        #expect(GaugeMetrics.short.height == 212)
        #expect(GaugeMetrics.short.sunSize == 120)
    }

    @Test func sunStaysInsideTheHeroAtEveryHeight() {
        for window in stride(from: CGFloat(300), through: 900, by: 50) {
            let m = GaugeMetrics.wide(height: WideGauge.height(forWindow: window))
            #expect(m.centreY(fraction: 1) - m.sunSize / 2 >= 0)
            #expect(m.zeroY < m.waterY)
            #expect(m.height <= WideGauge.maxHeight && m.height >= WideGauge.minHeight)
        }
    }

    @Test func wideHeroOnTheDuoHas150PtSun() {
        #expect(GaugeMetrics.wide(height: WideGauge.height(forWindow: 573)).sunSize == 150)
    }

    @Test func theScaleAndPillClearTheSideIsland() {
        for inset in [CGFloat(0), 30, 50, 62] {
            let m = GaugeMetrics.wide(height: 470, leadingInset: inset)
            // The scale's labels sit 36 pt left of the line.
            #expect(m.scaleX - 36 >= inset)
            #expect(m.pillX > inset)
        }
    }
}
