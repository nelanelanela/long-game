import Foundation

/// "Forgot to stop?": the person's usual session length, and when the Finish sheet asks about a long one.
enum UsualSession {
    /// The last this many timer sessions count.
    static let window = 20
    /// Fewer timer sessions than this: no usual yet.
    static let minimumCount = 5
    /// A session at least this many times the usual, and over `longAfter`, gets the card.
    static let longFactor = 2.0
    static let longAfter: TimeInterval = 90 * 60

    struct Entry: Equatable, Sendable {
        var start: Date
        var seconds: TimeInterval
        /// Only timer sessions count (not hours added by hand or a catch-up).
        var isTimer: Bool
    }

    /// The median length of the last 20 timer sessions, or nil with fewer than 5.
    static func usual(_ entries: [Entry]) -> TimeInterval? {
        let recent = entries.filter(\.isTimer).sorted { $0.start > $1.start }.prefix(window).map(\.seconds)
        guard recent.count >= minimumCount else { return nil }
        let sorted = recent.sorted()
        let mid = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid]
    }

    /// The usual as shown and used: rounded to 5 minutes, at least 5 minutes.
    static func rounded(_ usual: TimeInterval) -> TimeInterval {
        max(300, (usual / 300).rounded() * 300)
    }

    /// Whether the Finish sheet shows "A long one. Did the timer keep running?".
    static func isLong(elapsed: TimeInterval, usual: TimeInterval?) -> Bool {
        guard let usual, usual > 0 else { return false }
        return elapsed >= longFactor * usual && elapsed > longAfter
    }

    enum Choice: Equatable, Sendable { case keep, useUsual }

    /// The length a choice sets: Keep puts the measured time back, Use sets the (rounded) usual.
    static func duration(for choice: Choice, elapsed: TimeInterval, usual: TimeInterval) -> TimeInterval {
        switch choice {
        case .keep: elapsed
        case .useUsual: min(elapsed, rounded(usual))
        }
    }
}
