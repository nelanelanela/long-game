import XCTest

/// Update 47: every screen we can reach in the Simulator, opened with the debug launch switches, photographed into
/// the test results and checked with Apple's accessibility audit (all audit types).
///
/// The pass comes from the environment (`TEST_RUNNER_LG_PASS=light|large|dark|contrast` on the xcodebuild line):
/// - light: default text size, light look;
/// - large: the largest accessibility text size, light look;
/// - dark: default size, dark look;
/// - contrast: light look; Increase Contrast is switched on for the Simulator before the run.
@MainActor
final class AccessibilityAuditTests: XCTestCase {
    private var app: XCUIApplication!
    private var pass: String { ProcessInfo.processInfo.environment["LG_PASS"] ?? "light" }

    override func setUp() async throws {
        continueAfterFailure = true
    }

    // MARK: Helpers

    private func launch(_ extra: [String] = [], demo: Bool = true) {
        app = XCUIApplication()
        var args = ["-uitest.disableAnimations"]
        if demo { args.append("-demoData") }
        switch pass {
        case "large": args += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL", "-uitest.appearance", "light"]
        case "dark": args += ["-uitest.appearance", "dark"]
        default: args += ["-uitest.appearance", "light"]
        }
        app.launchArguments = args + extra
        app.launch()
    }

    /// Screenshot (kept in the results) and the audit. Issues the audit gets wrong are listed in `KnownFalseAlarms`
    /// with the reason; everything else fails the test.
    private func audit(_ screen: String, file: StaticString = #filePath, line: UInt = #line) {
        // iOS's own "You have changed the icon" alert (the sample total passes a stage) would stop the audit: OK it.
        let ok = XCUIApplication(bundleIdentifier: "com.apple.springboard").buttons["OK"]
        if ok.exists { ok.tap(); sleep(1) }
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "\(pass) · \(screen)"
        shot.lifetime = .keepAlways
        add(shot)
        do {
            try app.performAccessibilityAudit(for: .all) { issue in
                let element = issue.element.map { "\($0.elementType.rawValue) '\($0.label)' \($0.frame)" } ?? "-"
                let ignored = KnownFalseAlarms.ignores(issue, screen: screen)
                print("AUDIT|\(self.pass)|\(screen)|\(issue.auditType.rawValue)|\(ignored ? "ignored" : "FOUND")|\(issue.compactDescription)|\(element)")
                return ignored
            }
        } catch {
            XCTFail("\(screen): audit could not run: \(error)", file: file, line: line)
        }
    }

    @discardableResult
    private func tap(_ label: String, timeout: TimeInterval = 6) -> Bool {
        let button = app.buttons[label].firstMatch
        guard button.waitForExistence(timeout: timeout) else {
            XCTFail("No button '\(label)'")
            return false
        }
        button.tap()
        return true
    }

    private func wait(_ label: String, timeout: TimeInterval = 6) {
        let any = app.descendants(matching: .any)[label].firstMatch
        if !any.waitForExistence(timeout: timeout) {
            let text = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", label)).firstMatch
            XCTAssertTrue(text.waitForExistence(timeout: 2), "Didn't find '\(label)'")
        }
    }

    // MARK: Onboarding

    func testOnboarding() {
        launch(["-uitest.freshInstall"], demo: false)
        wait("Get started", timeout: 12)
        audit("Welcome")
        tap("Get started")
        wait("One game, 10,000 hours")
        audit("Intro 1")
        tap("Next")
        sleep(1)
        audit("Intro 2")
        tap("Next")
        sleep(1)
        audit("Intro 3")
        tap("Choose your game")
        wait("What’s your game?")
        audit("Setup 1 · Your game")
        // Update 53: typing your own craft makes it a selected chip, and the button plays it.
        let field = app.textFields.firstMatch
        field.tap()
        field.typeText("Calligraphy")
        wait("Your own: Calligraphy")
        audit("Setup 1 · Your own craft")
        tap("Play Calligraphy")
        wait("When did you start?")
        audit("Setup 2 · When did you start")
        tap("Continue")
        wait("Before today")
        audit("Setup 3 · Before today")
        tap("Continue")
        wait("From today on")
        audit("Setup 4 · From today on")
        tap("Continue")
        wait("Keep your game safe")
        audit("Setup 5 · Keep your game safe")
    }

