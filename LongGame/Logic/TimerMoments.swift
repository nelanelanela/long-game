import Foundation

/// The small moments in the Timer that are worked out from timestamps alone.
enum TimerMoments {
    // MARK: Small win: the overall total crosses a whole hour

    static let bounceDuration: TimeInterval = 0.6
    static let shimmerDuration: TimeInterval = 0.8

    /// Seconds since the overall total (big gold number) last crossed a whole hour during this
    /// session, or nil when that was longer ago than the shimmer lasts, or never happened.
    /// A session that starts exactly on a whole hour has not "crossed" anything.
    static func secondsSinceWholeHour(baseTotal: Double, elapsed: TimeInterval) -> TimeInterval? {
        let total = baseTotal + elapsed / 3600
        let crossedAt = (total.rounded(.down) - baseTotal) * 3600   // elapsed seconds when it reached that hour
        guard crossedAt > 0 else { return nil }
        let since = elapsed - crossedAt
        return since >= 0 && since < shimmerDuration ? since : nil
    }

    /// Sun scale during the happy bounce: 100 → 114 → 96 → 104 → 100 %, eased between the steps.
    static func bounceScale(secondsSince t: TimeInterval) -> Double {
        let keys: [Double] = [1, 1.14, 0.96, 1.04, 1]
        let p = t / bounceDuration
        guard p > 0, p < 1 else { return 1 }
        let position = p * Double(keys.count - 1)
        let i = min(keys.count - 2, Int(position))
        let local = position - Double(i)
        let eased = (1 - cos(local * .pi)) / 2
        return keys[i] + (keys[i + 1] - keys[i]) * eased
    }

    /// 0 → 1 → 0 over the shimmer. With Reduce Motion this fade is all that happens.
    static func shimmerOpacity(secondsSince t: TimeInterval) -> Double {
        let p = t / shimmerDuration
        guard p > 0, p < 1 else { return 0 }
        return sin(p * .pi)
    }
}
