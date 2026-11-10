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

                // The day scene, edge to edge, with the sun over the dunes and sea.
                SceneHero(tone: .day, height: 230, skyHeight: 190, horizon: 0.82, landTop: 110, sunSize: 120, sunTop: 10,
                          giggles: true, label: "The sun over the sea")
                    .padding(.horizontal, -24)

                VStack(spacing: 8) {
                    Text("Keep the sun shining")
                        .lgText(LGTextStyle(size: 28, weight: .bold, relativeTo: .title, tracking: -0.56))
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                    Text("Long Game is free, with no ads and no subscription, and it will stay that way. If it helps you play, you can leave a tip. Tips don’t unlock anything: every feature is free for everyone.")
                        .lgText(.note, color: LGColor.inkMuted).multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 6)
                }

                VStack(spacing: 0) {
                    ForEach(Array(TipTier.allCases.enumerated()), id: \.element) { index, tier in
                        row(tier)
                        if index < TipTier.allCases.count - 1 { Divider().overlay(LGColor.divider) }
                    }
                }
                .padding(.horizontal, 14)
                .lgCard(radius: 20)
                .padding(.top, 16)

                if let notice = tips.notice {
                    Text(notice == .waitingForApproval ? "Waiting for approval" : "Tips aren't available right now")
                        .lgText(.rowStrong, color: notice == .waitingForApproval ? LGColor.inkMuted : LGColor.danger)
                        .multilineTextAlignment(.center)
                        .padding(.top, 14)
                        .accessibilityAddTraits(.updatesFrequently)
                }

                Text("One-time payments through the App Store. Prices are shown in your currency.")
                    .lgText(LGTextStyle(size: 12, weight: .regular, relativeTo: .caption), color: LGColor.inkMuted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
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
                Text(tier.title).lgText(.rowStrong)
                Text(tier.line).lgText(LGTextStyle(size: 12, weight: .regular, relativeTo: .caption), color: LGColor.inkMuted)
            }
            Spacer(minLength: 8)
            Button {
                Task { await tips.buy(tier) }
            } label: {
                Group {
                    if let price { Text(price) }
                    else if tips.loading == .unavailable { Text("–") }
                    else { ProgressView().tint(LGColor.ink) }
                }
                .lgText(LGTextStyle(size: 14, weight: .semibold, relativeTo: .subheadline))
                .frame(minWidth: 40, minHeight: 34)
                .padding(.horizontal, 12)
                .background(LGColor.stepperButton, in: Capsule())
                .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .disabled(price == nil || tips.isPurchasing)
            .opacity(price == nil || tips.isPurchasing ? 0.4 : 1)
            .accessibilityLabel(price.map { "\(tier.spokenTitle), \($0)" } ?? tier.spokenTitle)
        }
        .frame(minHeight: 60)
    }
}
