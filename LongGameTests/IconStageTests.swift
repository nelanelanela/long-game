import Testing
import Foundation
@testable import LongGame

@Suite("App icon · stages")
struct IconStageTests {
    @Test func thresholds() {
        func t(_ h: Double) -> Int { IconStage.for(totalHours: h).thousands }
        #expect(t(0) == 0)
        #expect(t(999.9) == 0)
        #expect(t(1_000) == 1)
        #expect(t(1_999.9) == 1)
        #expect(t(2_000) == 2)
        #expect(t(2_500) == 2)
        #expect(t(9_999.9) == 9)
        #expect(t(10_000) == 10)
        #expect(t(12_000) == 10)
    }

    @Test func namesAndNumbersMatchTheAssets() {
        #expect(IconStage.all.count == 11)
        #expect(IconStage.start.alternateIconName == nil)
        #expect(IconStage.start.assetName == "AppIcon")
        #expect(IconStage.all.dropFirst().map(\.assetName) == (1...10).map { "AppIcon-\($0)000" })
        #expect(IconStage.all.map(\.number) == ["10,000", "1,000", "2,000", "3,000", "4,000", "5,000",
                                                "6,000", "7,000", "8,000", "9,000", "10,000"])
        #expect(IconStage.all.map(\.ringFill) == [0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1])
        #expect(IconStage(thousands: 14).thousands == 10)
    }

    @Test func anOldStoredValueIsUnknown() {
        #expect(IconStage(stored: "k2_5") == nil)
        #expect(IconStage(stored: "start") == nil)
        #expect(IconStage(stored: "4") == IconStage(thousands: 4))
    }
}

@Suite("App icon · when it changes")
struct IconPlanTests {
    private let g = true
    private func stage(_ n: Int) -> IconStage { IconStage(thousands: n) }

    @Test func onlyOneThousandFivethousandAndTenthousandHaveACelebration() {
        #expect(IconPlan.hasCelebration(thousands: 1))
        #expect(IconPlan.hasCelebration(thousands: 5))
        #expect(IconPlan.hasCelebration(thousands: 10))
        #expect([2, 3, 4, 6, 7, 8, 9].allSatisfy { !IconPlan.hasCelebration(thousands: $0) })
    }

    @Test func aCelebrationedThousandWaitsForTheButton() {
        // 5,000 crossed: the quiet check holds it while the celebration is due, the button then changes it.
        #expect(IconPlan.quietStage(totalHours: 5_010, growsWithYou: g, applied: stage(4), celebrationPending: true) == nil)
        #expect(IconPlan.afterCelebration(hours: 5_000, totalHours: 5_010, growsWithYou: g, applied: stage(4)) == stage(5))
        #expect(IconPlan.afterCelebration(hours: 5_000, totalHours: 5_010, growsWithYou: false, applied: stage(4)) == nil)
        #expect(IconPlan.afterCelebration(hours: 500, totalHours: 520, growsWithYou: g, applied: stage(0)) == nil)
    }

    @Test func aThousandWithoutCelebrationChangesWhenTheSheetCloses() {
        // 3,000 crossed: nothing is pending, so the check made when the sheet has closed changes it.
        #expect(IconPlan.quietStage(totalHours: 3_010, growsWithYou: g, applied: stage(2), celebrationPending: false) == stage(3))
    }

    @Test func crossing2500ShowsACelebrationButKeepsTheIcon() {
        // 2,450 → 2,520: still stage 2, so nothing changes, before or after the celebration.
        #expect(IconPlan.quietStage(totalHours: 2_520, growsWithYou: g, applied: stage(2), celebrationPending: true) == nil)
        #expect(IconPlan.afterCelebration(hours: 2_500, totalHours: 2_520, growsWithYou: g, applied: stage(2)) == nil)
        #expect(IconPlan.afterCelebration(hours: 7_500, totalHours: 7_520, growsWithYou: g, applied: stage(7)) == nil)
    }

