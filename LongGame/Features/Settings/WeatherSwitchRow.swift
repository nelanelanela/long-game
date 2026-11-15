import SwiftUI
import WeatherKit

/// Settings › Weather in the scene (update 49). Off by default. Turning it on asks for location (approximate is
/// enough); a refusal puts the switch back with one line. Apple's weather attribution sits under it, as Apple asks.
struct WeatherSwitchRow: View {
    @Bindable var settings: AppSettings
    let save: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var refused = false
    @State private var attribution: WeatherAttribution?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Toggle("Weather in the scene", isOn: Binding(get: { settings.weatherInScene }, set: { turn($0) }))
                .lgText(.row).tint(LGColor.selectedFill)
            Text("Rain, mist and snow from outside your window")
                .lgText(.caption, color: LGColor.inkMuted)
            if refused {
                Text("Without your location the app can't see the weather.")
                    .lgText(.caption, color: LGColor.ember)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
            WeatherAttributionView(attribution: attribution, dark: colorScheme == .dark)
                .padding(.top, 8)
        }
        .padding(.vertical, 10)
        .task { attribution = try? await WeatherService.shared.attribution }
    }

    private func turn(_ on: Bool) {
        refused = false
        guard on else {
            settings.weatherInScene = false
            WeatherStore.shared.clear()
            save()
            return
        }
        Task {
            if await LocationOnce.requestPermission() {
                settings.weatherInScene = true
                save()
                await WeatherStore.shared.refreshIfDue(enabled: true)
            } else {
                settings.weatherInScene = false
                save()
                refused = true
            }
        }
    }
}

/// The Apple Weather mark and the legal link to the other data sources.
struct WeatherAttributionView: View {
    let attribution: WeatherAttribution?
    let dark: Bool

    var body: some View {
        if let attribution {
            HStack(spacing: 10) {
                AsyncImage(url: dark ? attribution.combinedMarkDarkURL : attribution.combinedMarkLightURL) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    Color.clear
                }
                .frame(height: 12)
                .accessibilityLabel(Text(verbatim: attribution.serviceName))
                Link(destination: attribution.legalPageURL) {
                    Text("Other data sources").lgText(.caption, color: LGColor.inkMuted).underline()
                        .frame(minHeight: 44)
                }
            }
        }
    }
}
