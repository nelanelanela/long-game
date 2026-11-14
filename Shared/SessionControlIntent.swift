import AppIntents
import Foundation

/// The Control's tap: on begins (or resumes) a session, off pauses it. A Live Activity intent, so iOS runs it in the
/// app (where `TimerStore` lives) even from the background, and it can start the Live Activity.
@available(iOS 18.0, *)
struct SessionControlIntent: SetValueIntent, LiveActivityIntent {
    static let title: LocalizedStringResource = "Begin or pause a session"
    static let isDiscoverable = false

    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { [.background, .foreground(.dynamic)] }

    @Parameter(title: "Playing")
    var value: Bool

    @MainActor
    func perform() async throws -> some IntentResult {
        if case .begin(.noCraft) = SessionCommands.setPlaying(value) { throw openAppInstead() }
        return .result()
    }
}
