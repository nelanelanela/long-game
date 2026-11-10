import SwiftUI
import SwiftData

/// The day scene (sun over the dunes and sea) with a small white circle holding the blue iCloud outline, as on
/// ICloud.dc.html: a 390 × 270 box.
struct ICloudIllustration: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            SceneHero(tone: .day, height: 270, skyHeight: 250, horizon: 0.78, landTop: 150,
                      sunSize: 140, sunTop: 56, hidden: true)
            GeometryReader { geo in
                Image(systemName: "icloud")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundStyle(LGColor.icloud)
                    .frame(width: 60, height: 60)
                    .background {
                        Circle()
                            .fill(RadialGradient(colors: [.white, Color(hex: 0xEEF2FB)], center: UnitPoint(x: 0.35, y: 0.3),
                                                 startRadius: 0, endRadius: 42))
                            .shadow(color: LGColor.ink.opacity(0.16), radius: 12, y: 10)
                    }
                    .position(x: geo.size.width / 2 + 76, y: 60)
                    .accessibilityHidden(true)
            }
        }
        .frame(height: 270)
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
                    ICloudIllustration()
                        .padding(.top, 8)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Keep your game safe").lgText(.setupTitle)
                            .accessibilityAddTraits(.isHeader)
                            .padding(.top, 16)
                        card.padding(.top, 16)
                        Text("Private to your Apple Account. Only you can see it. No sign-in needed.")
                            .lgText(LGTextStyle(size: 13, weight: .regular, relativeTo: .footnote), color: LGColor.inkMuted)
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
            Button("Start playing", action: onStart).buttonStyle(.lg(.primary))
                .padding(.top, 8)
            LGBrandLine().padding(.top, 12)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 10)
        .lgScreen()
        .navigationBarBackButtonHidden()
    }

    private var card: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "icloud")
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(LGColor.icloud)
                .frame(width: 44, height: 44)
                .background(LGColor.icloudTile, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Save to iCloud").lgText(LGTextStyle(size: 16, weight: .semibold, relativeTo: .body))
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
