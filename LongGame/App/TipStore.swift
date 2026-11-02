import Foundation
import Observation
import StoreKit
import SwiftData

/// The whole tip jar's store code. Tips are consumable purchases through the App Store only:
/// no server, no account, nothing unlocked. Listens for transactions from app launch, so a tip that was
/// waiting for approval (Ask to Buy) or interrupted is still thanked for and finished.
@MainActor
@Observable
final class TipStore {
    enum Loading: Equatable { case idle, loading, loaded, unavailable }
    enum Notice: Equatable { case waitingForApproval, unavailable }

    private(set) var products: [String: Product] = [:]
    private(set) var loading: Loading = .idle
    private(set) var isPurchasing = false
    var notice: Notice?
    /// The thank-you sheet is showing.
    var showThanks = false
    /// Called once for each completed tip (the app saves `lastTipAt` and `tipCount`).
    @ObservationIgnored var onTip: ((Date) -> Void)?

    @ObservationIgnored private var updatesTask: Task<Void, Never>?
    @ObservationIgnored private var handled: Set<UInt64> = []

    /// Starts listening for transactions and saves tips into Settings. Safe to call more than once.
    func start(context: ModelContext) {
        onTip = { date in
            let settings: AppSettings
            if let existing = (try? context.fetch(FetchDescriptor<AppSettings>()))?.first {
                settings = existing
            } else {
                settings = AppSettings()
                context.insert(settings)
            }
            settings.lastTipAt = date
            settings.tipCount += 1
            try? context.save()
        }
        listen()
    }

    /// Transactions that arrive outside a purchase: approved Ask to Buy, or interrupted ones from last time.
    func listen() {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.finish(result, thankYou: true)
            }
        }
    }

    func loadProducts() async {
        guard loading != .loading else { return }
        loading = .loading
        do {
            let found = try await Product.products(for: TipTier.allCases.map(\.id))
            products = Dictionary(uniqueKeysWithValues: found.map { ($0.id, $0) })
            loading = products.isEmpty ? .unavailable : .loaded
        } catch {
            loading = .unavailable
        }
    }

    /// The price exactly as the App Store shows it in the user's currency.
    func price(for tier: TipTier) -> String? { products[tier.id]?.displayPrice }

    func buy(_ tier: TipTier) async {
        guard !isPurchasing, let product = products[tier.id] else { return }
        isPurchasing = true
        notice = nil
        defer { isPurchasing = false }
        do {
            switch try await product.purchase() {
            case .success(let result): await finish(result, thankYou: true)
            case .userCancelled: break
            case .pending: notice = .waitingForApproval
            @unknown default: notice = .unavailable
            }
        } catch {
            notice = .unavailable
        }
    }

    private func finish(_ result: VerificationResult<Transaction>, thankYou: Bool) async {
        guard case .verified(let transaction) = result else {
            notice = .unavailable
            return
        }
        await transaction.finish()
        guard handled.insert(transaction.id).inserted else { return }
        onTip?(transaction.purchaseDate)
        notice = nil
        if thankYou { showThanks = true }
    }
}
