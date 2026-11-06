import Foundation

/// The eleven looks of the app icon, the "10,000 ring": the start icon plus one for every 1,000 hours.
/// A stage is just a count of whole thousands, 0...10. Pure, so it is easy to test; the app changes the real icon
/// in `AppIconManager`.
struct IconStage: Hashable, Comparable, Sendable {
    /// Whole thousands reached, 0 (the start icon) ... 10.
    let thousands: Int

    init(thousands: Int) { self.thousands = min(max(thousands, 0), Self.maxThousands) }

    static let maxThousands = 10
    static let start = IconStage(thousands: 0)
    /// Every stage, start icon first.
    static let all = (0...maxThousands).map { IconStage(thousands: $0) }

    /// The stage for a total: the whole thousands reached, never more than 10.
    static func `for`(totalHours: Double) -> IconStage {
        IconStage(thousands: Int((max(totalHours, 0) / 1_000).rounded(.down)))
    }

    /// The hours that unlock this stage (0 for the start icon).
    var milestoneHours: Int { thousands * 1_000 }

    /// The asset-catalog name; nil is the primary icon, which is what iOS wants for `setAlternateIconName`.
    var alternateIconName: String? { thousands == 0 ? nil : "AppIcon-\(milestoneHours)" }

    /// The asset-catalog set that holds the artwork.
    var assetName: String { alternateIconName ?? "AppIcon" }

    /// The number in the middle of the ring: the next goal on the start icon, the thousand reached after that.
    var number: String { thousands == 0 || thousands == Self.maxThousands ? "10,000" : DurationFormat.grouped(milestoneHours) }

    /// How much of the ring is filled, 0...1.
    var ringFill: Double { Double(milestoneHours) / 10_000 }

    /// What is stored in Settings.
    var stored: String { String(thousands) }

    /// Reads a stored value; anything else (for example an old name from before the thousands) is unknown.
    init?(stored: String) {
        guard let n = Int(stored), (0...Self.maxThousands).contains(n) else { return nil }
        self.init(thousands: n)
    }

    static func < (a: IconStage, b: IconStage) -> Bool { a.thousands < b.thousands }
}

/// When the icon is allowed to change. All plain decisions, no UIKit.
enum IconPlan {
    /// The stage the icon should show: the total's stage, or the plain icon when the switch is off.
    static func wanted(totalHours: Double, growsWithYou: Bool) -> IconStage {
        growsWithYou ? .for(totalHours: totalHours) : .start
    }

    /// The celebrations that hold the icon back until their main button is tapped (and 2,500 and 7,500 are among
    /// them only so the system alert never covers a celebration). The icon itself changes for the thousands.
    static let heldBelow = 1_000

    /// After the user taps the main button on a celebration: the stage to move to, or nil. Only celebrations of
    /// 1,000 hours or more are involved. 2,500 and 7,500 never change the icon themselves: they only release a stage
    /// that a jump over several thousands was waiting for. The icon goes straight to the stage for the whole total.
    static func afterCelebration(hours: Int, totalHours: Double, growsWithYou: Bool, applied: IconStage?) -> IconStage? {
        guard growsWithYou, hours >= heldBelow else { return nil }
        let target = IconStage.for(totalHours: totalHours)
        return target == applied ? nil : target
    }

    /// Thousands that have no celebration of their own: the icon changes right after the session that crossed them
    /// is saved, once its sheet has closed.
    static func hasCelebration(thousands: Int) -> Bool { [1, 5, 10].contains(thousands) }

    /// The quiet check on launch, on return to the foreground, when Home first appears and when a sheet has closed.
    /// A stored stage that is unknown (nil) counts as "set it again".
    /// A lower stage (the total went down) is set at once; a higher one waits while a celebration of 1,000 h or more is due or showing,
    /// so the system alert never covers it.
    static func quietStage(totalHours: Double, growsWithYou: Bool, applied: IconStage?, celebrationPending: Bool) -> IconStage? {
        let target = wanted(totalHours: totalHours, growsWithYou: growsWithYou)
        if target == applied { return nil }
        if celebrationPending, applied.map({ target > $0 }) ?? true { return nil }
        return target
    }

    /// The last gate before calling `setAlternateIconName`: the app is active, no session is running, the device
    /// supports it, and the icon on screen is not already the wanted one.
    static func shouldCall(wanted: IconStage, currentIconName: String?, appActive: Bool,
                           supportsAlternateIcons: Bool, timerRunning: Bool) -> Bool {
        appActive && supportsAlternateIcons && !timerRunning && currentIconName != wanted.alternateIconName
    }
}
