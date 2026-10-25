import ActivityKit
import Foundation

/// Keeps the lock-screen / Dynamic Island activity in step with the timer.
@MainActor
enum LiveActivityManager {
    static func sync(_ state: TimerState?, now: Date = Date()) {
        guard let state else { end(); return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let elapsed = state.elapsed(at: now)
        let sun = SunHour(elapsed: elapsed)
        let content = ActivityContent(
            state: TimerActivityAttributes.ContentState(
                effectiveStart: now.addingTimeInterval(-elapsed),
                pausedElapsed: state.isPaused(at: now) ? elapsed : nil,
                litRays: sun.litRays,
                hours: sun.hoursCompleted),
            staleDate: nil)

        if !Activity<TimerActivityAttributes>.activities.isEmpty {
            Task { await update(content) }
        } else {
            _ = try? Activity.request(attributes: TimerActivityAttributes(craftName: state.craftName),
                                      content: content, pushType: nil)
        }
    }

    static func end() {
        Task { await endAll() }
    }

    private nonisolated static func update(_ content: ActivityContent<TimerActivityAttributes.ContentState>) async {
        for activity in Activity<TimerActivityAttributes>.activities {
            await activity.update(content)
        }
    }

    private nonisolated static func endAll() async {
        for activity in Activity<TimerActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
