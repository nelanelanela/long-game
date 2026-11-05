import Testing
import Foundation
@testable import LongGame

@Suite("App icon · stages")
struct IconStageTests {
    @Test func thresholds() {
        #expect(IconStage.for(totalHours: 0) == .start)
        #expect(IconStage.for(totalHours: 999.9) == .start)
        #expect(IconStage.for(totalHours: 1_000) == .k1)
        #expect(IconStage.for(totalHours: 2_499) == .k1)
        #expect(IconStage.for(totalHours: 2_500) == .k2_5)
        #expect(IconStage.for(totalHours: 4_999.9) == .k2_5)
        #expect(IconStage.for(totalHours: 5_000) == .k5)
        #expect(IconStage.for(totalHours: 7_500) == .k7_5)
        #expect(IconStage.for(totalHours: 9_999.9) == .k7_5)
        #expect(IconStage.for(totalHours: 10_000) == .k10)
        #expect(IconStage.for(totalHours: 12_345) == .k10)
    }

    @Test func namesAndNumbersMatchTheAssets() {
        #expect(IconStage.start.alternateIconName == nil)
        #expect(IconStage.start.assetName == "AppIcon")
        #expect(IconStage.allCases.dropFirst().map(\.assetName) ==
                ["AppIcon-1000", "AppIcon-2500", "AppIcon-5000", "AppIcon-7500", "AppIcon-10000"])
        #expect(IconStage.allCases.map(\.number) == ["10,000", "1,000", "2,500", "5,000", "7,500", "10,000"])
        #expect(IconStage.allCases.map(\.ringFill) == [0, 0.1, 0.25, 0.5, 0.75, 1])
    }
}

@Suite("App icon · when it changes")
struct IconPlanTests {
    @Test func onlyCelebrationsOfAThousandOrMoreChangeTheIcon() {
        #expect(IconPlan.afterCelebration(hours: 100, totalHours: 120, growsWithYou: true) == nil)
        #expect(IconPlan.afterCelebration(hours: 500, totalHours: 520, growsWithYou: true) == nil)
        #expect(IconPlan.afterCelebration(hours: 1_000, totalHours: 1_010, growsWithYou: true) == .k1)
        #expect(IconPlan.afterCelebration(hours: 1_000, totalHours: 1_010, growsWithYou: false) == nil)
    }

    @Test func aBigJumpGoesStraightToTheHighestStage() {
        // 600 h → 5,200 h in one catch-up crosses 1,000, 2,500 and 5,000; the celebration is for 5,000.
        let crossed = Milestones.newlyCrossed(total: 5_200, seen: [100, 500])
        #expect(crossed == [1_000, 2_500, 5_000])
        #expect(IconPlan.afterCelebration(hours: crossed.max()!, totalHours: 5_200, growsWithYou: true) == .k5)
    }

    @Test func aLowerTotalLowersTheIconQuietly() {
        // Replace my craft: the new craft starts near zero while the icon was at 5,000.
        #expect(IconPlan.quietStage(totalHours: 20, growsWithYou: true, applied: .k5, celebrationPending: false) == .start)
        // Deleted sessions drop the total from 2,600 to 2,400.
        #expect(IconPlan.quietStage(totalHours: 2_400, growsWithYou: true, applied: .k2_5, celebrationPending: false) == .k1)
        // Nothing to do when it already matches.
        #expect(IconPlan.quietStage(totalHours: 2_400, growsWithYou: true, applied: .k1, celebrationPending: false) == nil)
    }

    @Test func aHigherStageWaitsForTheCelebration() {
        #expect(IconPlan.quietStage(totalHours: 1_200, growsWithYou: true, applied: .start, celebrationPending: true) == nil)
        // New users already past 1,000 hours get their stage once, when Home first appears.
        #expect(IconPlan.quietStage(totalHours: 1_200, growsWithYou: true, applied: .start, celebrationPending: false) == .k1)
        // A lower stage is never held back.
        #expect(IconPlan.quietStage(totalHours: 10, growsWithYou: true, applied: .k2_5, celebrationPending: true) == .start)
    }

    @Test func theSwitchOffAndOn() {
        #expect(IconPlan.wanted(totalHours: 3_000, growsWithYou: false) == .start)
        #expect(IconPlan.wanted(totalHours: 3_000, growsWithYou: true) == .k2_5)
        // Off: the plain icon even though the applied stage is higher. On: the current stage again.
        #expect(IconPlan.quietStage(totalHours: 3_000, growsWithYou: false, applied: .k2_5, celebrationPending: false) == .start)
        #expect(IconPlan.quietStage(totalHours: 3_000, growsWithYou: true, applied: .start, celebrationPending: false) == .k2_5)
        // While it is off no celebration moves it.
        #expect(IconPlan.afterCelebration(hours: 2_500, totalHours: 2_600, growsWithYou: false) == nil)
    }

    @Test func theSystemIsOnlyCalledWhenAllowed() {
        func call(_ wanted: IconStage, current: String? = nil, active: Bool = true, supports: Bool = true, timer: Bool = false) -> Bool {
            IconPlan.shouldCall(wanted: wanted, currentIconName: current, appActive: active,
                                supportsAlternateIcons: supports, timerRunning: timer)
        }
        #expect(call(.k1))
        #expect(call(.start, current: "AppIcon-1000"))
        #expect(!call(.k1, current: "AppIcon-1000"))   // already showing
        #expect(!call(.start))                          // primary already showing
        #expect(!call(.k1, active: false))
        #expect(!call(.k1, supports: false))
        #expect(!call(.k1, timer: true))                // never during a session
    }
}
