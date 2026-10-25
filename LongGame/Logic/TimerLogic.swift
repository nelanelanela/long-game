import Foundation

/// The running session, stored as timestamps only. Elapsed time is always
/// derived from these, never counted in memory.
struct TimerState: Codable, Equatable, Sendable {
    var craftId: UUID
    var craftName: String = ""
    var startedAt: Date
    var pausedAt: Date?
    var accumulatedPause: TimeInterval = 0

    static let autoPauseAfter: TimeInterval = 12 * 3600
    static let longSessionAfter: TimeInterval = 4 * 3600

    private func rawElapsed(at now: Date) -> TimeInterval {
        (pausedAt ?? now).timeIntervalSince(startedAt) - accumulatedPause
    }

    /// Seconds practised so far, never more than 12 hours.
    func elapsed(at now: Date) -> TimeInterval {
        max(0, min(rawElapsed(at: now), Self.autoPauseAfter))
    }

    func isAutoPaused(at now: Date) -> Bool {
        pausedAt == nil && rawElapsed(at: now) >= Self.autoPauseAfter
    }

    func isPaused(at now: Date) -> Bool { pausedAt != nil || isAutoPaused(at: now) }

    /// Turns a 12-hour auto-pause into a real pause at the moment it happened.
    mutating func normalize(at now: Date) {
        if isAutoPaused(at: now) {
            pausedAt = startedAt.addingTimeInterval(accumulatedPause + Self.autoPauseAfter)
        }
    }

    mutating func pause(at now: Date) {
        normalize(at: now)
        if pausedAt == nil { pausedAt = now }
    }

    mutating func resume(at now: Date) {
        normalize(at: now)
        guard let p = pausedAt else { return }
        accumulatedPause += max(0, now.timeIntervalSince(p))
        pausedAt = nil
    }

    /// When the running timer would reach 4 hours, if it keeps running.
    func longSessionDate(at now: Date) -> Date? {
        guard !isPaused(at: now) else { return nil }
        let remaining = Self.longSessionAfter - elapsed(at: now)
        return remaining > 0 ? now.addingTimeInterval(remaining) : nil
    }
}

/// How the sun looks for a given elapsed time: a ray every 5 minutes,
/// all 12 lit at each full hour ("golden hour").
struct SunHour: Equatable, Sendable {
    static let raySeconds: TimeInterval = 300
    static let hourSeconds: TimeInterval = 3600

    let elapsed: TimeInterval

    init(elapsed: TimeInterval) { self.elapsed = max(0, elapsed) }

    var hoursCompleted: Int { Int(elapsed / Self.hourSeconds) }
    var secondsIntoHour: TimeInterval { elapsed.truncatingRemainder(dividingBy: Self.hourSeconds) }
    var litRays: Int { Int(secondsIntoHour / Self.raySeconds) }
    var secondsSinceLastRay: TimeInterval { elapsed.truncatingRemainder(dividingBy: Self.raySeconds) }
    var secondsToNextRay: TimeInterval { Self.raySeconds - secondsSinceLastRay }
    var secondsToGoldenHour: TimeInterval { Self.hourSeconds - secondsIntoHour }
    /// 0...1 through the hour, drives the warming sky.
    var hourFraction: Double { secondsIntoHour / Self.hourSeconds }
    var minutesIntoHour: Int { Int(secondsIntoHour / 60) }

    /// Seconds since the last full hour while the golden-hour moment is playing.
    func goldenProgress(duration: TimeInterval = 1.2) -> Double? {
        guard hoursCompleted >= 1, secondsIntoHour < duration else { return nil }
        return secondsIntoHour / duration
    }

    /// Seconds since a new ray lit, while its 600 ms grow plays.
    func rayGrowProgress(duration: TimeInterval = 0.6) -> Double? {
        guard elapsed >= Self.raySeconds, secondsSinceLastRay < duration, litRays > 0 else { return nil }
        return secondsSinceLastRay / duration
    }

    var caption: String {
        "Next ray in \(DurationFormat.minutesSeconds(seconds: secondsToNextRay)) · golden hour in \(DurationFormat.minutesSeconds(seconds: secondsToGoldenHour))"
    }

    var accessibilityLabel: String {
        "The sun is focusing with you. \(litRays) of 12 rays lit: \(minutesIntoHour) minutes into this hour."
    }
}

enum FinishRules {
    static let step: TimeInterval = 300
    static let minimumSave: TimeInterval = 60

    static func canSave(elapsed: TimeInterval) -> Bool { elapsed >= minimumSave }

    /// Next lower 5-minute step, never below one minute.
    static func lowered(_ duration: TimeInterval) -> TimeInterval {
        let down = (ceil(duration / step) - 1) * step
        return max(minimumSave, down)
    }

    /// Next higher 5-minute step, never above the real elapsed time.
    static func raised(_ duration: TimeInterval, elapsed: TimeInterval) -> TimeInterval {
        min(elapsed, (floor(duration / step) + 1) * step)
    }
}
