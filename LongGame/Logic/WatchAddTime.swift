import Foundation

/// The Watch's Add time screen: the amount, its steps and the daily limit.
enum WatchAddTime {
    static let step: TimeInterval = 300
    static let minimum: TimeInterval = 300
    static let maximum: TimeInterval = 8 * 3600
    static let initial: TimeInterval = 1800
    static let quickPicks: [TimeInterval] = [900, 1800, 3600]
    /// A day's total on the Watch can't pass this.
    static let maxDaySeconds: TimeInterval = 12 * 3600

    /// The amount snapped to a 5-minute step inside the range (the Crown's value).
    static func clamped(_ seconds: TimeInterval) -> TimeInterval {
        min(maximum, max(minimum, (seconds / step).rounded() * step))
    }

    static func canAdd(_ seconds: TimeInterval, todaySeconds: TimeInterval) -> Bool {
        todaySeconds + seconds <= maxDaySeconds
    }

    /// "30 m", "1 h", "1 h 15 m".
    static func amount(_ seconds: TimeInterval) -> String { DurationFormat.short(seconds: seconds) }
}
