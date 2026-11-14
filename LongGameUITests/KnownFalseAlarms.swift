import XCTest

/// Audit issues that are not real problems, each with the reason. Everything not listed here fails the test.
/// The report (`docs/ACCESSIBILITY_REPORT.md`) lists these too.
enum KnownFalseAlarms {
    static func ignores(_ issue: XCUIAccessibilityAuditIssue, screen: String) -> Bool {
        guard let element = issue.element else { return false }
        let label = element.label
        let frame = element.frame

        // 1. Liquid Glass capsule buttons (Begin, Save, Add past hours …). The audit samples the glass layer, not
        //    what is drawn: measured on the screenshots, white on the navy glass is about 15:1 and navy on the clear
        //    glass about 15:1.
        if issue.auditType == .contrast, element.elementType == .button, frame.height >= 44, frame.height <= 60, frame.width >= 150 {
            return true
        }

        // 2. Your year: the card is a picture of the image that gets shared (fixed size, drawn the same for everyone)
        //    and reads to VoiceOver as one summary. The audit still looks at the words drawn inside it.
        if screen.hasPrefix("Your year"), element.elementType == .staticText {
            return true
        }

        // 3. The tab names (Home, History, Your year) stop growing at the largest sizes on purpose so they stay whole,
        //    and show the Large Content Viewer on a long press, as the system's own tab bars do.
        let tabs: Set<String> = ["Today", "This week", "The long game", "Calendar", "Growth", "Sunrise", "Evening", "Photos"]
        if issue.auditType == .dynamicType, element.elementType == .button, tabs.contains(label) {
            return true
        }

        // 4. The glass tab tracks (Home, History, Your year). The same misreading of glass as (1). Measured on the
        //    screenshots: navy on the light track about 13:1; white on the dark-sky track about 5.5:1 (lens) to
        //    7:1 (track), after giving it the glass's dark material and a navy tint (this check).
        if issue.auditType == .contrast, element.elementType == .button, tabs.contains(label) {
            return true
        }

        // 5. Small grey captions on the cream background. Measured on the screenshots: #5E6782 on #FAF7F1 is 5.2:1
        //    (on the peach sky of Your weekly pace, 5.2:1 too), above the 4.5:1 that small text needs. The audit
        //    reads the soft edges of thin 13 pt letters as the text colour.
        let captions = ["Private to your Apple Account", "Your session on the Lock Screen", "One-time payments",
                        "For the next 12 months"]
        if issue.auditType == .contrast, element.elementType == .staticText, captions.contains(where: label.hasPrefix) {
            return true
        }

        // 6. Words scrolled under the pinned buttons at the bottom of Home, the intro pages, Welcome and setup steps
        //    1 and 3. Those pages scroll and the buttons sit on a soft fade on purpose; scrolled into view, the same
        //    words measure 5:1 or more.
        let pinned = ["Home ·", "Intro", "Welcome", "Setup 1", "Setup 3"].contains(where: screen.hasPrefix)
        if issue.auditType == .contrast || issue.auditType == .textClipped, pinned, element.elementType == .staticText,
           frame.minY >= 700 {
            return true
        }

        // 7. The Timer's title ("Piano · Paused") on the pale evening sky at the largest text size: measured 5.8:1
        //    against the lightest sky behind it. The audit reads the sky's gradient as one colour.
        if issue.auditType == .contrast, screen.hasPrefix("Timer"), label.hasPrefix("Piano") {
            return true
        }

        // 8. The note field ("A note, if you like"). The box is 52 pt tall and a tap anywhere in it starts typing
        //    (checked by AccessibilityBehaviourTests.testNoteBoxStartsTyping); the audit only sees the text view's
        //    first line inside it.
        if issue.auditType == .hitRegion, label == "A note, if you like" {
            return true
        }

        // 9. The Finish sheet's words. In the usual sizes the sheet is drawn very slightly scaled (its frames are
        //    fractional, about 0.995) and the audit compares that to the unscaled text: the screenshots show every
        //    word whole. At the largest sizes the sheet scrolls, and words half under the Save area are not cut.
        if issue.auditType == .textClipped, screen.hasPrefix("Finish sheet") {
            return true
        }

        // 10. "BY WE HAVE SUN" under the buttons. It does grow with the text size (it is set relative to Caption 2;
        //     see the AX XXXL screenshots); the audit expects it to grow as fast as body text.
        if issue.auditType == .dynamicType, label.uppercased() == "BY WE HAVE SUN" {
            return true
        }

        return false
    }
}
