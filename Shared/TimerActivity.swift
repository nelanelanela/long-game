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

struct FinishTimerIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Finish session"
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        // Opens the app, which pauses the timer and shows the Finish sheet.
        NotificationCenter.default.post(name: .timerFinishRequested, object: nil)
        return .result()
    }
}
