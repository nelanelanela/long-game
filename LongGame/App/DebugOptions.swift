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

    /// Settings button: Home shows this memory today (firstDay, photo, yearAgo, sameMonth, weekday), nil for the real one.
    static var forcedMemoryKind: String? {
        get { UserDefaults.standard.string(forKey: "debug.forceMemory") }
        set {
            UserDefaults.standard.set(newValue, forKey: "debug.forceMemory")
            UserDefaults.standard.removeObject(forKey: "memory.winkDay")
        }
    }

    /// The forced memory, with sample numbers (a photo's anniversary uses a real photo when there is one).
    static func forcedMemory(sessions: [Memories.Item], now: Date) -> Memory? {
        let cal = Calendar.current
        let lastYear = cal.date(byAdding: .year, value: -1, to: cal.startOfDay(for: now)) ?? now
        let today = sessions.filter { cal.isDate($0.start, inSameDayAs: now) }.reduce(0) { $0 + $1.durationSec }
        switch forcedMemoryKind {
        case "firstDay": return .firstDay(years: 3)
        case "photo":
            guard let photo = sessions.first(where: \.hasPhoto) else { return .yearAgo(years: 1, seconds: 1_200, today: nil, day: lastYear) }
            return .photo(years: 2, sessionId: photo.id, day: cal.startOfDay(for: photo.start))
        case "yearAgo": return .yearAgo(years: 1, seconds: 1_200, today: today >= 1_200 ? today : nil, day: lastYear)
        case "sameMonth":
            let month = cal.dateInterval(of: .month, for: now)?.start ?? now
            return .sameMonth(month: month, lastYear: 18 * 3600, thisYear: 22 * 3600)
        case "weekday": return .weekday(weekday: cal.component(.weekday, from: now), count: 31)
        default: return nil
        }
    }

    /// Three years of sample days for the keepsake poster (nothing is saved): busier weekdays, the odd week off.
    static func samplePoster(craft: String) -> KeepsakePoster.Content {
        let cal = Calendar.current
        let last = cal.startOfDay(for: Date())
        let first = cal.date(byAdding: .year, value: -3, to: last) ?? last
        var days: [CalendarLevel] = []
        var seed: UInt64 = 0x5EED
        var day = first
        while day <= last {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            let r = Double(seed >> 33) / Double(1 << 31)
            let weekend = cal.isDateInWeekend(day)
            let hours = r < (weekend ? 0.45 : 0.18) ? 0 : r * (weekend ? 2.5 : 4)
            days.append(CalendarLevel.level(hours: hours))
            day = cal.date(byAdding: .day, value: 1, to: day) ?? last.addingTimeInterval(86_400)
        }
        return KeepsakePoster.Content(hours: 3_000, craft: craft, days: days, firstDay: first, lastDay: last, baseline: 2_190)
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
