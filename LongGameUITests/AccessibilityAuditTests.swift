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
        tap("Piano")
        tap("Continue")
        wait("When did you start?")
        audit("Setup 2 · When did you start")
        tap("Continue")
        wait("Hours a week, each year")
        audit("Setup 3 · Hours a week")
        tap("Continue")
        wait("Your weekly pace")
        audit("Setup 4 · Your weekly pace")
        tap("Continue")
        wait("Keep your game safe")
        audit("Setup 5 · Keep your game safe")
        tap("Continue")
        wait("A gentle nudge")
        audit("Setup 6 · A gentle nudge")
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
        let photos = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Your photos'")).firstMatch
        if photos.waitForExistence(timeout: 3) {
            photos.tap()
            sleep(1)
            audit("Your photos")
            let back = app.buttons["Back"].firstMatch
            if back.waitForExistence(timeout: 3) { back.tap() }
            sleep(1)
        }
        let newGame = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Switch to a new game'")).firstMatch
        if newGame.waitForExistence(timeout: 3) {
            newGame.swipeUp()
            newGame.tap()
            sleep(1)
            audit("One craft at a time")
        }
    }
}
