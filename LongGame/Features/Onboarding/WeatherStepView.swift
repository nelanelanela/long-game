import SwiftUI

/// The last setup step, "The weather outside" (update 49, `design/redesign/OnboardingWeather.dc.html`): a small scene
/// with the rain layer and the sun resting its eyes, what the weather does and doesn't do, then Show the weather (the
/// system location prompt) or Not now. Both go on to Home. People who finished setup before never see it.
struct WeatherStepView: View {
    /// The total setup has worked out, for "Write to yourself at 100 hours".
    var letterTotal: Double = 0
    /// Called with true when location was allowed, false for Not now (or a refusal).
    let onFinish: (Bool) -> Void

    @Environment(\.onboardingStepCount) private var stepCount
    @State private var asking = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingHeader(step: stepCount)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ZStack(alignment: .topLeading) {
                        SceneHero(tone: .day, height: 196, skyHeight: 180, horizon: 0.72, landTop: 76,
                                  sunSize: 110, sunTop: 28, face: .focus, hidden: true)
                        GeometryReader { geo in
                            WeatherLayerView(layer: .rain, sun: CGPoint(x: geo.size.width / 2, y: 28 + 55), sunRadius: 34,
                                             horizonY: 196 * 0.72)
                        }
                    }
                    .frame(height: 196)
                    .accessibilityHidden(true)
                    .padding(.top, 4)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("The weather outside").lgText(.setupTitle)
                            .accessibilityAddTraits(.isHeader)
                            .padding(.top, 12)
                        Text("When it rains where you are, it can rain here too. Mist, wind, cloud and snow pass through quietly; on a clear day nothing changes.")
                            .lgText(LGTextStyle(size: 15, weight: .regular, relativeTo: .subheadline), color: LGColor.inkMuted)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 8)
                        card.padding(.top, 12)
                        Text("iPhone will ask for your location next. Change your mind any time in Settings.")
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
            Button("Show the weather", action: show)
                .buttonStyle(.lg(.primary))
                .padding(.top, 8)
            Button("Not now") { finish(false) }
                .buttonStyle(.lg(.text))
                .padding(.top, 4)
            // The first letter, at the end of setup: Home opens it.
            if let title = LetterOffer.title(total: letterTotal) {
                Button(title) {
                    UserDefaults.standard.set(true, forKey: LetterOffer.afterSetupKey)
                    finish(false)
                }
                .buttonStyle(.lg(.text))
            }
            LGBrandLine().padding(.top, 6)
        }
        .disabled(asking)
        .padding(.horizontal, 24)
        .padding(.bottom, 10)
        .lgScreen()
        .navigationBarBackButtonHidden()
    }

    private var card: some View {
        VStack(spacing: 0) {
            row(icon: "sun.horizon", title: "Only in the landscape",
                detail: "The sun's height and the sky still show your progress.")
            Divider().overlay(LGColor.divider)
            row(icon: "location", title: "Your rough area is enough",
                detail: "Used to ask Apple Weather a few times a day. Never saved, never shared.")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lgCard(radius: 20)
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
        .accessibilityElement(children: .combine)
    }

    /// The system location prompt is only ever shown from here or the Settings switch.
    private func show() {
        guard !asking else { return }
        asking = true
        Task {
            let allowed = await LocationOnce.requestPermission()
            finish(allowed)
        }
    }

    private func finish(_ allowed: Bool) {
        asking = true
        onFinish(allowed)
    }
}

#Preview("The weather outside") {
    WeatherStepView { _ in }
}
