import Foundation

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
