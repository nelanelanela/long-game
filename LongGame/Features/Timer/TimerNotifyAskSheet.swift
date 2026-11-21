import SwiftUI

/// "Lost in your work?" (update 53, `design/redesign/TimerNotifyAsk.dc.html`): the notification question, asked once,
/// over the first running session instead of during setup. The timer keeps running underneath. Allow notifications
/// shows iOS's prompt and, if allowed, plans the 4-hour "Still practising?" for the session already running.
/// Not now, or a swipe down, closes it. Either way it is never shown again (the presenter records that on opening).
struct TimerNotifyAskSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulsing = false
    @State private var answering = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Circle().fill(LGColor.amber)
                        .frame(width: 8, height: 8)
                        .scaleEffect(pulsing ? 1.35 : 1)
                        .opacity(pulsing ? 0.55 : 1)
                        .accessibilityHidden(true)
                    Text("Your first session is running")
                        .lgText(LGTextStyle(size: 13, weight: .semibold, relativeTo: .footnote), color: LGColor.ember)
                }
                .padding(.top, 28)

                HStack(alignment: .center, spacing: 14) {
                    SunView(idle: false, face: .wink)
                        .frame(width: 64, height: 64)
                        .accessibilityHidden(true)
                    Text("Lost in your work?").lgText(.setupTitle)
                        .accessibilityAddTraits(.isHeader)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 14)

                Text("It happens to everyone: you get absorbed in what you’re making and forget to stop the timer.")
                    .lgText(LGTextStyle(size: 15, weight: .regular, relativeTo: .subheadline), color: LGColor.inkMuted)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 12)

                VStack(spacing: 0) {
                    AskRow(icon: "bell", title: "We’ll tap you on the shoulder",
                           detail: "After 4 hours, a quiet “Still practising?”, so you can stop it.")
                    Divider().overlay(LGColor.divider)
                    AskRow(icon: "pencil", title: "You can always fix the time",
                           detail: "Change a session’s length when you finish, or later in History.")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lgCard(radius: 20)
                .padding(.top, 16)

                Text("Only a few quiet notifications: this check and your milestones. Never ads, never streaks.")
                    .lgText(.caption, color: LGColor.inkMuted)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 12).padding(.horizontal, 4)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 4) {
                Button("Allow notifications", action: allow).buttonStyle(.lg(.primary))
                Button("Not now") { dismiss() }.buttonStyle(.lg(.text))
            }
            .disabled(answering)
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 8)
            .background(LGColor.background.opacity(0.94))
        }
        .lgScreen()
        .presentationDragIndicator(.visible)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { pulsing = true }
        }
    }

    /// iOS's own prompt; if allowed, the running session gets its 4-hour check now (it was dropped quietly when the
    /// timer started without permission).
    private func allow() {
        guard !answering else { return }
        answering = true
        UserDefaults.standard.set(true, forKey: Notifications.askedKey)
        Task { @MainActor in
            if await Notifications.requestAuthorization() {
                Notifications.scheduleLongSession(at: TimerStore.shared.state?.longSessionDate(at: Date()))
            }
            dismiss()
        }
    }
}

/// An icon on a peach tile, a bold line and a muted one: the rows of the ask sheets (also the weather invite).
struct AskRow: View {
    let icon: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey

    var body: some View {
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
        .accessibilityElement(children: .combine)
    }
}

extension View {
    /// The first session's notification question, when it is due. Recorded as shown the moment it opens.
    func lgNotifyAsk(isPresented: Binding<Bool>) -> some View {
        sheet(isPresented: isPresented) {
            TimerNotifyAskSheet()
                .presentationDetents([.fraction(0.8), .large])
                .lgSheetCard()
                .lgAppLook()
        }
    }
}

/// Decides whether "Lost in your work?" is due and records that it was shown.
@MainActor
enum NotificationAskCheck {
    /// True when the ask should open now; marks it shown in Settings so it never opens again.
    static func take(settings: AppSettings?, sessionRunning: Bool, save: () -> Void) async -> Bool {
        guard let settings, !settings.notificationAskShown, sessionRunning else { return false }
        #if DEBUG
        // UI tests that open one screen: never cover it (it has its own route, "notifyAsk").
        if UITestLaunch.screen != nil { return false }
        #endif
        let permission = await Notifications.permission()
        guard NotificationAskRule.shouldShow(alreadyShown: settings.notificationAskShown, permission: permission,
                                             sessionRunning: sessionRunning) else { return false }
        settings.notificationAskShown = true
        save()
        return true
    }
}

#Preview("Lost in your work?") {
    Color.black.sheet(isPresented: .constant(true)) { TimerNotifyAskSheet() }
}

#Preview("Lost in your work? · dark, AX5") {
    Color.black.sheet(isPresented: .constant(true)) {
        TimerNotifyAskSheet().preferredColorScheme(.dark).dynamicTypeSize(.accessibility5)
    }
}
