import SwiftUI
import SwiftData

/// The sun over the sea with a small white circle holding the blue iCloud symbol. Also used by Welcome back.
struct ICloudIllustration: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            SunriseHero(layout: .intro(page: 0), label: "").accessibilityHidden(true)
            GeometryReader { geo in
                Image(systemName: "icloud.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(LGColor.icloud)
                    .frame(width: 52, height: 52)
                    .background(.white, in: Circle())
                    .shadow(color: LGColor.ink.opacity(0.12), radius: 8, y: 3)
                    .position(x: geo.size.width / 2 + 104, y: 52)
                    .accessibilityHidden(true)
            }
        }
        .frame(height: 300)
    }
}

/// Step 5 of 5, "Keep your game safe": one card with the Save to iCloud switch (on by default), and Start playing.
struct ICloudStepView: View {
    @Bindable var model: OnboardingModel
    /// Saves everything and opens Home on The long game.
    let onStart: () -> Void

    @Environment(ICloudMonitor.self) private var monitor

    private var state: ICloudSwitchState {
        ICloudSwitchState.make(availability: monitor.availability, wantsOn: model.saveToICloud)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingHeader(step: 5)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ICloudIllustration().padding(.top, 4)
                    Text("Keep your game safe").lgText(.screenTitle)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.top, 12)
                    card.padding(.top, 20)
                    Text("Private to your Apple Account. Only you can see it. No sign-in needed.")
                        .lgText(LGTextStyle(size: 13, weight: .regular, relativeTo: .footnote), color: LGColor.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 12).padding(.horizontal, 4)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            Button("Start playing", action: onStart).buttonStyle(.lg(.primary))
                .padding(.top, 8)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .lgScreen()
        .navigationBarBackButtonHidden()
    }

    private var card: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "icloud.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(LGColor.icloud)
                .frame(width: 40, height: 40)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text("Save to iCloud").lgText(.rowStrong)
                Text(state.showsSignInHint
                     ? "Sign in to iCloud in the Settings app to keep a copy."
                     : "On all your Apple devices, and back if you get a new iPhone.")
                    .lgText(.caption, color: LGColor.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Toggle("Save to iCloud", isOn: Binding(get: { state.isOn }, set: { model.saveToICloud = $0 }))
                .labelsHidden()
                .tint(LGColor.ink)
                .disabled(!state.isEnabled)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lgCard(radius: 20)
        .accessibilityElement(children: .contain)
    }
}

#Preview("Keep your game safe") {
    ICloudStepView(model: OnboardingModel()) {}
        .environment(ICloudMonitor())
}