    /// Update 53: started this year, so Before today asks for a total.
    func testOnboardingStartedThisYear() {
        launch(["-uitest.freshInstall"], demo: false)
        tap("Get started", timeout: 12)
        tap("Next"); tap("Next")
        tap("Choose your game")
        tap("Piano")
        tap("Play Piano")
        wait("When did you start?")
        for _ in 0..<3 { app.buttons["Later year"].firstMatch.tap() }
        tap("Continue")
        wait("hours so far")
        audit("Setup 3 · Before today, started this year")
        tap("I’m just starting · 0 h")
        tap("Continue")
        wait("Starting from zero.")
        audit("Setup 4 · From today on, from zero")
    }

    func testNotificationAsk() { launch(["-uitest.screen", "notifyAsk"]); wait("Lost in your work?"); audit("Lost in your work?") }
    func testWeatherInvite() { launch(["-uitest.screen", "weatherInvite"]); wait("Bring the weather in?"); audit("Bring the weather in?") }

    // MARK: Update 48 and 49

    func testThenAndNow() {
        launch(["-uitest.screen", "thenAndNow"])
        wait("Look how far.")
        audit("Then and now")
        tap("Choose other photos")
        wait("Choose Then")
        audit("Then and now · choose photos")
    }

    func testMemoryCard() {
        launch(["-debug.forceMemory", "yearAgo", "-uitest.today", "empty", "-uitest.screen", "home.today"])
        wait("A year ago today")
        audit("Home · a memory")
    }

    func testWeatherLayers() {
        for layer in ["cloud", "rain", "wind", "mist", "snow"] {
            launch(["-debug.forceWeather", layer, "-uitest.screen", "home.today"])
            wait("Begin")
            audit("Home · weather, \(layer)")
            app.terminate()
        }
    }

    func testLetterWriteAndSeal() {
        launch(["-uitest.screen", "letter.write"])
        wait("Seal the letter")
        audit("Letter · write")
        let field = app.textViews["Your letter"].exists ? app.textViews["Your letter"] : app.textFields["Your letter"]
        if field.waitForExistence(timeout: 4) {
            field.tap()
            field.typeText("I hope the nocturne sings by now.")
            tap("Seal the letter")
            wait("Your letter is sealed")
            audit("Letter · sealed")
        } else {
            XCTFail("No letter field")
        }
    }

    func testLetterWaiting() { launch(["-uitest.screen", "letter.sealed"]); wait("A letter is waiting"); audit("Letter · waiting") }
    func testLetterDelivered() { launch(["-uitest.screen", "letter.delivered"]); wait("A letter from you"); audit("Letter · delivered") }

    func testYourLetters() {
        launch(["-uitest.screen", "letters"])
        wait("Begin")
        app.swipeUp()
        let row = app.buttons.containing(NSPredicate(format: "label BEGINSWITH 'Your letters'")).firstMatch
        if row.waitForExistence(timeout: 4) {
            row.tap()
            sleep(1)
            audit("Your letters")
        } else {
            XCTFail("No Your letters row")
        }
    }

    func testKeepsakePoster() {
        launch(["-uitest.screen", "keepsake"])
        wait("A keepsake for your wall")
        audit("Keepsake poster")
        tap("Night")
        sleep(1)
        audit("Keepsake poster · night")
    }

    // MARK: Home

    func testHomeTodayEmpty() { launch(["-uitest.today", "empty", "-uitest.screen", "home.today"]); wait("Begin"); audit("Home · Today, empty day") }
    func testHomeTodayInProgress() { launch(["-uitest.today", "progress", "-uitest.screen", "home.today"]); wait("Begin"); audit("Home · Today, in progress") }
    func testHomeTodayCovered() { launch(["-uitest.today", "covered", "-uitest.screen", "home.today"]); wait("Begin"); audit("Home · Today, covered") }
    func testHomeWeek() { launch(["-uitest.screen", "home.week"]); wait("Begin"); audit("Home · This week") }
    func testHomeLongGame() { launch(["-uitest.screen", "home.longGame"]); wait("Begin"); audit("Home · The long game") }
    func testWeeklyLookBack() { launch(["-uitest.screen", "lookback"]); wait("Start the week"); audit("Weekly look-back") }

