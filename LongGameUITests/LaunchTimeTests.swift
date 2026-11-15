import XCTest

/// Update 50: how long the app takes to open, with Apple's launch metric (five launches, the first ignored).
/// In the Simulator and a Debug build this is only a guide; the real figure comes from a device (Xcode › Organizer ›
/// Launch Time once people use it, or Instruments › App Launch).
final class LaunchTimeTests: XCTestCase {
    @MainActor
    func testLaunchTime() {
        let options = XCTMeasureOptions()
        options.iterationCount = 5
        measure(metrics: [XCTApplicationLaunchMetric(waitUntilResponsive: true)], options: options) {
            let app = XCUIApplication()
            app.launchArguments = ["-uitest.disableAnimations"]
            app.launch()
            app.terminate()
        }
    }
}
