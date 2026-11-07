import Testing
import CoreGraphics
import Foundation
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

    @Test func regularButTallIsTheTallLayout() {
        #expect(WindowShape.make(width: 744, height: 1133, isRegularWidth: true) == .tall)
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

struct IPadShapeTests {
    @Test func ipadLandscapeAndBigStageManagerWindowsGetTheSidebar() {
        #expect(WindowShape.make(width: 1194, height: 834, isRegularWidth: true) == .sidebar)
        #expect(WindowShape.make(width: 1133, height: 744, isRegularWidth: true) == .sidebar)
        #expect(WindowShape.make(width: 1000, height: 700, isRegularWidth: true) == .sidebar)
    }
    @Test func smallerLandscapeWindowsKeepTheTwoPaneLayout() {
        #expect(WindowShape.make(width: 999, height: 700, isRegularWidth: true) == .wide)
        #expect(WindowShape.make(width: 802, height: 573, isRegularWidth: true) == .wide)
    }
    @Test func portraitIpadsAreTall() {
        #expect(WindowShape.make(width: 834, height: 1194, isRegularWidth: true) == .tall)
        #expect(WindowShape.make(width: 744, height: 1133, isRegularWidth: true) == .tall)
    }
    @Test func slideOverAndSplitViewThirdsAreThePhoneLayout() {
        #expect(WindowShape.make(width: 320, height: 1194, isRegularWidth: false) == .compact)
        #expect(WindowShape.make(width: 507, height: 834, isRegularWidth: false) == .compact)
        #expect(WindowShape.make(width: 597, height: 834, isRegularWidth: false) == .compact)
    }
    @Test func isWideCoversSidebarButNotTall() {
        #expect(WindowShape.sidebar.isWide)
        #expect(!WindowShape.tall.isWide && WindowShape.tall.isTall)
    }
}

struct IPadFiguresTests {
    @Test func rhythmReadsAsDaysPerWeek() {
        #expect(IPadFigures.rhythmText(daysPerWeek: 6).contains("6"))
        #expect(IPadFigures.rhythmText(daysPerWeek: 0) == "–")
    }

    @Test func dailyHoursAddUpPerCalendarDay() {
        let cal = Calendar(identifier: .gregorian)
        let day = cal.date(from: DateComponents(year: 2026, month: 11, day: 6, hour: 7))!
        let later = day.addingTimeInterval(3 * 3600)
        let records = [SessionRecord(start: day, durationSec: 3600), SessionRecord(start: later, durationSec: 1800)]
        let daily = IPadFigures.daily(records, calendar: cal)
        #expect(daily.count == 1)
        #expect(daily.values.first == 1.5)
    }

    @Test func sidebarPlayViewsMatchTheHomeTabs() {
        for tab in HomeTab.allCases { #expect(SidebarSection(tab: tab).homeTab == tab) }
        #expect(SidebarSection.calendar.homeTab == nil)
        #expect(SidebarSection.numbered.count == 5)
    }

    @MainActor @Test func commandsAreNumberedSoRepeatsAreSeen() {
        let center = CommandCenter()
        center.send(.addHours)
        let first = center.issued
        center.send(.addHours)
        #expect(first != center.issued)
        #expect(center.issued?.command == .addHours)
    }
}
