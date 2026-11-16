import XCTest

/// Smoothness checks on the heavy game (`-demoData.heavy`: eight years, 300 photos; docs/PERFORMANCE_PLAN.md).
///
/// Each test repeats its steps five times and Xcode reports the numbers. Once a baseline is set (test report, "Set
/// Baseline"), a test fails when it gets clearly worse. In the Simulator these are only a guide; on a phone they are
/// the real thing (Product › Test with the phone chosen as the destination).
@MainActor
final class PerformanceUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // The heavy game is written on the first launch only (about 5 s); Home opens on Today with nothing popping up.
        app.launchArguments = ["-demoData.heavy", "-uitest.skipOpening", "-uitest.appearance", "light",
                               "-uitest.screen", "home.today"]
        app.launch()
        XCTAssertTrue(app.buttons["This week"].firstMatch.waitForExistence(timeout: 30), "Home didn't open")
    }

    private var options: XCTMeasureOptions {
        let o = XCTMeasureOptions()
        o.iterationCount = 5
        return o
    }

    /// Home's three tabs: the sun's glide and the labels' cross-fade. Clock time and the app's CPU while switching.
    func testTabSwitching() {
        measure(metrics: [XCTClockMetric(), XCTCPUMetric(application: app)], options: options) {
            app.buttons["This week"].firstMatch.tap()
            app.buttons["The long game"].firstMatch.tap()
            app.buttons["Today"].firstMatch.tap()
        }
    }

    /// Home left alone for 10 seconds: the sea, the sun and any weather keep moving. The CPU this takes is what a
    /// phone spends just showing Home.
    func testHomeIdle() {
        measure(metrics: [XCTCPUMetric(application: app)], options: options) {
            Thread.sleep(forTimeInterval: 10)
        }
    }

    /// History's calendar and day card, scrolled up and down: Apple's scrolling hitch measure.
    func testHistoryScrolling() {
        app.buttons["History"].firstMatch.tap()
        let scroll = app.scrollViews.firstMatch
        XCTAssertTrue(scroll.waitForExistence(timeout: 5))
        measure(metrics: [XCTOSSignpostMetric.scrollingAndDecelerationMetric], options: options) {
            scroll.swipeUp(velocity: .fast)
            scroll.swipeDown(velocity: .fast)
        }
    }

    /// Settings, scrolled up and down (its photo count and storage figures are worked out in the background).
    func testSettingsScrolling() {
        app.buttons["Settings"].firstMatch.tap()
        let scroll = app.scrollViews.firstMatch
        XCTAssertTrue(scroll.waitForExistence(timeout: 5))
        measure(metrics: [XCTOSSignpostMetric.scrollingAndDecelerationMetric], options: options) {
            scroll.swipeUp(velocity: .fast)
            scroll.swipeDown(velocity: .fast)
        }
    }
}
