import SwiftUI

/// "Bring the weather in?" (updates 53 and 56, `design/redesign/WeatherInvite.dc.html`): the weather question, once, a week
/// after setup and right after a saved session, instead of a setup step. A small rainy scene with the sun resting its
/// eyes, what the weather does and doesn't do, then Show the weather (the system location prompt, then the Settings
/// switch on, as the switch itself does) or Not now. Either way it is never shown again (recorded on opening).
struct WeatherInviteSheet: View {
    let settings: AppSettings?
    let save: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var asking = false

    var body: some View {
        FittedSheet {
            VStack(alignment: .leading, spacing: 0) {
                // A small rainy scene: the sun resting its eyes behind the dunes, a faint navy veil, rain.
                ZStack(alignment: .topLeading) {
                    SceneHero(tone: .day, height: 150, skyHeight: 140, horizon: 0.72, landTop: 36,
                              sunSize: 90, sunTop: 18, face: .sleepy, moon: false, hidden: true)
                    LGColor.navy.opacity(0.1)
                    GeometryReader { geo in
                        WeatherLayerView(layer: .rain, sun: CGPoint(x: geo.size.width / 2, y: 18 + 45), sunRadius: 28,
                                         horizonY: 150 * 0.72)
                    }
                }
                .frame(height: 150)
                .clipped()
                .accessibilityHidden(true)
                .padding(.top, 26)

                VStack(alignment: .leading, spacing: 0) {
                    Text("Bring the weather in?").lgText(.askTitle)
                        .accessibilityAddTraits(.isHeader)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 14)
                    Text("You’ve been playing for a week now. When it rains where you are, it can rain here too. Mist, wind, cloud and snow pass through quietly.")
                        .lgText(LGTextStyle(size: 15, weight: .regular, relativeTo: .subheadline), color: LGColor.inkMuted)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 8)
                    VStack(spacing: 0) {
                        AskRow(icon: "cloud.rain", title: "Only the scenery changes",
                               detail: "The sun’s height and the sky still show your progress.")
                        Divider().overlay(LGColor.divider)
                        AskRow(icon: "mappin", title: "Your rough area is enough",
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
                    Button("Show the weather", action: show).buttonStyle(.lg(.primary))
                        .padding(.top, 14)
                    Button("Not now") { dismiss() }.buttonStyle(.lg(.text))
                        .padding(.top, 4)
                }
                .disabled(asking)
                .padding(.horizontal, 24)
                .padding(.bottom, 4)  // the sheet's own safe area sits under it
            }
        }
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
