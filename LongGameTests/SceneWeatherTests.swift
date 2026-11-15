import Testing
import Foundation
import CoreGraphics
@testable import LongGame

// Update 49: weather in the scene.

struct SceneWeatherTests {
    private func w(_ sky: WeatherReading.Sky, wind: Double = 5) -> WeatherReading { .init(sky: sky, windKmh: wind) }

    @Test func eachLayersCondition() {
        #expect(SceneWeather.current(weather: w(.mostlyCloudy)) == .cloud)
        #expect(SceneWeather.current(weather: w(.overcast)) == .cloud)
        #expect(SceneWeather.current(weather: w(.rain)) == .rain)
        #expect(SceneWeather.current(weather: w(.drizzle)) == .rain)
        #expect(SceneWeather.current(weather: w(.clear, wind: 40)) == .wind)
        #expect(SceneWeather.current(weather: w(.clear, wind: 39.9)) == nil)
        #expect(SceneWeather.current(weather: w(.fog)) == .mist)
        #expect(SceneWeather.current(weather: w(.mist)) == .mist)
        #expect(SceneWeather.current(weather: w(.haze)) == .mist)
        #expect(SceneWeather.current(weather: w(.snow)) == .snow)
        #expect(SceneWeather.current(weather: w(.sleet)) == .snow)
    }

    @Test func clearPartlyCloudyAndNoDataShowNothing() {
        #expect(SceneWeather.current(weather: w(.clear)) == nil)
        #expect(SceneWeather.current(weather: w(.partlyCloudy)) == nil)
        #expect(SceneWeather.current(weather: nil) == nil)
    }

    @Test func orderOfPreference() {
        // Snow beats wind; rain beats wind; mist beats wind; wind beats cloud.
        #expect(SceneWeather.current(weather: w(.snow, wind: 60)) == .snow)
        #expect(SceneWeather.current(weather: w(.rain, wind: 60)) == .rain)
        #expect(SceneWeather.current(weather: w(.fog, wind: 60)) == .mist)
        #expect(SceneWeather.current(weather: w(.overcast, wind: 60)) == .wind)
    }

    @Test func nothingWhenSwitchedOff() {
        #expect(SceneWeather.current(weather: w(.rain), enabled: false) == nil)
        #expect(!SceneWeather.shouldFetch(lastFetch: nil, now: Date(), enabled: false))
    }

    @Test func atMostEveryThreeHours() {
        let now = Date()
        #expect(SceneWeather.shouldFetch(lastFetch: nil, now: now, enabled: true))
        #expect(!SceneWeather.shouldFetch(lastFetch: now.addingTimeInterval(-2 * 3600), now: now, enabled: true))
        #expect(!SceneWeather.shouldFetch(lastFetch: now.addingTimeInterval(-3 * 3600 + 1), now: now, enabled: true))
        #expect(SceneWeather.shouldFetch(lastFetch: now.addingTimeInterval(-3 * 3600), now: now, enabled: true))
        // A clock set back: fetch again rather than wait.
        #expect(SceneWeather.shouldFetch(lastFetch: now.addingTimeInterval(3600), now: now, enabled: true))
    }

    @Test func cloudsNeverCoverTheSun() {
        let size = CGSize(width: 390, height: 330)
        let radius: CGFloat = 45
        // The sun along its whole arc, low left to high centre to low right, and at several drifts.
        for i in 0...20 {
            let t = Double(i) / 20
            let sun = CGPoint(x: 40 + 310 * t, y: 260 - 200 * sin(.pi * t))
            for drift in stride(from: 0.0, through: 1.0, by: 0.25) {
                for cloud in SceneWeather.clouds(in: size, sun: sun, sunRadius: radius, drift: drift) {
                    #expect(!SceneWeather.overlaps(cloud, sun: sun, radius: radius), "sun at \(sun), drift \(drift)")
                }
            }
        }
    }

    @Test func positionsAreTheSameEveryTime() {
        let a = SceneWeather.clouds(in: CGSize(width: 390, height: 330), sun: CGPoint(x: 195, y: 120), sunRadius: 45)
        let b = SceneWeather.clouds(in: CGSize(width: 390, height: 330), sun: CGPoint(x: 195, y: 120), sunRadius: 45)
        #expect(a == b)
    }
}

struct WindSwayTests {
    /// Wind makes the shoreline and the water's lines sway faster, not wildly (update 49's board, finished in 50).
    @Test func windSwaysFaster() {
        #expect(SceneWeather.windSway > 1.5 && SceneWeather.windSway < 4)
    }
}
