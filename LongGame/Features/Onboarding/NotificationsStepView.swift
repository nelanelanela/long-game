import SwiftUI

/// The day scene with the winking sun and a bell in a small white bubble beside it, as on Notifications.dc.html:
/// a 390 × 196 box.
struct NotificationsIllustration: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            SceneHero(tone: .day, height: 196, skyHeight: 180, horizon: 0.72, landTop: 76,
                      sunSize: 110, sunTop: 28, face: .wink, hidden: true)
            GeometryReader { geo in
                Image(systemName: "bell")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(LGColor.amber)
                    .frame(width: 52, height: 52)
                    .background {
                        Circle()
                            .fill(RadialGradient(colors: [.white, LGColor.bellBubble], center: UnitPoint(x: 0.35, y: 0.3),
                                                 startRadius: 0, endRadius: 36))
                            .shadow(color: LGColor.ink.opacity(0.16), radius: 12, y: 10)
                    }
                    .position(x: geo.size.width / 2 + 64, y: 40)
            }
        }
        .frame(height: 196)
        .accessibilityHidden(true)
    }
}

/// Step 6 of 6, "A gentle nudge": what each notification is, then Allow notifications (iOS's own prompt) or Not now.
/// Shown only while iOS has never asked (`OnboardingSteps.showsNotifications`).
struct NotificationsStepView: View {
    let craftName: String
    /// Called with true for Allow notifications, false for Not now. Asking iOS and finishing happen there.
    let onAnswer: (Bool) -> Void

    @State private var answering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingHeader(step: OnboardingSteps.number(of: .notifications))
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    NotificationsIllustration()
                        .padding(.top, 4)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("A gentle nudge").lgText(.setupTitle)
                            .accessibilityAddTraits(.isHeader)
                            .padding(.top, 12)
                        Text("Long Game can send you a few quiet notifications. Never ads, never streaks.")
                            .lgText(LGTextStyle(size: 15, weight: .regular, relativeTo: .subheadline), color: LGColor.inkMuted)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 8)
                        card.padding(.top, 12)
                        Text("Your session on the Lock Screen shows either way. Change your mind any time in Settings.")
                            .lgText(.caption, color: LGColor.inkMuted)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 12).padding(.horizontal, 4)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .padding(.horizontal, -24)
            Button("Allow notifications") { answer(true) }
                .buttonStyle(.lg(.primary))
                .padding(.top, 8)
            Button("Not now") { answer(false) }
                .buttonStyle(.lg(.text))
                .padding(.top, 4)
            LGBrandLine().padding(.top, 6)
        }
        .disabled(answering)
        .padding(.horizontal, 24)
        .padding(.bottom, 10)
        .lgScreen()
        .navigationBarBackButtonHidden()
    }

    /// One tap only: iOS's prompt takes a moment to appear, and a second tap must not finish twice.
    private func answer(_ allow: Bool) {
        guard !answering else { return }
        answering = true
        onAnswer(allow)
    }

    private var card: some View {
        VStack(spacing: 0) {
            row(icon: "star", title: "Milestones",
                detail: "“1,000 hours of \(displayCraft). Sunrise is coming.”")
            Divider().overlay(LGColor.divider)
            row(icon: "clock", title: "A long-session check",
                detail: "“Still practising?” after 4 hours, so a forgotten timer doesn’t count.")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lgCard(radius: 20)
    }

    /// The craft as the milestone message names it, in lower case as in the reminder; "piano" before a name is known.
    private var displayCraft: String {
        let name = craftName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "piano" : name.lowercased()
    }

    private func row(icon: String, title: LocalizedStringKey, detail: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(LGColor.ember)
                .frame(width: 36, height: 36)
                .background(LGColor.peachWashSetup, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).lgText(LGTextStyle(size: 15, weight: .semibold, relativeTo: .subheadline))
                Text(detail)
                    .lgText(.caption, color: LGColor.inkMuted)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
        // Read as one sentence pair: "Milestones. 1,000 hours of piano…".
        .accessibilityElement(children: .combine)
    }
}

#Preview("A gentle nudge") {
    NotificationsStepView(craftName: "piano") { _ in }
}

#Preview("A gentle nudge, smallest text") {
    NotificationsStepView(craftName: "piano") { _ in }
        .dynamicTypeSize(.xSmall)
}

#Preview("A gentle nudge, largest text") {
    NotificationsStepView(craftName: "piano") { _ in }
        .dynamicTypeSize(.accessibility5)
}
