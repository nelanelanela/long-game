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

    /// How long a session must be to move the overall total to 20 seconds below the next whole
    /// hour, so the Timer's small-win bounce shows soon after it starts.
    static func secondsToJustUnderWholeHour(total: Double, marginSeconds: Double = 20) -> Double {
        var target = total.rounded(.down) + 1 - marginSeconds / 3600
        if target <= total { target += 1 }
        return (target - total) * 3600
    }

    /// Settings button: Home shows this anniversary today instead of the real one (cleared with nil).
    static var fakeAnniversary: Anniversary? {
        get {
            switch UserDefaults.standard.string(forKey: "debug.fakeAnniversary") {
            case "years": .years(2)
            case "year": .years(1)
            case "session": .session(100)
            case "days": .practiceDays(100)
            case "month": .months(1)
            default: nil
            }
        }
        set {
            let key: String? = switch newValue {
            case .years(1): "year"
            case .years: "years"
            case .session: "session"
            case .practiceDays: "days"
            case .months: "month"
            case nil: nil
            }
            UserDefaults.standard.set(key, forKey: "debug.fakeAnniversary")
            UserDefaults.standard.removeObject(forKey: "anniversary.faceDay")
        }
    }

    /// Settings button: Home opens the weekly look-back on its next appearance, whatever the week (once).
    static func requestLookBack() { UserDefaults.standard.set(true, forKey: "debug.showLookBack") }

    static func takeLookBackRequest() -> Bool {
        let asked = UserDefaults.standard.bool(forKey: "debug.showLookBack")
        UserDefaults.standard.removeObject(forKey: "debug.showLookBack")
        return asked
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