    // MARK: Timer

    func testTimerRunning() { launch(["-uitest.screen", "timer.running"]); wait("Finish"); audit("Timer · running") }
    func testTimerPaused() { launch(["-uitest.screen", "timer.paused"]); wait("Finish"); audit("Timer · paused") }

    func testFinishSheetAndSaved() {
        launch(["-uitest.screen", "timer.finish"])
        wait("Save")
        audit("Finish sheet")
        tap("Save")
        sleep(1)
        audit("Saved")
    }

    func testFinishSheetForgotToStop() {
        launch(["-uitest.screen", "timer.long"])
        wait("A long one. Did the timer keep running?")
        audit("Finish sheet · Forgot to stop?")
    }

    // MARK: History and Your year

    func testCalendar() { launch(["-uitest.screen", "history.calendar"]); wait("Calendar"); audit("History · Calendar") }

    func testGrowthAndYear() {
        launch(["-uitest.screen", "history.growth"])
        wait("Growth")
        sleep(2)
        audit("History · Growth")
        let full = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'full screen' OR label CONTAINS[c] 'expand'")).firstMatch
        if full.waitForExistence(timeout: 3) {
            full.tap()
            sleep(2)
            audit("Growth · full screen")
            let close = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'close' OR label CONTAINS[c] 'done'")).firstMatch
            if close.exists { close.tap() }
            sleep(1)
        }
        let year = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Your 20'")).firstMatch
        if year.waitForExistence(timeout: 3) {
            year.tap()
            wait("Share")
            audit("Your year · Sunrise")
            if app.buttons["Evening"].exists { app.buttons["Evening"].tap(); sleep(1); audit("Your year · Evening") }
            if app.buttons["Photos"].exists { app.buttons["Photos"].tap(); sleep(1); audit("Your year · Photos") }
        }
    }

    func testMilestoneCelebration() { launch(["-uitest.screen", "milestone"]); sleep(3); audit("Milestone celebration") }

    // MARK: Sheets and Settings

    func testCatchUpByWeek() {
        launch(["-debug.lastSessionDaysAgo", "20"])
        wait("Welcome back.", timeout: 8)
        audit("Catch up · Welcome back")
        tap("I practised, let me add it")
        sleep(1)
        audit("Catch up · by week")
    }

    func testCatchUpAverage() {
        launch(["-debug.lastSessionDaysAgo", "40"])
        tap("I practised, let me add it", timeout: 8)
        sleep(1)
        audit("Catch up · average")
    }

    func testAddPastHours() { launch(["-uitest.screen", "addHours"]); wait("Add past hours"); audit("Add past hours") }
    func testFutureSelf() { launch(["-uitest.screen", "futureSelf"]); wait("Meet your future self"); audit("Meet your future self") }
    func testTipJar() { launch(["-uitest.screen", "tipjar"]); wait("Keep the sun shining"); sleep(2); audit("Tip jar") }
    func testWeeklyPace() { launch(["-uitest.screen", "pace"]); wait("Your pace for the year"); audit("Your pace for the year") }

    func testSettingsAndFriends() {
        launch(["-uitest.screen", "settings"])
        wait("Settings")
        audit("Settings")
        let data = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Data & storage'")).firstMatch
        for _ in 0..<3 where !data.isHittable { app.swipeUp() }
        if data.waitForExistence(timeout: 3) {
            data.tap()
            wait("Save to iCloud")
            audit("Data & storage")
            let photos = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Your photos'")).firstMatch
            if photos.waitForExistence(timeout: 3) {
                photos.tap()
                sleep(1)
                audit("Your photos")
                app.buttons["Back"].firstMatch.tap()
                XCTAssertTrue(app.staticTexts["Data & storage"].waitForExistence(timeout: 3), "Your photos should go back to Data & storage")
            }
            app.buttons["Back"].firstMatch.tap()
            sleep(1)
        }
        let newGame = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Switch to a new game'")).firstMatch
        if newGame.waitForExistence(timeout: 3) {
            for _ in 0..<4 where !newGame.isHittable { app.swipeUp() }
            newGame.tap()
            XCTAssertTrue(app.buttons["Keep playing"].waitForExistence(timeout: 4))
            sleep(2)   // the sheet settles
            audit("One craft at a time")
        }
    }
}
