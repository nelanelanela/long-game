import Foundation

/// What Begin and Pause do to the timer, from the app, the Control, Siri or the Action Button. Pure, so the tests
/// can check it; `TimerStore` applies the result.
enum TimerCommands {
    enum Begin: Equatable, Sendable {
        /// A new session for the current craft.
        case started(TimerState)
        /// It was paused: Begin carries on.
        case resumed(TimerState)
        /// Already running: nothing changes.
        case alreadyRunning
        /// No craft set up yet: the app opens instead.
        case noCraft
    }

    static func begin(_ state: TimerState?, craftId: UUID?, craftName: String, now: Date) -> Begin {
        if var running = state {
            guard running.isPaused(at: now) else { return .alreadyRunning }
            running.resume(at: now)
            return .resumed(running)
        }
        guard let craftId else { return .noCraft }
        return .started(TimerState(craftId: craftId, craftName: craftName, startedAt: now))
    }

    /// Pauses a running session, resumes a paused one. Nil when nothing is running (nothing to do).
    static func pauseOrResume(_ state: TimerState?, now: Date) -> TimerState? {
        guard var s = state else { return nil }
        s.isPaused(at: now) ? s.resume(at: now) : s.pause(at: now)
        return s
    }

    /// The Control's toggle: on means playing. Turning it on begins or resumes; off pauses.
    enum Toggle: Equatable, Sendable {
        case begin(Begin)
        case paused(TimerState)
        case nothing
    }

    static func setPlaying(_ playing: Bool, _ state: TimerState?, craftId: UUID?, craftName: String, now: Date) -> Toggle {
        if playing { return .begin(begin(state, craftId: craftId, craftName: craftName, now: now)) }
        guard var s = state, !s.isPaused(at: now) else { return .nothing }
        s.pause(at: now)
        return .paused(s)
    }

    /// Whether the Control shows as on (a session is running, not paused).
    static func isPlaying(_ state: TimerState?, now: Date) -> Bool {
        guard let state else { return false }
        return !state.isPaused(at: now)
    }
}
