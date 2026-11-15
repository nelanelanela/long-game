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

    /// A small seeded generator, so drops, flakes and clouds sit in the same natural places every launch.
    struct Seeded {
        private var state: UInt64
        init(_ seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }
        mutating func next() -> Double {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Double(state >> 11) / Double(1 << 53)
        }
    }

    /// Three soft clouds high and to the sides, each moved clear of the sun's disc (plus a margin) wherever the sun is.
    /// `drift` (0…1) slides them slowly across.
    static func clouds(in size: CGSize, sun: CGPoint, sunRadius: CGFloat, drift: Double = 0) -> [CGRect] {
        var rng = Seeded(0xC10D)
        let clear = sunRadius * 1.25
        return (0..<3).map { i in
            let w = size.width * (0.26 + 0.1 * rng.next())
            let h = w * 0.36
            let baseX = [0.04, 0.62, 0.30][i] * size.width + CGFloat(rng.next()) * size.width * 0.06
            let x = (baseX + CGFloat(drift) * size.width * 0.18).truncatingRemainder(dividingBy: size.width + w) - w * 0.15
            var rect = CGRect(x: x, y: size.height * (0.06 + 0.1 * Double(i % 2)) + CGFloat(rng.next()) * 10, width: w, height: h)
            // Keep clear of the sun: move up, or sideways, until the cloud no longer touches its disc.
            var tries = 0
            while overlaps(rect, sun: sun, radius: clear), tries < 40 {
                rect.origin.x += rect.midX < sun.x ? -8 : 8
                if tries % 3 == 0, rect.minY > 0 { rect.origin.y = max(0, rect.origin.y - 6) }
                tries += 1
            }
            return rect
        }
    }

    /// Whether a cloud's oval touches a circle around the sun.
    static func overlaps(_ rect: CGRect, sun: CGPoint, radius: CGFloat) -> Bool {
        // Nearest point of the cloud's box to the sun's centre.
        let nx = min(max(sun.x, rect.minX), rect.maxX), ny = min(max(sun.y, rect.minY), rect.maxY)
        let dx = sun.x - nx, dy = sun.y - ny
        return dx * dx + dy * dy < radius * radius
    }
}