    @Test func aBigJumpGoesStraightToTheHighestStageWithOneChange() {
        // 1,200 → 4,300: crosses 2,000, 3,000, 4,000 and the 2,500 celebration. The change waits for the celebration…
        let crossed = Milestones.newlyCrossed(total: 4_300, seen: [100, 500, 1_000])
        #expect(crossed == [2_500])
        #expect(IconPlan.quietStage(totalHours: 4_300, growsWithYou: g, applied: stage(1), celebrationPending: true) == nil)
        // …and then goes to stage 4, not through 2 and 3.
        #expect(IconPlan.afterCelebration(hours: 2_500, totalHours: 4_300, growsWithYou: g, applied: stage(1)) == stage(4))
        // Without a celebration in the way the same jump is one change on sheet close.
        #expect(IconPlan.quietStage(totalHours: 4_300, growsWithYou: g, applied: stage(1), celebrationPending: false) == stage(4))
    }

    @Test func aSessionSavedFromTheWatchOrLiveActivityChangesTheIconWhenHomeNextAppears() {
        // The app was not active, so nothing was applied. On the next active / Home appearance the check runs.
        #expect(IconPlan.quietStage(totalHours: 6_050, growsWithYou: g, applied: stage(5), celebrationPending: false) == stage(6))
    }

    @Test func aLowerTotalLowersTheIconQuietly() {
        #expect(IconPlan.quietStage(totalHours: 20, growsWithYou: g, applied: stage(5), celebrationPending: false) == .start)
        #expect(IconPlan.quietStage(totalHours: 2_400, growsWithYou: g, applied: stage(3), celebrationPending: false) == stage(2))
        #expect(IconPlan.quietStage(totalHours: 2_400, growsWithYou: g, applied: stage(2), celebrationPending: false) == nil)
        // A lower stage is never held back.
        #expect(IconPlan.quietStage(totalHours: 10, growsWithYou: g, applied: stage(2), celebrationPending: true) == .start)
    }

    @Test func newUsersPastAThousandGetTheirStageOnce() {
        #expect(IconPlan.quietStage(totalHours: 3_200, growsWithYou: g, applied: .start, celebrationPending: false) == stage(3))
        // An unknown stored stage is set again.
        #expect(IconPlan.quietStage(totalHours: 3_200, growsWithYou: g, applied: nil, celebrationPending: false) == stage(3))
    }

    @Test func theSwitchOffAndOn() {
        #expect(IconPlan.wanted(totalHours: 3_000, growsWithYou: false) == .start)
        #expect(IconPlan.wanted(totalHours: 3_000, growsWithYou: true) == stage(3))
        // Off: the plain icon even though the applied stage is higher. On: the current stage again.
        #expect(IconPlan.quietStage(totalHours: 3_000, growsWithYou: false, applied: stage(3), celebrationPending: false) == .start)
        #expect(IconPlan.quietStage(totalHours: 3_000, growsWithYou: true, applied: .start, celebrationPending: false) == stage(3))
        // While it is off no celebration moves it.
        #expect(IconPlan.afterCelebration(hours: 5_000, totalHours: 5_100, growsWithYou: false, applied: stage(4)) == nil)
    }

    @Test func theSystemIsOnlyCalledWhenAllowed() {
        func call(_ wanted: IconStage, current: String? = nil, active: Bool = true, supports: Bool = true, timer: Bool = false) -> Bool {
            IconPlan.shouldCall(wanted: wanted, currentIconName: current, appActive: active,
                                supportsAlternateIcons: supports, timerRunning: timer)
        }
        #expect(call(stage(1)))
        #expect(call(.start, current: "AppIcon-1000"))
        #expect(!call(stage(1), current: "AppIcon-1000"))   // already showing
        #expect(!call(.start))                          // primary already showing
        #expect(!call(stage(1), active: false))
        #expect(!call(stage(1), supports: false))
        #expect(!call(stage(1), timer: true))                // never during a session
        #expect(!call(stage(3), timer: true))
    }
}
