import XCTest

/// Update 50: a fresh install where the person says no to everything (iCloud off, no notifications, no location)
/// still works fully: setup finishes, a session is timed and saved, History and Settings open, and turning Weather in
/// the scene on afterwards just says the app can't see the weather.
/// Run after `xcrun simctl privacy <device> reset all com.wehavesun.LongGame`, so iOS asks for location again.
@MainActor
final class RefusedEverythingTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws { continueAfterFailure = false }

    private func tap(_ label: String, timeout: TimeInterval = 6) {
        let button = app.buttons[label].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: timeout), "No '\(label)' button")
        button.tap()
    }

    private func see(_ label: String, timeout: TimeInterval = 6) {
        let any = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", label)).firstMatch
        XCTAssertTrue(any.waitForExistence(timeout: timeout), "Didn't see '\(label)'")
    }

    /// iOS's own location prompt: Don't Allow.
    private func refuseLocationIfAsked() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for name in ["Don’t Allow", "Don't Allow"] {
            let button = springboard.buttons[name]
            if button.waitForExistence(timeout: 4) { button.tap(); return }
        }
    }

    private func dismissSystemAlert() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let ok = springboard.buttons["OK"]
        if ok.waitForExistence(timeout: 3) { ok.tap() }
    }

    func testEverythingRefusedStillWorks() {
        app = XCUIApplication()
        app.launchArguments = ["-uitest.freshInstall", "-uitest.disableAnimations", "-uitest.appearance", "light"]
        app.launch()

        // Setup, saying no to each ask.
        tap("Get started", timeout: 40)   // a fresh Simulator can hold the launch for ~30 s
        tap("Next"); tap("Next")
        tap("Choose your game")
        tap("Piano"); tap("Continue")
        tap("Continue")                     // When did you start?
        tap("Continue")                     // Hours a week
        tap("Continue")                     // Your weekly pace
        see("Keep your game safe")
        let iCloud = app.switches["Save to iCloud"].firstMatch
        if iCloud.waitForExistence(timeout: 3), iCloud.isEnabled, (iCloud.value as? String) == "1" {
            iCloud.switches.firstMatch.exists ? iCloud.switches.firstMatch.tap() : iCloud.tap()
        }
        tap("Continue")
        see("A gentle nudge")
        tap("Not now")                      // no notifications
        see("The weather outside")
        tap("Show the weather")             // then refuse the location prompt
        refuseLocationIfAsked()

        // iOS's "You have changed the icon" (the estimate is past 1,000 hours) and, the first time, Meet your future self.
        dismissSystemAlert()
        let futureSelf = app.buttons["Keep playing"].firstMatch
        if futureSelf.waitForExistence(timeout: 8) { futureSelf.tap() }
        dismissSystemAlert()

        // Home works: time a session and save it.
        tap("Begin", timeout: 12)
        sleep(65)                           // a session needs a minute to be saved
        tap("Finish", timeout: 8)
        tap("Save", timeout: 8)
        see("added", timeout: 10)

        // History opens with the session.
        let history = app.buttons.matching(NSPredicate(format: "label CONTAINS 'History' OR label CONTAINS 'Calendar'")).firstMatch
        XCTAssertTrue(history.waitForExistence(timeout: 4))
        history.tap()
        see("Rhythm")
        app.buttons["Back"].firstMatch.tap()

        // Settings: the weather switch is off, and turning it on says why it can't.
        tap("Settings")
        let weather = app.switches["Weather in the scene"]
        XCTAssertTrue(weather.waitForExistence(timeout: 4))
        XCTAssertEqual(weather.value as? String, "0")
        weather.switches.firstMatch.exists ? weather.switches.firstMatch.tap() : weather.tap()
        refuseLocationIfAsked()
        see("Without your location the app can't see the weather.")
        XCTAssertEqual(weather.value as? String, "0")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "Everything refused · Settings"
        shot.lifetime = .keepAlways
        add(shot)
    }
}
