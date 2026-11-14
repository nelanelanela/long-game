import Foundation
#if os(iOS)
import UIKit
#elseif os(watchOS)
import WatchKit
#endif

/// Plays the app's haptic language (`HapticPlan`): call it with what happened, not with a pattern. iOS plays nothing
/// when System Haptics is off in Settings; the Mac has none.
@MainActor
enum Haptics {
    /// Moments that arrive within a few hundredths of a second count as one: only the strongest plays.
    private static var pending: [HapticMoment] = []

    static func play(_ moment: HapticMoment) { play([moment]) }

    /// Several moments at once: only the strongest plays.
    static func play(_ moments: [HapticMoment]) {
        guard !moments.isEmpty else { return }
        let first = pending.isEmpty
        pending += moments
        guard first else { return }
        after(0.04) {
            let pattern = HapticPlan.strongest(pending)
            pending = []
            perform(pattern)
        }
    }

    private static func perform(_ pattern: HapticPattern) {
        #if os(iOS)
        switch pattern {
        case .none: break
        case .tick: UISelectionFeedbackGenerator().selectionChanged()
        case .softTap: impact(.light)
        case .twoTaps:
            impact(.light)
            after(0.12) { impact(.light) }
        case .risingThree:
            impact(.light)
            after(0.15) { impact(.medium) }
            after(0.3) { impact(.rigid) }
        }
        #elseif os(watchOS)
        let device = WKInterfaceDevice.current()
        switch pattern {
        case .none: break
        case .tick, .softTap: device.play(.click)
        case .twoTaps:
            device.play(.directionUp)
            after(0.12) { WKInterfaceDevice.current().play(.directionUp) }
        case .risingThree: device.play(.success)
        }
        #endif
    }

    #if os(iOS)
    private static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
    #endif

    private static func after(_ seconds: Double, _ work: @escaping @MainActor () -> Void) {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(seconds))
            work()
        }
    }
}
