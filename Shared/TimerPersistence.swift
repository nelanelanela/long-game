import Foundation

/// Where the running timer is kept between launches (and where the Live
/// Activity buttons write to, since they can run while the app is closed).
///
/// Kept in the shared App Group, so the Control in Control Centre (the widget extension) can show the running clock.
enum TimerPersistence {
    static let key = "timer.state.v1"

    /// The App Group's defaults, or the app's own where there is no group (the Mac, signed to run locally).
    private static var defaults: UserDefaults {
        UserDefaults(suiteName: WidgetSnapshot.groupID) ?? .standard
    }

    static func load() -> TimerState? {
        let shared = defaults
        // Earlier versions kept it in the app's own defaults: move it across once.
        if shared.data(forKey: key) == nil, shared !== UserDefaults.standard, let old = UserDefaults.standard.data(forKey: key) {
            shared.set(old, forKey: key)
            UserDefaults.standard.removeObject(forKey: key)
        }
        guard let data = shared.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(TimerState.self, from: data)
    }

    static func save(_ state: TimerState?) {
        if let state, let data = try? JSONEncoder().encode(state) {
            defaults.set(data, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}

/// The Control's kind, shared so the app can ask WidgetKit to redraw it.
enum SessionControlKind {
    static let kind = "app.longgame.session"
}

extension Notification.Name {
    /// Posted after a Live Activity button changed the stored timer.
    static let timerChangedExternally = Notification.Name("app.longgame.timerChangedExternally")
    static let timerFinishRequested = Notification.Name("app.longgame.timerFinishRequested")
}
