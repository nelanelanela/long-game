import Testing
import Foundation
@testable import LongGame

struct FocusPlanTests {
    func on() -> FocusSettings { FocusSettings(switchFocus: true) }

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

    @Test func settingsSurviveEncoding() throws {
        let data = try JSONEncoder().encode(on())
        #expect(try JSONDecoder().decode(FocusSettings.self, from: data) == on())
    }
}
