#if DEBUG
import Foundation

/// Debug-only switches for trying flows in the Simulator.
@MainActor
enum DebugOptions {
    private static let settingKey = "debug.pretendNow"
    private static let argumentKey = "debug.lastSessionDaysAgo"
    private static var argumentUsed = false

    private static let stretchHoursKey = "debug.stretch.hoursBefore"
    private static let stretchRestKey = "debug.stretch.restDay"

    /// Today's stretch: pretend this many hours were logged this week before today. Nil = use the real ones.
    static var stretchHoursBeforeToday: Double? {
        get {
            let d = UserDefaults.standard
            return d.object(forKey: stretchHoursKey) == nil ? nil : d.double(forKey: stretchHoursKey)
        }
        set {
            if let newValue { UserDefaults.standard.set(newValue, forKey: stretchHoursKey) }
            else { UserDefaults.standard.removeObject(forKey: stretchHoursKey) }
        }
    }

    /// Today's stretch: pretend today is not one of the practice days.
    static var stretchRestDay: Bool {
        get { UserDefaults.standard.bool(forKey: stretchRestKey) }
        set { UserDefaults.standard.set(newValue, forKey: stretchRestKey) }
    }

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
