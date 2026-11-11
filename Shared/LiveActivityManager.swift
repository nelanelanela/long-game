import ActivityKit
import Foundation

/// Keeps the lock-screen / Dynamic Island activity in step with the timer.
@MainActor
enum LiveActivityManager {
    /// Today's stretch as the Timer screen last saw it, so syncs from elsewhere (pause from the lock screen, Siri)
    /// still know whether the day's sunrise is complete. Only used on the day it was made.
    private static var lastPlan: (plan: StretchPlan, day: Date)?

    static func sync(_ state: TimerState?, now: Date = Date(), plan: StretchPlan? = nil) {
        guard let state else { end(); return }
        let calendar = Calendar.current
        if let plan { lastPlan = (plan, calendar.startOfDay(for: now)) }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let elapsed = state.elapsed(at: now)
        let paused = state.isPaused(at: now)
        let sun = SunHour(elapsed: elapsed)
        // The same sunrise as the Timer screen: a session counts towards the day it started.
        let today = lastPlan.flatMap { calendar.isDate($0.day, inSameDayAs: now) ? $0.plan : nil }
        let p = today.map {
            TimerSunrise.progress(doneSaved: $0.doneSaved, running: state.startedAt >= calendar.startOfDay(for: now) ? elapsed : 0,
                                  target: $0.target)
        } ?? 0
        let content = ActivityContent(
            state: TimerActivityAttributes.ContentState(
                effectiveStart: now.addingTimeInterval(-elapsed),
                pausedElapsed: paused ? elapsed : nil,
                litRays: TimerSunrise.litRays(p: p, paused: paused, hourRays: sun.litRays),
                hours: sun.hoursCompleted,
                dayComplete: p >= 1),
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
