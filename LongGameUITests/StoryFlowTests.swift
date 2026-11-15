import XCTest

/// Updates 48 and 49, used the way a person would: the features work, not only that they pass the audit.
/// Opened with the same debug launch switches as the audit tests (`UITestLaunch`), on sample data.
@MainActor
final class StoryFlowTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws { continueAfterFailure = false }

    private func launch(_ extra: [String]) {
        app = XCUIApplication()
        app.launchArguments = ["-demoData", "-uitest.disableAnimations", "-uitest.appearance", "light"] + extra
        app.launch()
    }

    private func text(_ contains: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", contains)).firstMatch
    }

    private func shot(_ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    // MARK: A letter to your future self

    /// Seal is off while the letter is empty, on once there are words; sealing shows the envelope and the row on
    /// The long game then says a letter is waiting, without its text.
    func testWritingAndSealingALetter() {
        launch(["-uitest.screen", "letter.write"])
        let seal = app.buttons["Seal the letter"]
        XCTAssertTrue(seal.waitForExistence(timeout: 8))
        XCTAssertFalse(seal.isEnabled, "Seal should wait for some words")
        XCTAssertTrue(text("of 1,000 characters").exists || text("/ 1,000").exists, "No character counter")
        let field = app.textViews["Your letter"].exists ? app.textViews["Your letter"] : app.textFields["Your letter"]
        XCTAssertTrue(field.waitForExistence(timeout: 4))
        field.tap()
        field.typeText("Secret words for later.")
        XCTAssertTrue(seal.isEnabled)
        seal.tap()
        XCTAssertTrue(text("Your letter is sealed").waitForExistence(timeout: 4))
        shot("Letter sealed")
        app.buttons["Done"].tap()
        // On The long game: waiting, and the words never shown.
        app.buttons["The long game"].firstMatch.tap()
        app.swipeUp()
        XCTAssertTrue(text("A letter is waiting").waitForExistence(timeout: 4))
        XCTAssertFalse(text("Secret words for later.").exists, "A sealed letter's text must not show")
    }

    /// Leaving with words typed asks first.
    func testLeavingALetterAsksFirst() {
        launch(["-uitest.screen", "letter.write"])
        let field = app.textViews["Your letter"].exists ? app.textViews["Your letter"] : app.textFields["Your letter"]
        XCTAssertTrue(field.waitForExistence(timeout: 8))
        field.tap()
        field.typeText("Half a thought")
        shot("Letter · typed")
        app.buttons["Not now"].firstMatch.tap()
        sleep(1)
        shot("Letter · after Not now")
        XCTAssertTrue(app.buttons["Keep writing"].waitForExistence(timeout: 4) || text("Throw this letter away?").exists)
    }

    /// The delivered letter is one VoiceOver element: the pill, the text, the date.
    func testADeliveredLetterReadsAsOne() {
        launch(["-uitest.screen", "letter.delivered"])
        XCTAssertTrue(text("A letter from you").waitForExistence(timeout: 8))
        let card = text("You wrote this")
        XCTAssertTrue(card.exists)
        XCTAssertTrue(card.label.contains("Dear me at"), "The letter should be in the same element as the pill")
        XCTAssertTrue(card.label.contains(" · at "), "The date line should be in the same element")
        XCTAssertTrue(app.buttons["Keep it and close"].exists)
    }

    /// A sealed letter offers Rewrite and Throw away, and never its text.
    func testASealedLetterCantBeRead() {
        launch(["-uitest.screen", "letter.sealed"])
        XCTAssertTrue(text("A letter is waiting").waitForExistence(timeout: 8))
        XCTAssertFalse(text("Dear me at").exists)
        XCTAssertTrue(app.buttons["Rewrite"].exists)
        app.buttons["Throw away"].tap()
        XCTAssertTrue(text("Throw this letter away?").waitForExistence(timeout: 4))
    }

    // MARK: Then and now

    func testThenAndNow() {
        launch(["-uitest.screen", "thenAndNow"])
        XCTAssertTrue(text("Look how far.").waitForExistence(timeout: 8))
        XCTAssertTrue(text("Then.").exists, "The Then card reads as one element starting 'Then.'")
        XCTAssertTrue(text("Now.").exists)
        XCTAssertTrue(text("years").exists && text("later").exists, "No '… later' pill")
        // Share is ready once the image is made.
        let share = app.buttons["Share"]
        XCTAssertTrue(share.waitForExistence(timeout: 6))
        let made = NSPredicate(format: "isEnabled == true")
        expectation(for: made, evaluatedWith: share)
        waitForExpectations(timeout: 10)
        // Choose other photos: pick Then, then Now.
        app.buttons["Choose other photos"].tap()
        XCTAssertTrue(text("Choose Then").waitForExistence(timeout: 4))
        shot("Then and now · choose")
    }

    func testThenAndNowFromGrowth() {
        launch(["-uitest.screen", "history.growth"])
        XCTAssertTrue(text("At your chosen pace").waitForExistence(timeout: 8))
        app.swipeUp()
        let row = app.buttons.containing(NSPredicate(format: "label CONTAINS 'Then and now'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 4), "Then and now row missing on Growth")
        XCTAssertTrue(app.buttons.containing(NSPredicate(format: "label CONTAINS 'Keepsake poster'")).firstMatch.exists,
                      "Keepsake poster row missing on Growth (sample data is past 1,000 hours)")
    }

    // MARK: Keepsake poster

    func testThePosterIsMadeInEveryPaperAndLook() {
        launch(["-uitest.screen", "keepsake"])
        XCTAssertTrue(text("A keepsake for your wall").waitForExistence(timeout: 8))
        XCTAssertTrue(text("Poster:").exists, "The preview should read as one element 'Poster: …'")
        let save = app.buttons["Save the poster"]
        for choice in ["A4", "A3", "50 × 70", "18 × 24 in", "Night", "Paper"] {
            app.buttons[choice].tap()
            let ready = NSPredicate(format: "isEnabled == true")
            expectation(for: ready, evaluatedWith: save)
            waitForExpectations(timeout: 10)
            XCTAssertTrue(app.buttons[choice].isSelected, "\(choice) should read as selected")
        }
    }

    // MARK: The sun remembers

    func testAMemoryOpensHistory() {
        launch(["-debug.forceMemory", "yearAgo", "-uitest.today", "empty", "-uitest.screen", "home.today"])
        let card = app.buttons.containing(NSPredicate(format: "label BEGINSWITH 'A year ago today'")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 8))
        card.tap()
        XCTAssertTrue(text("History").waitForExistence(timeout: 4), "The memory should open that day in History")
    }

    // MARK: Weather in the scene

    /// The scene's label gains the weather's words; a clear day says nothing extra.
    func testTheSceneSaysTheWeather() {
        launch(["-debug.forceWeather", "rain", "-uitest.screen", "home.today"])
        XCTAssertTrue(text("light rain").waitForExistence(timeout: 8), "The scene's label should say 'light rain'")
        app.terminate()
        launch(["-debug.forceWeather", "none", "-uitest.screen", "home.today"])
        XCTAssertTrue(app.buttons["Begin"].waitForExistence(timeout: 8))
        XCTAssertFalse(text("light rain").exists)
    }

    /// Settings has the switch, off unless turned on, with Apple's attribution link under it.
    func testWeatherSwitchInSettings() {
        launch(["-uitest.screen", "settings"])
        let toggle = app.switches["Weather in the scene"]
        for _ in 0..<4 where !toggle.exists { app.swipeUp() }
        XCTAssertTrue(toggle.waitForExistence(timeout: 4))
        XCTAssertEqual(toggle.value as? String, "0", "Weather in the scene should start off")
        XCTAssertTrue(app.switches["The sun remembers"].exists)
    }
}
