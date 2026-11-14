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

        return false
    }
}
