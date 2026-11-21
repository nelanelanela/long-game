import SwiftUI

/// "Bring the weather in?" (update 53, `design/redesign/WeatherInvite.dc.html`): the weather question, once, a week
/// after setup and right after a saved session, instead of a setup step. A small rainy scene with the sun resting its
/// eyes, what the weather does and doesn't do, then Show the weather (the system location prompt, then the Settings
/// switch on, as the switch itself does) or Not now. Either way it is never shown again (recorded on opening).
struct WeatherInviteSheet: View {
    let settings: AppSettings?
    let save: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var asking = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topLeading) {
                    SceneHero(tone: .day, height: 176, skyHeight: 160, horizon: 0.72, landTop: 60,
                              sunSize: 100, sunTop: 26, face: .sleepy, moon: false, hidden: true)
                    GeometryReader { geo in
                        WeatherLayerView(layer: .rain, sun: CGPoint(x: geo.size.width / 2, y: 26 + 50), sunRadius: 31,
                                         horizonY: 176 * 0.72)
                    }
                }
                .frame(height: 176)
                .clipped()
                .accessibilityHidden(true)
                .padding(.top, 20)

                VStack(alignment: .leading, spacing: 0) {
                    Text("Bring the weather in?").lgText(.setupTitle)
                        .accessibilityAddTraits(.isHeader)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 12)
                    Text("You’ve been playing for a week now. When it rains where you are, it can rain here too. Mist, wind, cloud and snow pass through quietly.")
                        .lgText(LGTextStyle(size: 15, weight: .regular, relativeTo: .subheadline), color: LGColor.inkMuted)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 8)
                    VStack(spacing: 0) {
                        AskRow(icon: "sun.horizon", title: "Only in the landscape",
                               detail: "The sun's height and the sky still show your progress.")
                        Divider().overlay(LGColor.divider)
                        AskRow(icon: "location", title: "Your rough area is enough",
                               detail: "Used to ask Apple Weather a few times a day. Never saved, never shared.")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lgCard(radius: 20)
                    .padding(.top, 12)
                    Text("iPhone will ask for your location next. You’ll find it in Settings any time.")
                        .lgText(.caption, color: LGColor.inkMuted)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 12).padding(.horizontal, 4)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 4) {
                Button("Show the weather", action: show).buttonStyle(.lg(.primary))
                Button("Not now") { dismiss() }.buttonStyle(.lg(.text))
            }
            .disabled(asking)
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 8)
            .background(LGColor.background.opacity(0.94))
        }
        .lgScreen()
        .presentationDragIndicator(.visible)
    }

    /// The system location prompt is only ever shown from here or the Settings switch.
    private func show() {
        guard !asking, let settings else { dismiss(); return }
        asking = true
        Task { @MainActor in
            _ = await WeatherSwitch.turnOn(settings: settings, save: save)
            dismiss()
        }
    }
}

#Preview("Bring the weather in?") {
    Color.clear.sheet(isPresented: .constant(true)) { WeatherInviteSheet(settings: nil) {} }
}

#Preview("Bring the weather in? · dark, AX5") {
    Color.clear.sheet(isPresented: .constant(true)) {
        WeatherInviteSheet(settings: nil) {}.preferredColorScheme(.dark).dynamicTypeSize(.accessibility5)
    }
}
