import Foundation
import CoreLocation
import WeatherKit
import Observation
import OSLog

/// Weather in the scene (update 49). Asks for the current weather at most once every 3 hours, only when Home appears
/// and only while the Settings switch is on. Keeps the last layer and when it was fetched; never the location.
@MainActor
@Observable
final class WeatherStore {
    static let shared = WeatherStore()

    private enum Key {
        static let layer = "weather.layer"
        static let fetchedAt = "weather.fetchedAt"
        static let forced = "debug.forceWeather"
    }

    /// The layer Home draws (nil: the scene as it is).
    private(set) var layer: WeatherLayer?
    private var fetching = false
    /// One line per fetch in Xcode's console (Release too): what the sky was, or why it failed. Never the location.
    private static let log = Logger(subsystem: "com.wehavesun.LongGame", category: "Weather")

    init() {
        layer = UserDefaults.standard.string(forKey: Key.layer).flatMap(WeatherLayer.init(rawValue:))
    }

    /// What Home shows: the forced layer in a debug build, else the last fetched one, and nothing when switched off.
    func shown(enabled: Bool) -> WeatherLayer? {
        #if DEBUG
        if let forced = UserDefaults.standard.string(forKey: Key.forced) {
            return forced == "none" ? nil : WeatherLayer(rawValue: forced)
        }
        #endif
        return enabled ? layer : nil
    }

    #if DEBUG
    /// Settings › Debug only: draw this layer whatever the weather (nil: back to the real one).
    static func force(_ layer: WeatherLayer?) {
        if let layer { UserDefaults.standard.set(layer.rawValue, forKey: Key.forced) }
        else { UserDefaults.standard.removeObject(forKey: Key.forced) }
        shared.layer = shared.layer   // redraw
    }
    #endif

    /// Called when Home appears. Says nothing on any failure: the scene simply stays as it is.
    func refreshIfDue(enabled: Bool) async {
        let last = UserDefaults.standard.object(forKey: Key.fetchedAt) as? Date
        guard !fetching, SceneWeather.shouldFetch(lastFetch: last, now: Date(), enabled: enabled),
              LocationOnce.isAllowed else { return }
        fetching = true
        defer { fetching = false }
        guard let location = await LocationOnce.current() else {
            Self.log.notice("Weather: no location this time")
            return
        }
        do {
            let current = try await WeatherService.shared.weather(for: location, including: .current)
            let reading = WeatherReading(sky: Self.sky(current.condition),
                                         windKmh: current.wind.speed.converted(to: .kilometersPerHour).value)
            layer = SceneWeather.current(weather: reading)
            Self.log.notice("Weather fetched: \(String(describing: reading.sky), privacy: .public), wind \(Int(reading.windKmh), privacy: .public) km/h, layer \(self.layer?.rawValue ?? "none", privacy: .public)")
            UserDefaults.standard.set(layer?.rawValue, forKey: Key.layer)
            UserDefaults.standard.set(Date(), forKey: Key.fetchedAt)
        } catch {
            // No network or no service: keep the scene as it is, quietly.
            Self.log.error("Weather fetch failed: \(String(describing: error), privacy: .public)")
        }
    }

    /// Switched off: forget the last layer too.
    func clear() {
        layer = nil
        UserDefaults.standard.removeObject(forKey: Key.layer)
        UserDefaults.standard.removeObject(forKey: Key.fetchedAt)
    }

    static func sky(_ c: WeatherCondition) -> WeatherReading.Sky {
        switch c {
        case .clear, .mostlyClear, .hot, .frigid: .clear
        case .partlyCloudy: .partlyCloudy
        case .mostlyCloudy: .mostlyCloudy
        case .cloudy: .overcast
        case .drizzle: .drizzle
        case .rain, .heavyRain, .sunShowers, .isolatedThunderstorms, .scatteredThunderstorms, .strongStorms, .thunderstorms,
             .freezingRain, .freezingDrizzle, .tropicalStorm, .hurricane: .rain
        case .snow, .heavySnow, .flurries, .sunFlurries, .blizzard, .blowingSnow: .snow
        case .sleet, .wintryMix, .hail: .sleet
        case .foggy: .fog
        case .haze, .smoky, .blowingDust: .haze
        case .breezy, .windy: .clear
        @unknown default: .other
        }
    }
}

/// One approximate location, asked for only from the Settings switch or the onboarding step.
@MainActor
final class LocationOnce: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var authContinuation: CheckedContinuation<Bool, Never>?
    private var locationContinuation: CheckedContinuation<CLLocation?, Never>?
    private static var active: LocationOnce?

    static var isAllowed: Bool { allowed(CLLocationManager().authorizationStatus) }

    nonisolated static func allowed(_ status: CLAuthorizationStatus) -> Bool {
        #if os(macOS)
        status == .authorizedAlways
        #else
        status == .authorizedWhenInUse || status == .authorizedAlways
        #endif
    }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyReduced
    }

    /// Shows the system prompt if iOS hasn't asked yet; true when location is allowed.
    static func requestPermission() async -> Bool {
        let once = LocationOnce()
        active = once
        defer { active = nil }
        let status = once.manager.authorizationStatus
        if allowed(status) { return true }
        switch status {
        case .denied, .restricted: return false
        default:
            return await withCheckedContinuation { c in
                once.authContinuation = c
                once.manager.requestWhenInUseAuthorization()
            }
        }
    }

    /// The device's rough location, or nil.
    static func current() async -> CLLocation? {
        let once = LocationOnce()
        active = once
        defer { active = nil }
        return await withCheckedContinuation { c in
            once.locationContinuation = c
            once.manager.requestLocation()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        MainActor.assumeIsolated {
            guard status != .notDetermined, let c = authContinuation else { return }
            authContinuation = nil
            c.resume(returning: Self.allowed(status))
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let last = locations.last
        MainActor.assumeIsolated {
            locationContinuation?.resume(returning: last)
            locationContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        MainActor.assumeIsolated {
            locationContinuation?.resume(returning: nil)
            locationContinuation = nil
        }
    }
}
