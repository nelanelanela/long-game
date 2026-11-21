import XCTest

/// The everyday flows, used the way a person would: set up a game, time a session, add and edit past hours, look at
/// History, switch games. Each test opens the app with the debug launch switches (`UITestLaunch`) on the sample Piano
/// game, which is put back fresh on every launch, so the tests don't depend on each other.
@MainActor
final class CoreFlowTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws { continueAfterFailure = false }

    // MARK: Helpers

    private func launch(_ extra: [String], demo: Bool = true) {
        app = XCUIApplication()
        var args = ["-uitest.disableAnimations", "-uitest.appearance", "light"]
        if demo { args.append("-demoData") }
        app.launchArguments = args + extra
        app.launch()
    }

    private func button(_ label: String) -> XCUIElement { app.buttons[label].firstMatch }

    private func tap(_ label: String, timeout: TimeInterval = 6, file: StaticString = #filePath, line: UInt = #line) {
        let b = button(label)
        XCTAssertTrue(b.waitForExistence(timeout: timeout), "No '\(label)' button", file: file, line: line)
        b.tap()
    }

    private func text(_ contains: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", contains)).firstMatch
    }

    private func see(_ contains: String, timeout: TimeInterval = 6, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(text(contains).waitForExistence(timeout: timeout), "Didn't see '\(contains)'", file: file, line: line)
    }

    private func gone(_ element: XCUIElement, timeout: TimeInterval = 6) -> Bool {
        let p = NSPredicate(format: "exists == false")
        return XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: p, object: element)], timeout: timeout) == .completed
    }

    /// iOS's own "You have changed the icon" alert, which can arrive when the sample total passes an icon stage.
    private func okSystemAlert() {
        let ok = XCUIApplication(bundleIdentifier: "com.apple.springboard").buttons["OK"]
        if ok.waitForExistence(timeout: 2) { ok.tap() }
    }

    /// Home is showing: Begin is the button that starts a session. A milestone celebration or Meet your future self
    /// can arrive over it on the sample data (both close with Keep playing); they're closed first.
    /// Pass `closingPopUps: false` when the next check is the short-lived "added" note, which the wait would miss.
    private func waitForHome(timeout: TimeInterval = 10, closingPopUps: Bool = true,
                             file: StaticString = #filePath, line: UInt = #line) {
        okSystemAlert()
        XCTAssertTrue(button("Begin").waitForExistence(timeout: timeout), "Home didn't open", file: file, line: line)
        guard closingPopUps else { return }
        let keepPlaying = button("Keep playing")
        for _ in 0..<3 where keepPlaying.waitForExistence(timeout: 1.5) {
            keepPlaying.tap()
            _ = gone(keepPlaying, timeout: 3)
            okSystemAlert()
        }
    }

    private func shot(_ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    // MARK: Setup

    /// A new person goes from Welcome to Home with their own craft, and Home names it.
    func testSetupWithYourOwnCraftReachesHome() {
        launch(["-uitest.freshInstall"], demo: false)
        tap("Get started", timeout: 40)   // a freshly booted Simulator can hold the first launch
        tap("Next"); tap("Next")
        tap("Choose your game")
        see("What’s your game?")
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 4))
        field.tap()
        field.typeText("Calligraphy")
        tap("Play Calligraphy")
        see("When did you start?"); tap("Continue")
        see("Before today"); tap("Continue")
        see("From today on"); tap("Continue")
        see("Keep your game safe")
        tap("Start playing")
        okSystemAlert()
        let futureSelf = button("Keep playing")
        if futureSelf.waitForExistence(timeout: 6) { futureSelf.tap() }
        waitForHome(timeout: 12)
        see("Calligraphy")
        shot("Setup · Home with Calligraphy")
    }

    /// The Play button names the chosen suggestion and changes when another is chosen.
    func testChoosingASuggestionNamesThePlayButton() {
        launch(["-uitest.freshInstall"], demo: false)
        tap("Get started", timeout: 40)
        tap("Next"); tap("Next")
        tap("Choose your game")
        tap("Piano")
        XCTAssertTrue(button("Play Piano").waitForExistence(timeout: 4))
        // Choosing a suggestion fills the field with it: clear it before typing your own.
        tap("Clear")
        let field = app.textFields.firstMatch
        field.tap()
        field.typeText("Pottery")
        XCTAssertTrue(button("Play Pottery").waitForExistence(timeout: 4), "Typing your own craft should choose it")
        XCTAssertFalse(button("Play Piano").exists)
    }

    // MARK: Home

    /// The three Home tabs each open, and Begin stays reachable on all of them.
    func testHomeTabsSwitch() {
        launch(["-uitest.screen", "home.today"])
        waitForHome()
        for tab in ["This week", "The long game", "Today"] {
            tap(tab)
            XCTAssertTrue(button(tab).isSelected, "\(tab) should read as the chosen tab")
            XCTAssertTrue(button("Begin").exists, "Begin missing on \(tab)")
        }
    }

    /// Meet your future self closes with Keep playing.
    func testFutureSelfCloses() {
        launch(["-uitest.screen", "futureSelf"])
        see("Meet your future self")
        tap("Keep playing")
        XCTAssertTrue(gone(text("Meet your future self")))
        waitForHome()
    }

    // MARK: Timer

    /// Begin opens the timer; Pause and Resume swap; Minimise goes back to Home with the session still running.
    func testBeginPauseResumeAndMinimise() {
        launch(["-uitest.today", "empty", "-uitest.screen", "home.today"])
        waitForHome()
        tap("Begin")
        // The first session asks about check-in notifications.
        let notNow = button("Not now")
        if notNow.waitForExistence(timeout: 4) { notNow.tap() }
        tap("Pause", timeout: 8)
        XCTAssertTrue(button("Resume").waitForExistence(timeout: 4), "Pause should turn into Resume")
        see("Paused")
        tap("Resume")
        XCTAssertTrue(button("Pause").waitForExistence(timeout: 4), "Resume should turn back into Pause")
        tap("Minimise")
        XCTAssertTrue(gone(button("Finish")), "Minimise should close the timer")
        shot("Timer minimised · Home")
    }

    /// Finish, then Save: the Saved moment shows, then Home says the time was added and offers Undo.
    func testFinishAndSaveAddsTheTime() {
        launch(["-uitest.screen", "timer.finish"])
        tap("Save", timeout: 8)
        see("Saved")
        waitForHome(timeout: 12, closingPopUps: false)
        see("added", timeout: 8)
        shot("Timer saved · Home toast")
    }

    /// Undo on the "added" note removes the session that was just saved.
    func testUndoAfterSaving() {
        launch(["-uitest.screen", "timer.finish"])
        tap("Save", timeout: 8)
        waitForHome(timeout: 12, closingPopUps: false)
        let toast = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'added' AND label CONTAINS 'Undo'")).firstMatch
        XCTAssertTrue(toast.waitForExistence(timeout: 8), "No added note with Undo")
        let undo = button("Undo")
        undo.exists ? undo.tap() : toast.tap()
        see("Removed.", timeout: 4)
    }

    /// The finish sheet's − button shortens the session it will save.
    func testFinishSheetLessTime() {
        launch(["-uitest.screen", "timer.finish"])
        let less = button("Less time")
        XCTAssertTrue(less.waitForExistence(timeout: 8))
        // The sample session is 25 minutes; Less time steps down to the 5-minute mark below (the first tap can only
        // drop the running seconds), so within two taps it reads "20 m".
        XCTAssertTrue(text("25 m").waitForExistence(timeout: 4), "The session should start at 25 m")
        let twenty = app.descendants(matching: .any).matching(NSPredicate(format: "label == '20 m'")).firstMatch
        for _ in 0..<2 where !twenty.exists { less.tap(); _ = twenty.waitForExistence(timeout: 1.5) }
        XCTAssertTrue(twenty.exists, "Less time should shorten the session to 20 m")
        XCTAssertTrue(button("Save").isEnabled)
    }

    /// Discard asks first; confirming closes the timer and adds nothing.
    func testDiscardAsksThenAddsNothing() {
        launch(["-uitest.screen", "timer.finish"])
        tap("Discard", timeout: 8)
        see("Discard this session?")
        // The dialog has its own Discard (the destructive one); the sheet's is behind it.
        let confirm = app.sheets.buttons["Discard"].exists ? app.sheets.buttons["Discard"] : app.buttons.matching(identifier: "Discard").element(boundBy: 1)
        confirm.tap()
        waitForHome(timeout: 10)
        XCTAssertFalse(text("added").waitForExistence(timeout: 3), "A discarded session shouldn't say it was added")
    }

    /// A long session asks whether the timer kept running.
    func testForgotToStopAsks() {
        launch(["-uitest.screen", "timer.long"])
        see("A long one. Did the timer keep running?", timeout: 8)
        XCTAssertTrue(button("Save").exists)
    }

    // MARK: Add past hours

    /// The add button counts what will be added, is off at zero, and saving shows the added note.
    func testAddPastHours() {
        launch(["-uitest.screen", "addHours"])
        see("Add past hours")
        let fewer = button("Fewer hours"), fewerMin = button("Fewer minutes")
        XCTAssertTrue(fewer.waitForExistence(timeout: 4))
        for _ in 0..<13 where fewer.isEnabled { fewer.tap() }
        for _ in 0..<12 where fewerMin.isEnabled { fewerMin.tap() }
        XCTAssertFalse(button("Add hours").isEnabled, "Nothing to add should be off")
        tap("More hours"); tap("More hours")
        tap("Add 2 hours")
        waitForHome(timeout: 8, closingPopUps: false)
        see("added", timeout: 8)
    }

    /// Cancel closes Add past hours without adding.
    func testAddPastHoursCancel() {
        launch(["-uitest.screen", "addHours"])
        see("Add past hours")
        tap("Cancel")
        waitForHome()
        XCTAssertFalse(text("added").waitForExistence(timeout: 2))
    }

    /// Home's Add past hours button opens the form.
    func testAddPastHoursFromHome() {
        launch(["-uitest.screen", "home.today"])
        waitForHome()
        let add = button("Add past hours")
        for _ in 0..<4 where !add.isHittable { app.swipeUp() }
        add.tap()
        see("Day")
        XCTAssertTrue(button("More hours").exists)
    }

    // MARK: Editing a session

    /// Tapping one of today's sessions opens it to edit; deleting it asks first, then says Removed.
    func testEditAndDeleteTodaysSession() {
        launch(["-uitest.today", "progress", "-uitest.screen", "home.today"])
        waitForHome()
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS ' to ' AND label ENDSWITH '.'")).firstMatch
        for _ in 0..<4 where !(row.exists && row.isHittable) { app.swipeUp() }
        XCTAssertTrue(row.waitForExistence(timeout: 4), "No session in Today's sessions")
        row.tap()
        see("Edit session")
        XCTAssertTrue(button("Save changes").exists)
        let delete = button("Delete session")
        for _ in 0..<3 where !delete.isHittable { app.swipeUp() }
        delete.tap()
        see("Delete this session?")
        app.buttons.matching(NSPredicate(format: "label == 'Delete'")).firstMatch.tap()
        waitForHome()
    }

    /// Changing a session's length and saving closes the form.
    func testEditSessionSaveChanges() {
        launch(["-uitest.today", "progress", "-uitest.screen", "home.today"])
        waitForHome()
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS ' to ' AND label ENDSWITH '.'")).firstMatch
        for _ in 0..<4 where !(row.exists && row.isHittable) { app.swipeUp() }
        row.tap()
        tap("More minutes")
        tap("Save changes")
        XCTAssertTrue(gone(text("Edit session")))
        waitForHome()
    }

    // MARK: History

    /// History opens from Home on the Calendar, switches to Growth and back, and Back returns Home.
    func testHistoryCalendarAndGrowth() {
        launch(["-uitest.screen", "home.today"])
        waitForHome()
        tap("History")
        see("Calendar")
        see("Rhythm")
        tap("Growth")
        see("At your chosen pace", timeout: 8)
        tap("Calendar")
        see("Rhythm")
        tap("Back")
        waitForHome()
    }

    /// A new game's History explains that the calendar fills in.
    func testHistoryForANewGame() {
        launch(["-uitest.newGame", "-uitest.screen", "history.calendar"])
        see("Your calendar fills in as you play.", timeout: 8)
    }

    // MARK: Pace, catch up

    /// Your pace for the year: Back closes it, Save closes it too.
    func testWeeklyPaceSheet() {
        launch(["-uitest.screen", "pace"])
        see("Your pace for the year")
        tap("Back")
        waitForHome()
        app.terminate()
        launch(["-uitest.screen", "pace"])
        see("Your pace for the year")
        tap("Save")
        XCTAssertTrue(gone(text("Your pace for the year")))
    }

    /// Back after three weeks away: I took a break closes it with a kind word.
    func testCatchUpTookABreak() {
        launch(["-debug.lastSessionDaysAgo", "20", "-uitest.screen", "home.today"])   // the screen switch also clears a timer left running
        see("Welcome back.", timeout: 10)
        tap("I took a break")
        see("Rest is part of the craft.", timeout: 6)
    }

    /// Back after three weeks away: adding the hours ends with the added note on Home.
    func testCatchUpAddsHours() {
        launch(["-debug.lastSessionDaysAgo", "20", "-uitest.screen", "home.today"])   // the screen switch also clears a timer left running
        tap("I practised, let me add it", timeout: 10)
        see("How much did you play each week?")
        let add = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Add ' AND label ENDSWITH ' hours'")).firstMatch
        for _ in 0..<3 where !(add.exists && add.isHittable) { app.swipeUp() }
        XCTAssertTrue(add.waitForExistence(timeout: 4), "No Add … hours button")
        if add.isEnabled {
            add.tap()
            see("added", timeout: 8)
        }
    }

    // MARK: One craft

    /// Switching to a new game: Keep playing stays; Archive and replace starts setup again from Welcome.
    func testSwitchingToANewGame() {
        launch(["-uitest.screen", "settings"])
        see("Settings")
        let newGame = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Switch to a new game'")).firstMatch
        for _ in 0..<6 where !(newGame.exists && newGame.isHittable) { app.swipeUp() }
        newGame.tap()
        see("One craft at a time")
        tap("Keep playing")
        XCTAssertTrue(gone(text("One craft at a time")))

        for _ in 0..<6 where !(newGame.exists && newGame.isHittable) { app.swipeUp() }
        newGame.tap()
        see("One craft at a time")
        let inSheet = app.buttons.matching(NSPredicate(format: "label == 'Switch to a new game'")).firstMatch
        XCTAssertTrue(inSheet.waitForExistence(timeout: 4))
        inSheet.tap()
        see("Replace Piano?")
        tap("Archive and replace")
        XCTAssertTrue(button("Get started").waitForExistence(timeout: 10), "Replacing should start setup again")
        shot("After replacing Piano")
    }

    /// Cancel on Replace? keeps the game.
    func testReplaceCancelKeepsTheGame() {
        launch(["-uitest.screen", "settings"])
        let newGame = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Switch to a new game'")).firstMatch
        for _ in 0..<6 where !(newGame.exists && newGame.isHittable) { app.swipeUp() }
        newGame.tap()
        app.buttons.matching(NSPredicate(format: "label == 'Switch to a new game'")).firstMatch.tap()
        see("Replace Piano?")
        tap("Cancel")
        XCTAssertFalse(button("Get started").waitForExistence(timeout: 2))
        XCTAssertTrue(text("One craft at a time").exists)
    }
}
