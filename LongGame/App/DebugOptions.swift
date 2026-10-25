#if DEBUG
import Foundation

/// Debug-only switches for trying flows in the Simulator.
@MainActor
enum DebugOptions {
    private static let settingKey = "debug.pretendNow"
    private static let argumentKey = "debug.lastSessionDaysAgo"
    private static var argumentUsed = false

    /// Settings button: pretend the last session was this many days ago, once.
    static func setPretendLastSessionDaysAgo(_ days: Int) {
        UserDefaults.standard.set(days, forKey: settingKey)
    }

    /// Also available as a launch argument: `-debug.lastSessionDaysAgo 10` (once per launch).
    static func takePretendLastSessionDaysAgo() -> Int? {
        if UserDefaults.standard.object(forKey: settingKey) != nil {
            let days = UserDefaults.standard.integer(forKey: settingKey)
            UserDefaults.standard.removeObject(forKey: settingKey)
            return days
        }
        if !argumentUsed, UserDefaults.standard.object(forKey: argumentKey) != nil {
            argumentUsed = true
            return UserDefaults.standard.integer(forKey: argumentKey)
        }
        return nil
    }
}
#endif
