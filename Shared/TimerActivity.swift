import ActivityKit
import AppIntents
import Foundation

/// Shared by the app and the Live Activity widget.
struct TimerActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// "now − elapsed" when last updated, so Text(timerInterval:) can count on its own.
        var effectiveStart: Date
        /// Set while paused.
        var pausedElapsed: Double?
        var litRays: Int
        var hours: Int
        /// Today's stretch is covered: the sun smiles, as on the Timer screen.
        var dayComplete: Bool
    }

    var craftName: String
}

struct ToggleTimerIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Pause or resume"

    func perform() async throws -> some IntentResult {
        if var state = TimerPersistence.load() {
            let now = Date()
            if state.isPaused(at: now) { state.resume(at: now) } else { state.pause(at: now) }
            TimerPersistence.save(state)
        }
        NotificationCenter.default.post(name: .timerChangedExternally, object: nil)
        return .result()
    }
}

struct FinishTimerIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Finish session"
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        if var state = TimerPersistence.load() {
            state.pause(at: Date())
            TimerPersistence.save(state)
        }
        NotificationCenter.default.post(name: .timerFinishRequested, object: nil)
        return .result()
    }
}
