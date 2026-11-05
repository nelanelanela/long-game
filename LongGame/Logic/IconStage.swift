import Foundation

/// The six looks of the app icon, the "10,000 ring". It grows at 1,000, 2,500, 5,000, 7,500 and 10,000 hours.
/// Pure, so it is easy to test; the app changes the real icon in `AppIconManager`.
enum IconStage: String, CaseIterable, Comparable, Sendable {
    case start, k1, k2_5, k5, k7_5, k10

    /// The stage for a total. Below 1,000 hours it is the start icon.
    static func `for`(totalHours: Double) -> IconStage {
        allCases.last(where: { totalHours >= Double($0.milestoneHours) }) ?? .start
    }

    /// The milestone that unlocks this stage (0 for the start icon).
    var milestoneHours: Int {
        switch self {
        case .start: 0
        case .k1: 1_000
        case .k2_5: 2_500
        case .k5: 5_000
        case .k7_5: 7_500
        case .k10: 10_000
        }
    }

    /// The asset-catalog name; nil is the primary icon, which is what iOS wants for `setAlternateIconName`.
    var alternateIconName: String? {
        self == .start ? nil : "AppIcon-\(milestoneHours)"
    }

    /// The asset-catalog set that holds the artwork.
    var assetName: String { alternateIconName ?? "AppIcon" }

    /// The number in the middle of the ring: the next goal on the start icon, the milestone reached after that.
    var number: String { self == .start || self == .k10 ? "10,000" : DurationFormat.grouped(milestoneHours) }

    /// How much of the ring is filled, 0...1.
    var ringFill: Double { self == .start ? 0 : Double(milestoneHours) / 10_000 }

    static func < (a: IconStage, b: IconStage) -> Bool { a.milestoneHours < b.milestoneHours }
}

/// When the icon is allowed to change. All plain decisions, no UIKit.
enum IconPlan {
    /// The stage the icon should show: the total's stage, or the plain icon when the switch is off.
    static func wanted(totalHours: Double, growsWithYou: Bool) -> IconStage {
        growsWithYou ? .for(totalHours: totalHours) : .start
    }

    /// After the user taps the main button on a celebration: the stage to move to, or nil.
    /// Only celebrations of 1,000 hours or more change the icon. When one big save jumped over several milestones,
    /// the celebration is for the highest, and the icon goes straight to the stage for the whole total.
    static func afterCelebration(hours: Int, totalHours: Double, growsWithYou: Bool) -> IconStage? {
        guard growsWithYou, hours >= IconStage.k1.milestoneHours else { return nil }
        return .for(totalHours: totalHours)
    }

    /// The quiet check on launch, on return to the foreground and when Home first appears.
    /// A lower stage (the total went down) is set at once; a higher one waits while a celebration is due or showing,
    /// so the system alert never covers it.
    static func quietStage(totalHours: Double, growsWithYou: Bool, applied: IconStage, celebrationPending: Bool) -> IconStage? {
        let target = wanted(totalHours: totalHours, growsWithYou: growsWithYou)
        if target == applied { return nil }
        if target > applied && celebrationPending { return nil }
        return target
    }

    /// The last gate before calling `setAlternateIconName`: the app is active, no session is running, the device
    /// supports it, and the icon on screen is not already the wanted one.
    static func shouldCall(wanted: IconStage, currentIconName: String?, appActive: Bool,
                           supportsAlternateIcons: Bool, timerRunning: Bool) -> Bool {
        appActive && supportsAlternateIcons && !timerRunning && currentIconName != wanted.alternateIconName
    }
}
