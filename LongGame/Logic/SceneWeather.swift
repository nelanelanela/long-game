import Foundation
import CoreGraphics

/// Weather in the scene (update 49): one quiet layer over Home's landscape, or none. The sky's colour, the sun's
/// height and its lit rays never change with it.
enum WeatherLayer: String, CaseIterable, Sendable {
    case cloud, rain, wind, mist, snow

    /// "light rain", for VoiceOver ("Sunrise scene, light rain").
    var spoken: String {
        switch self {
        case .cloud: String(localized: "cloudy")
        case .rain: String(localized: "light rain")
        case .wind: String(localized: "windy")
        case .mist: String(localized: "mist")
        case .snow: String(localized: "snow")
        }
    }
}

/// What the weather service said, reduced to what the scene needs.
struct WeatherReading: Equatable, Sendable {
    enum Sky: Sendable { case clear, partlyCloudy, mostlyCloudy, overcast, rain, drizzle, snow, sleet, fog, mist, haze, other }
    var sky: Sky
    /// Wind speed in km/h.
    var windKmh: Double
}

enum SceneWeather {
    /// How much faster the shoreline and the water's lines sway in wind.
    static let windSway = 2.4

    /// The wind that sways the scene.
    static let windyKmh = 40.0
    /// Weather is fetched at most this often.
    static let refresh: TimeInterval = 3 * 3600

    /// One layer at a time, in this order: snow, rain, mist, wind, cloud. Clear, partly cloudy and no data: none.
    static func current(weather: WeatherReading?, enabled: Bool = true) -> WeatherLayer? {
        guard enabled, let w = weather else { return nil }
        switch w.sky {
        case .snow, .sleet: return .snow
        case .rain, .drizzle: return .rain
        case .fog, .mist, .haze: return .mist
        default: break
        }
        if w.windKmh >= windyKmh { return .wind }
        if w.sky == .mostlyCloudy || w.sky == .overcast { return .cloud }
        return nil
    }

    /// Whether Home may ask for the weather again: never before 3 hours since the last fetch.
    static func shouldFetch(lastFetch: Date?, now: Date, enabled: Bool) -> Bool {
        guard enabled else { return false }
        guard let lastFetch else { return true }
        return now.timeIntervalSince(lastFetch) >= refresh || now < lastFetch
    }

    // MARK: Seeded positions

    /// A small seeded generator, so drops and flakes sit in the same natural places every launch.
    struct Seeded {
        private var state: UInt64
        init(_ seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }
        mutating func next() -> Double {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Double(state >> 11) / Double(1 << 53)
        }
    }

    /// Whether a box touches a circle around the sun.
    static func overlaps(_ rect: CGRect, sun: CGPoint, radius: CGFloat) -> Bool {
        // Nearest point of the cloud's box to the sun's centre.
        let nx = min(max(sun.x, rect.minX), rect.maxX), ny = min(max(sun.y, rect.minY), rect.maxY)
        let dx = sun.x - nx, dy = sun.y - ny
        return dx * dx + dy * dy < radius * radius
    }
}
