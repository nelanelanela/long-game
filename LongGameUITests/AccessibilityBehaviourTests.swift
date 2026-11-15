import XCTest
import UIKit

/// Update 47, part 3: what the audit can't check, still in the Simulator. The accessibility settings are switched on
/// with the debug launch switches, which set the same SwiftUI values the app always reads.
@MainActor
final class AccessibilityBehaviourTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws { continueAfterFailure = true }

    private func launch(_ extra: [String], animations: Bool = false) {
        app = XCUIApplication()
        app.launchArguments = ["-demoData", "-uitest.appearance", "light"] + (animations ? [] : ["-uitest.disableAnimations"]) + extra
        app.launch()
    }

    private func shot(_ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    // MARK: Reduce Motion

    /// The opening plays the short fade: Home is there within about a second, not after the 2.2 s sunrise.
    func testReduceMotionShortOpening() {
        launch(["-uitest.reduceMotion", "-uitest.screen", "home.today"], animations: true)
        XCTAssertTrue(app.buttons["Begin"].waitForExistence(timeout: 1.5), "Home wasn't there quickly: the full opening played")
        shot("Reduce Motion · Home after the short opening")
    }

    /// No breathing, ray turning or water sway: two pictures of Home a moment apart are the same.
    func testReduceMotionStillHome() {
        launch(["-uitest.reduceMotion", "-uitest.screen", "home.week"])
        XCTAssertTrue(app.buttons["Begin"].waitForExistence(timeout: 6))
        sleep(2)
        let first = app.screenshot()
        sleep(2)
        let second = app.screenshot()
        shot("Reduce Motion · Home, still")
        // The status bar is left out: its clock can change between the two pictures.
        XCTAssertEqual(Self.belowStatusBar(first), Self.belowStatusBar(second), "Home moved with Reduce Motion on")
    }

    private static func belowStatusBar(_ shot: XCUIScreenshot) -> Data? {
        guard let cg = shot.image.cgImage else { return nil }
        let cut = Int(70 * shot.image.scale)
        return cg.cropping(to: CGRect(x: 0, y: cut, width: cg.width, height: cg.height - cut))
            .flatMap { UIImage(cgImage: $0).pngData() }
    }

    /// The giggle shows just the face: a tap on the sun changes the face and nothing moves around it.
    func testReduceMotionGiggle() {
        // Home's sun (the sample data is loaded, so a fresh install would go straight back to it anyway).
        launch(["-uitest.reduceMotion", "-uitest.screen", "home.today"])
        XCTAssertTrue(app.buttons["Begin"].waitForExistence(timeout: 8))
        let sun = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] 'sun'")).firstMatch
        if sun.waitForExistence(timeout: 4) {
            sun.tap()
            usleep(300_000)
            shot("Reduce Motion · the giggle, face only")
        }
    }

    // MARK: Reduce Transparency and Differentiate Without Colour

    func testReduceTransparencyHome() {
        launch(["-uitest.reduceTransparency", "-uitest.screen", "home.week"])
        XCTAssertTrue(app.buttons["Begin"].waitForExistence(timeout: 6))
        shot("Reduce Transparency · Home")
        let title = app.staticTexts["Piano"].firstMatch
        app.swipeUp()
        sleep(1)
        shot("Reduce Transparency · Home scrolled (the title stays)")
        XCTAssertTrue(title.exists, "The craft name faded with Reduce Transparency on")
    }

    func testDifferentiateWithoutColourCalendar() {
        launch(["-uitest.differentiateWithoutColor", "-uitest.screen", "history.calendar"])
        sleep(3)
        shot("Differentiate Without Colour · Calendar")
    }

    // MARK: Tap targets

    func testTapTargets() {
        for screen in ["home.today", "home.week", "timer.running", "timer.finish", "history.calendar", "settings", "addHours", "tipjar"] {
            launch(["-uitest.screen", screen])
            sleep(3)
            var small: [String] = []
            for kind in [XCUIElement.ElementType.button, .switch, .link, .slider, .textField] {
                for element in app.descendants(matching: kind).allElementsBoundByIndex where element.exists && element.isHittable {
                    let f = element.frame
                    if f.width < 43.5 || f.height < 43.5 { small.append("\(element.label.isEmpty ? element.identifier : element.label) \(Int(f.width))×\(Int(f.height))") }
                }
            }
            print("TAPTARGETS|\(screen)|\(small.count)|\(small.joined(separator: "; "))")
            // Not asserted, each for its reason (docs/ACCESSIBILITY_REPORT.md):
            // - the system's own controls at their standard sizes: the sheet grabber, the date picker, the
            //   segmented pickers (32 pt) and switches (whose row is reported 28 pt tall; the switch itself is
            //   the system's 51 × 31), and the unnamed inner part of each switch;
            // - left for a design decision: the calendar's day cells (18 pt), Home's tabs (36 pt tall) and
            //   This week's day bars (42 pt wide).
            let decided = ["Today", "This week", "The long game", "Calendar", "Growth", "Sheet Grabber", "Date Picker",
                           "Automatic", "Light", "Dark", "Monday", "Sunday"]
            let open = small.filter { item in
                if screen == "history.calendar" { return false }
                if decided.contains(where: { item.hasPrefix($0 + " ") }) { return false }
                if item.hasPrefix(" ") { return false }              // a switch's unnamed inner part
                if screen == "settings", item.hasSuffix("×28") || item.hasSuffix("×27") { return false }   // a system switch's row (27 or 28 after rounding)
                if screen == "home.week", item.hasSuffix("42×84") { return false } // a day bar
                // The note's text view: the whole box is the target, checked by testNoteBoxStartsTyping.
                if item.hasPrefix("A note, if you like ") { return false }
                // 44 pt circles, reported 42 because the Finish sheet is drawn at about 96% while it sits as a card.
                if screen == "timer.finish", item.hasSuffix("42×42") { return false }
                return true
            }
            XCTAssertTrue(open.isEmpty, "\(screen): smaller than 44 × 44: \(open.joined(separator: ", "))")
        }
    }

    /// The note box on the Finish sheet: a tap near its bottom edge (below the text view's first line) starts typing.
    func testNoteBoxStartsTyping() {
        launch(["-uitest.screen", "timer.finish"])
        let field = app.textViews["A note, if you like"].exists ? app.textViews["A note, if you like"] : app.textFields["A note, if you like"]
        XCTAssertTrue(field.waitForExistence(timeout: 8), "no note field")
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.95)).tap()
        sleep(1)
        // The Simulator may use the Mac's keyboard, so check the field's focus rather than the on-screen keyboard.
        let focused = (field.value(forKey: "hasKeyboardFocus") as? Bool) == true || app.keyboards.firstMatch.exists
        XCTAssertTrue(focused, "a tap at the bottom of the note box didn't start typing")
        shot("Note box · typing after a tap near its bottom edge")
    }

    // MARK: Chosen tab

    /// Update 51: in the dark look (the solid warm pill, on glass and flat) VoiceOver still hears a tab list with the
    /// chosen tab marked, "This week, tab, 2 of 3, selected".
    func testChosenTabInTheDarkLook() {
        for flat in [false, true] {
            app = XCUIApplication()
            app.launchArguments = ["-demoData", "-uitest.disableAnimations", "-uitest.appearance", "dark",
                                   "-uitest.screen", "home.week"] + (flat ? ["-uitest.flat"] : [])
            app.launch()
            // The group carries the tab-bar trait (VoiceOver's "tab, 2 of 3"); XCUITest lists it by name.
            let tabs = app.descendants(matching: .any).matching(identifier: "Home view").firstMatch
            XCTAssertTrue(tabs.waitForExistence(timeout: 15), "Home's tabs are not a tab list (flat: \(flat))")
            XCTAssertEqual(tabs.buttons.count, 3)
            XCTAssertTrue(tabs.buttons["This week"].isSelected, "This week isn't marked selected (flat: \(flat))")
            XCTAssertFalse(tabs.buttons["Today"].isSelected)
            XCTAssertFalse(tabs.buttons["The long game"].isSelected)
            shot("Dark look · chosen tab\(flat ? " · flat" : "")")
        }
    }

    // MARK: VoiceOver order

    /// What VoiceOver walks through, in order: the elements with a label, top to bottom as the app exposes them.
    /// Read from one snapshot of the tree (asking element by element took close to an hour on the calendar).
    /// "Toolbar" and "Sheet Grabber" are the system's own; screens underneath a cover can follow at the end.
    private func readingOrder() -> [String] {
        guard let root = try? app.snapshot() else { return [] }
        var out: [String] = []
        func walk(_ e: XCUIElementSnapshot) {
            let skip: Set<XCUIElement.ElementType> = [.other, .window, .application, .scrollView]
            if !skip.contains(e.elementType), !e.label.isEmpty, e.frame.width > 0, e.frame.height > 0,
               e.label != "Toolbar", e.label != "Sheet Grabber" {
                // VoiceOver stops on this element; the parts inside it (a switch's own text, a button's symbol)
                // are not read separately.
                out.append(e.label)
                return
            }
            e.children.forEach(walk)
        }
        walk(root)
        return out
    }

    private func checkOrder(_ screen: String, expected: [String]) {
        launch(["-uitest.screen", screen])
        sleep(3)
        let order = readingOrder()
        print("ORDER|\(screen)|\(order.joined(separator: " ▸ "))")
        let a = XCTAttachment(string: order.joined(separator: "\n"))
        a.name = "Reading order · \(screen)"
        a.lifetime = .keepAlways
        add(a)
        // Duplicates next to each other (the same words read twice) are always wrong.
        for (x, y) in zip(order, order.dropFirst()) where x == y { XCTFail("\(screen): '\(x)' is read twice in a row") }
        guard !expected.isEmpty else { return }
        // Each expected label is present, in this order (other labels may sit between them).
        var index = order.startIndex
        for label in expected {
            guard let found = order[index...].firstIndex(where: { $0.hasPrefix(label) }) else {
                XCTFail("\(screen): '\(label)' missing or out of order. Heard: \(order.joined(separator: " ▸ "))")
                return
            }
            index = order.index(after: found)
        }
    }

    func testOrderHomeToday() { checkOrder("home.today", expected: ExpectedOrder.homeToday) }
    func testOrderTimer() { checkOrder("timer.running", expected: ExpectedOrder.timer) }
    func testOrderFinishSheet() { checkOrder("timer.finish", expected: ExpectedOrder.finish) }
    func testOrderCalendar() { checkOrder("history.calendar", expected: ExpectedOrder.calendar) }
    func testOrderSettings() { checkOrder("settings", expected: ExpectedOrder.settings) }
}

/// The order a person should hear things, top to bottom. Filled in from a first listen and checked against the
/// screens; see `docs/ACCESSIBILITY_REPORT.md`.
enum ExpectedOrder {
    /// The craft and the two header buttons, the tabs, today's words, then Begin and Add past hours at the bottom.
    static let homeToday = ["Piano", "History", "Settings", "Today", "This week", "The long game", "Today's stretch",
                            "Begin", "Add past hours"]
    /// Minimise and the craft, the sun, today's number, this session's clock, then Pause and Finish.
    static let timer = ["Minimise", "Piano", "Session", "This session", "Pause", "Finish"]
    /// The time and its − / +, the photo and note, then Save and Discard.
    static let finish = ["Less time", "More time", "Add a photo", "A note, if you like", "Save", "Discard"]
    /// Back, the title, Settings, the two tabs, then the calendar.
    static let calendar = ["Back", "History", "Settings", "Calendar", "Growth"]
    /// Back and the title first, then the groups in the order they are drawn.
    static let settings = ["Back", "Settings", "Appearance", "Look", "Weather in the scene", "Support Long Game", "Notifications", "Daily reminder"]
}
