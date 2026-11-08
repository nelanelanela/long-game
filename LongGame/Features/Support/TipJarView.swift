import SwiftUI

/// "Support Long Game": four optional tips. Nothing is unlocked by any of them.
struct TipJarView: View {
    /// Shown as a sheet from Home instead of pushed from Settings.
    var isSheet = false

    @Environment(TipStore.self) private var tips
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        @Bindable var tips = tips
        ScrollView {
            VStack(spacing: 0) {
                HStack {
                    LGIconButton(systemName: isSheet ? "xmark" : "chevron.left", label: isSheet ? "Close" : "Back") { dismiss() }
                        .padding(.leading, -10)
                    Spacer()
                }
                .frame(height: 44)

                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { timeline in
                    let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                    let breathe = sin(t / 4 * 2 * .pi)
                    SunView(idle: false, face: .happy, raysRotation: .degrees(t.truncatingRemainder(dividingBy: 90) / 90 * 360))
                        .frame(width: 120, height: 120)
                        .scaleEffect(1 + 0.015 * (breathe + 1))
                        .offset(y: -1.5 * (breathe + 1))
                }
                .padding(.top, 8)

                VStack(spacing: 10) {
                    Text("Keep the sun shining").lgText(.screenTitle).multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                    Text("Long Game is free, with no ads and no subscription, and it will stay that way. If it helps you play, you can leave a tip to support it. Tips don’t unlock anything: every feature is free for everyone.")
                        .lgText(.body, color: LGColor.inkMuted).multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 14)

                VStack(spacing: 0) {
                    ForEach(Array(TipTier.allCases.enumerated()), id: \.element) { index, tier in
                        row(tier)
                        if index < TipTier.allCases.count - 1 { Divider().overlay(LGColor.divider) }
                    }
                }
                .padding(.horizontal, 16)
                .lgCard()
                .padding(.top, 24)

                if let notice = tips.notice {
                    Text(notice == .waitingForApproval ? "Waiting for approval" : "Tips aren't available right now")
                        .lgText(.rowStrong, color: notice == .waitingForApproval ? LGColor.inkMuted : LGColor.danger)
                        .multilineTextAlignment(.center)
                        .padding(.top, 14)
                        .accessibilityAddTraits(.updatesFrequently)
                }

                Text("One-time payments through the App Store. Prices are shown in your currency.")
                    .lgText(.caption, color: LGColor.inkMuted).multilineTextAlignment(.center)
                    .padding(.top, 24)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .lgScreen()
        .lgHidesNavigationBar()
        .task { await tips.loadProducts() }
        .sheet(isPresented: $tips.showThanks) {
            TipThanksSheet { tips.showThanks = false; if isSheet { dismiss() } }
                .presentationDetents([.medium, .large])
        }
    }

    private func row(_ tier: TipTier) -> some View {
        let price = tips.price(for: tier)
        return HStack(spacing: 14) {
            TipSunIcon(tier: tier)
            VStack(alignment: .leading, spacing: 2) {
                Text(tier.title).lgText(.button)
                Text(tier.line).lgText(.caption, color: LGColor.inkMuted)
            }
            Spacer(minLength: 8)
            Button {
                Task { await tips.buy(tier) }
            } label: {
                Group {
                    if let price { Text(price) }
                    else if tips.loading == .unavailable { Text("–") }
                    else { ProgressView().tint(.white) }
                }
                .lgText(.rowStrong, color: .white)
                .frame(minWidth: 72, minHeight: 36)
                .padding(.horizontal, 14)
                .background(LGColor.ink, in: Capsule())
                .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .disabled(price == nil || tips.isPurchasing)
            .opacity(price == nil || tips.isPurchasing ? 0.4 : 1)
            .accessibilityLabel(price.map { "\(tier.spokenTitle), \($0)" } ?? tier.spokenTitle)
        }
        .frame(minHeight: 68)
    }
}
