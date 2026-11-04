import Testing
import Foundation
@testable import LongGame

struct FocusPlanTests {
    func on() -> FocusSettings { FocusSettings(switchFocus: true, muteApps: true) }

    @Test func shieldOnlyWhileASessionRuns() {
        #expect(FocusPlan.shouldShield(on(), sessionActive: true, hasChosenApps: true, authorised: true))
        #expect(!FocusPlan.shouldShield(on(), sessionActive: false, hasChosenApps: true, authorised: true))
    }

    @Test func shieldNeedsEveryCondition() {
        #expect(!FocusPlan.shouldShield(FocusSettings(), sessionActive: true, hasChosenApps: true, authorised: true))
        #expect(!FocusPlan.shouldShield(on(), sessionActive: true, hasChosenApps: false, authorised: true))
        #expect(!FocusPlan.shouldShield(on(), sessionActive: true, hasChosenApps: true, authorised: false))
    }

    @Test func shortcutNamesFollowTheSwitch() {
        #expect(FocusPlan.shortcutName(on(), starting: true) == "Start Practising")
        #expect(FocusPlan.shortcutName(on(), starting: false) == "Stop Practising")
        #expect(FocusPlan.shortcutName(FocusSettings(switchFocus: false), starting: true) == nil)
    }

    @Test func blankShortcutNameIsIgnored() {
        var s = on()
        s.startShortcut = "   "
        #expect(FocusPlan.shortcutName(s, starting: true) == nil)
        s.stopShortcut = " Calm down "
        #expect(FocusPlan.shortcutName(s, starting: false) == "Calm down")
    }

    @Test func shortcutURLEncodesTheNameAndComesBack() throws {
        let url = try #require(FocusPlan.shortcutURL(name: "Start Practising & more"))
        #expect(url.scheme == "shortcuts")
        #expect(url.host == "x-callback-url")
        #expect(url.path == "/run-shortcut")
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        #expect(items.first { $0.name == "name" }?.value == "Start Practising & more")
        #expect(items.first { $0.name == "x-success" }?.value == "longgame://focus")
    }

    @Test func chosenSummaryReadsNaturally() {
        #expect(FocusPlan.chosenSummary(apps: 0, categories: 0, websites: 0) == "None")
        #expect(FocusPlan.chosenSummary(apps: 1, categories: 0, websites: 0) == "1 app")
        #expect(FocusPlan.chosenSummary(apps: 3, categories: 1, websites: 2) == "3 apps, 1 category, 2 websites")
    }

    @Test func settingsSurviveEncoding() throws {
        let data = try JSONEncoder().encode(on())
        #expect(try JSONDecoder().decode(FocusSettings.self, from: data) == on())
    }
}
