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
        // A refusal on "Bring the weather in?" shows the same line here.
        .onAppear { if !settings.weatherInScene && UserDefaults.standard.bool(forKey: WeatherSwitch.refusedKey) { refused = true } }
    }

    private func turn(_ on: Bool) {
        refused = false
        guard on else {
            WeatherSwitch.turnOff(settings: settings, save: save)
            return
        }
        Task { refused = !(await WeatherSwitch.turnOn(settings: settings, save: save)) }
    }
}

/// Turning Weather in the scene on or off, from the Settings switch or "Bring the weather in?" (update 53). The
/// location prompt is only ever shown from these two places.
@MainActor
enum WeatherSwitch {
    /// Set when location was refused, so Settings shows "Without your location…" under the switch.
    static let refusedKey = "weather.locationRefused"

    /// Asks for location; on yes the switch is on and the weather is fetched. Returns whether it was allowed.
    static func turnOn(settings: AppSettings, save: () -> Void) async -> Bool {
        if await LocationOnce.requestPermission() {
            settings.weatherInScene = true
            save()
            UserDefaults.standard.removeObject(forKey: refusedKey)
            await WeatherStore.shared.refreshIfDue(enabled: true)
            return true
        }
        settings.weatherInScene = false
        save()
        UserDefaults.standard.set(true, forKey: refusedKey)
        return false
    }

    static func turnOff(settings: AppSettings, save: () -> Void) {
        settings.weatherInScene = false
        WeatherStore.shared.clear()
        UserDefaults.standard.removeObject(forKey: refusedKey)
        save()
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
