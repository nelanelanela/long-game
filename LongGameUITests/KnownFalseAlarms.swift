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
        // The same for the keepsake poster's small preview (update 49): a scaled picture of the PDF, read to VoiceOver
        // as one summary ("Poster: 3,000 hours of piano, …"); the audit still finds the words drawn inside it.
        if screen.hasPrefix("Keepsake poster"), element.elementType == .staticText, frame.maxY < 330, frame.height < 30 {
            return true
        }

        // 3. The tab names (Home, History, Your year) stop growing at the largest sizes on purpose so they stay whole,
        //    and show the Large Content Viewer on a long press, as the system's own tab bars do.
        let tabs: Set<String> = ["Today", "This week", "The long game", "Calendar", "Growth", "Sunrise", "Evening", "Photos",
                                 // The keepsake poster's Paper and Look (update 49): the same glass tabs.
                                 "A4", "A3", "50 × 70", "18 × 24 in", "Paper", "Night"]
        if issue.auditType == .dynamicType, element.elementType == .button, tabs.contains(label) {
            return true
        }
        //    Your letters' delivered cards (update 49): reported "partially unsupported" in the default and dark passes,
        //    but the largest-size pass passes and its screenshot shows every word at full size.
        //    Meet your future self's track words ("Today · 3,257 h", "~Aug 2037 · 10,000 h") are the same: reported in
        //    the default pass only; the largest-size pass passes, and they grow and wrap onto two lines there.
        if issue.auditType == .dynamicType, screen == "Meet your future self", element.elementType == .staticText,
           label.hasSuffix(" h") {
            return true
        }
        if issue.auditType == .dynamicType, screen == "Your letters", element.elementType == .staticText {
            return true
        }
        //    The same on purpose for words that stop at xxxLarge so they stay whole and clear of a picture (update 50):
        //    the celebration's craft line and number over the sun, and the Then and now title between its buttons.
        let capped = ["· MILESTONE", " hours", "Then and now"]
        if issue.auditType == .dynamicType, element.elementType == .staticText,
           (screen == "Milestone celebration" && (label.hasSuffix(capped[0]) || label.hasSuffix(capped[1])))
            || (screen == "Then and now" && label == capped[2]) {
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
                        "For the next 12 months", "Deletes your game, sessions, notes and photos",
                        // Then and now's "212 hours of piano between these two." on the peach top: 5.1:1.
                        "between these two.",
                        // Update 49: setup step 7's note, the letter's invitation and the sealed page (#5E6782 on
                        // #FFF1DA / #FAF7F1 / #FFFDF8: 5.1–5.3:1).
                        "iPhone will ask for your location", "Write a few lines to the person", "The sun will bring it back",
                        "Not sure what to say?", "Your pace, split into a stretch"]
        if issue.auditType == .contrast, element.elementType == .staticText, captions.contains(where: { label.hasPrefix($0) || label.hasSuffix($0) }) {
            return true
        }
        // A delivered letter's date line ("8 June 2026 · at 3,700 h"): the same grey on the letter paper, 5.3:1.
        if issue.auditType == .contrast, element.elementType == .staticText, label.contains(" · at "), label.hasSuffix(" h") {
            return true
        }

        // 6. Words scrolled under the pinned buttons at the bottom of Home, the intro pages, Welcome and setup steps
        //    1 and 3. Those pages scroll and the buttons sit on a soft fade on purpose; scrolled into view, the same
        //    words measure 5:1 or more.
        //    Then and now (update 48) too: its Share and Choose other photos are pinned the same way.
        let pinned = ["Home ·", "Saved", "Intro", "Welcome", "Setup 1", "Setup 3", "Then and now"].contains(where: screen.hasPrefix)
        if issue.auditType == .contrast || issue.auditType == .textClipped, pinned, element.elementType == .staticText,
           frame.minY >= 700 {
            return true
        }

        //    This week's day letters (M, T, W …) at the foot of the day bars: on the taller phones the strip's bottom
        //    sits under Begin's fade at rest (the bars' frames reach about 730 pt). The largest-size pass, where the
        //    page scrolls them into view, is clean.
        if issue.auditType == .contrast, screen.hasPrefix("Home · This week"), element.elementType == .staticText,
           label.count == 1, frame.maxY >= 700 {
            return true
        }

        // 6b. The celebration (update 42 and 50): the craft line, white at 85% on the top of the dawn sky (navy #1E2550
        //     there, about 11:1), and Share this moment, navy on 70% white over the cream page (about 13:1).
        if issue.auditType == .contrast, screen.hasPrefix("Milestone celebration"),
           label.hasSuffix("· MILESTONE") || label == "Share this moment" {
            return true
        }

        // 6c. Then and now's two cards are tilted (−1.5° and +1.2°) on purpose. The audit measures their words with a
        //     straight box, catching the photo's edge, and also reads the spare large-size layout ViewThatFits keeps.
        //     The largest-size pass's screenshot shows every word whole and full size; VoiceOver reads each card as one.
        let cardWords = ["Then", "Now"]
        if screen == "Then and now", element.elementType == .staticText,
           [.contrast, .textClipped, .dynamicType].contains(issue.auditType),
           cardWords.contains(label) || label.hasPrefix("at ") || label.range(of: #"^\d{1,2} [A-Z][a-z]+ \d{4}$"#, options: .regularExpression) != nil
            || (issue.auditType != .dynamicType && frame.minY > 250) {
            return true
        }

        // 6d. Home's craft title under the full-screen celebration: Home is hidden from VoiceOver while it shows
        //     (update 47, fix 14), but the audit still samples its pixels.
        if issue.auditType == .contrast, screen == "Milestone celebration", label == "Piano" {
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
        //    The One craft sheet is the same: on iOS 26 a sheet at a height detent floats as an inset card drawn at
        //    about 0.87, and every word is whole in the screenshot.
        if issue.auditType == .textClipped, screen.hasPrefix("Finish sheet") || screen.hasPrefix("One craft at a time") {
            return true
        }

        // 10. "BY WE HAVE SUN" under the buttons. It does grow with the text size (it is set relative to Caption 2;
        //     see the AX XXXL screenshots); the audit expects it to grow as fast as body text.
        if issue.auditType == .dynamicType, label.uppercased() == "BY WE HAVE SUN" {
            return true
        }

        // 11. Undo in the "added" toast: gold #FFD66B on the navy pill measures 7.2:1. The audit samples the pill's
        //     translucent layer.
        if issue.auditType == .contrast, label == "Undo" {
            return true
        }

        // 12. The gauge's scale words on the dusk and night skies, white on their small navy tags (update 50). Measured
        //     on the audit's own screenshots: "7.5k" on The long game 7.4:1, "12 h" on This week in the dark look
        //     14.5:1. The audit reads the sky around the tag as the background.
        if issue.auditType == .contrast, screen.hasPrefix("Home ·"), element.elementType == .staticText,
           label.range(of: #"^(\d+(\.\d)?k|\d+ h)$"#, options: .regularExpression) != nil, frame.minY < 480 {
            return true
        }

        // Decided for 1.0 (15 November 2026): left as designed, on Natalia's word.
        // D1. The calendar's day squares (18 pt). VoiceOver and Voice Control reach every day; a tap shows the day in
        //     the card below the grid, which is full width.
        if issue.auditType == .hitRegion, screen.hasPrefix("History · Calendar"), element.elementType == .button,
           frame.width < 30, frame.height < 30 {
            return true
        }
        // D2. Home's and History's tabs (36 pt tall) and This week's day bars (42 pt wide): close to 44 and easy to hit;
        //     44 pt tabs would push the sky down on every Home tab.
        if issue.auditType == .hitRegion, element.elementType == .button,
           (tabs.contains(label) && frame.height >= 34) || (screen.hasPrefix("Home · This week") && frame.width >= 40 && frame.width < 44) {
            return true
        }
        // D3. The gauge's scale words on Home ("0", "2.5k" … "10k", "6 h", "12 h"): they grow with the text size up to
        //     about 1.5 times (accessibility1) and then stop, so the scale still fits beside the sun.
        let scaleWord = label.range(of: #"^(\d+(\.\d)?k|0|\d+ h)$"#, options: .regularExpression) != nil
        if issue.auditType == .dynamicType, screen.hasPrefix("Home ·"), element.elementType == .staticText,
           scaleWord, frame.minY < 480 {
            return true
        }

        return false
    }
}
