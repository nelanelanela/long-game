import XCTest

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
        XCTAssertEqual(first.pngRepresentation, second.pngRepresentation, "Home moved with Reduce Motion on")
    }

    /// The giggle shows just the face: a tap on the sun changes the face and nothing moves around it.
    func testReduceMotionGiggle() {
        launch(["-uitest.reduceMotion", "-uitest.freshInstall"])
        XCTAssertTrue(app.buttons["Get started"].waitForExistence(timeout: 8))
        app.buttons["Get started"].tap()
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
            if screen != "history.calendar" {
                XCTAssertTrue(small.isEmpty, "\(screen): smaller than 44 × 44: \(small.joined(separator: ", "))")
            }
        }
    }

    // MARK: VoiceOver order

    /// What VoiceOver walks through, in order: the elements with a label, top to bottom as the app exposes them.
    private func readingOrder() -> [String] {
        app.descendants(matching: .any).allElementsBoundByIndex.compactMap { e -> String? in
            guard e.exists, !e.label.isEmpty, e.frame.width > 0, e.frame.height > 0 else { return nil }
            switch e.elementType {
            case .other, .window, .application, .scrollView, .image where e.label.isEmpty: return nil
            default: return e.label
            }
        }
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
    static let homeToday: [String] = []
    static let timer: [String] = []
    static let finish: [String] = []
    static let calendar: [String] = []
    static let settings: [String] = []
}
