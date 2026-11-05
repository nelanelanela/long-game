import Testing
import Foundation
import StoreKit
import StoreKitTest
@testable import LongGame

struct TipRulesTests {
    let cal = Calendar(identifier: .gregorian)
    let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
    func days(_ n: Int, before d: Date? = nil) -> Date { cal.date(byAdding: .day, value: -n, to: d ?? now)! }

    func offer(onboarded: Int = 100, lastOffer: Int? = nil, lastTip: Date? = nil, timer: Bool = false, ended: Date? = nil) -> Bool {
        TipRules.shouldOffer(now: now, onboardedAt: days(onboarded), lastOfferAt: lastOffer.map { days($0) }, lastTipAt: lastTip,
                             timerRunning: timer, lastSessionEndedAt: ended, calendar: cal)
    }

    @Test func needsFourteenDaysSinceOnboarding() {
        #expect(!offer(onboarded: 13))
        #expect(offer(onboarded: 14))
    }

    @Test func atMostOneOfferEveryNinetyDays() {
        #expect(!offer(lastOffer: 89))
        #expect(offer(lastOffer: 90))
    }

    @Test func quietForTwelveMonthsAfterATip() {
        #expect(!offer(lastTip: cal.date(byAdding: .month, value: -11, to: now)))
        #expect(offer(lastTip: cal.date(byAdding: .month, value: -12, to: now)))
    }

    @Test func notWhileATimerRunsOrJustFinished() {
        #expect(!offer(timer: true))
        #expect(!offer(ended: now.addingTimeInterval(-60)))
        #expect(offer(ended: now.addingTimeInterval(-3600)))
    }
}

@MainActor
struct TipPurchaseTests {
    func session() throws -> SKTestSession {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("LongGame.storekit")
        let s = try SKTestSession(contentsOf: url)
        s.resetToDefaultState()
        s.clearTransactions()
        s.disableDialogs = true
        return s
    }

    @Test func successThanksAndRecordsTheTip() async throws {
        _ = try session()
        let store = TipStore()
        var recorded = 0
        store.onTip = { _ in recorded += 1 }
        await store.loadProducts()
        #expect(store.price(for: .ray) != nil)
        await store.buy(.ray)
        #expect(store.showThanks)
        #expect(recorded == 1)
        #expect(store.notice == nil)
    }

    @Test func cancelledDoesNothing() async throws {
        let s = try session()
        try await s.setSimulatedError(.generic(.userCancelled), forAPI: .purchase)
        let store = TipStore()
        var recorded = 0
        store.onTip = { _ in recorded += 1 }
        await store.loadProducts()
        await store.buy(.morning)
        #expect(recorded == 0)
        #expect(!store.showThanks)
        #expect(store.notice == nil)
    }

    @Test func askToBuyWaitsForApproval() async throws {
        let s = try session()
        s.askToBuyEnabled = true
        let store = TipStore()
        var recorded = 0
        store.onTip = { _ in recorded += 1 }
        await store.loadProducts()
        await store.buy(.goldenhour)
        #expect(store.notice == .waitingForApproval)
        #expect(!store.showThanks)
        #expect(recorded == 0)
    }
}
