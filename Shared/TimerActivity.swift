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
    }

    var craftName: String
}

/// Where the running timer is kept between launches (and where the Live
/// Activity buttons write to, since they can run while the app is closed).
enum TimerPersistence {
    static let key = "timer.state.v1"

    static func load() -> TimerState? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(TimerState.self, from: data)
    }

    static func save(_ state: TimerState?) {
        if let state, let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}

extension Notification.Name {
    /// Posted after a Live Activity button changed the stored timer.
    static let timerChangedExternally = Notification.Name("app.longgame.timerChangedExternally")
    static let timerFinishRequested = Notification.Name("app.longgame.timerFinishRequested")
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
