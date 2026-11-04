import Foundation

/// Gathers what today's stretch needs from the stored data, in one place for Home and the Timer.
enum StretchSource {
    @MainActor
    static func plan(sessions: [SessionRecord], settings: AppSettings?, periods: [TargetPeriod], now: Date,
                     calendar: Calendar = .current) -> StretchPlan {
        let weekStart = settings?.weekStart ?? .localeDefault
        let hours = Stretch.weeklyTarget(now: now, weekStart: weekStart, periods: periods.map(\.record),
                                         current: settings?.currentTarget, calendar: calendar)
        #if DEBUG
        return Stretch.plan(sessions: sessions, weeklyTargetHours: hours, now: now, weekStart: weekStart, calendar: calendar,
                            hoursBeforeToday: DebugOptions.stretchHoursBeforeToday, forceRestDay: DebugOptions.stretchRestDay)
        #else
        return Stretch.plan(sessions: sessions, weeklyTargetHours: hours, now: now, weekStart: weekStart, calendar: calendar)
        #endif
    }

    /// A running session belongs to the day it started: only one that started today counts towards today.
    static func startedToday(_ state: TimerState, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        state.startedAt >= calendar.startOfDay(for: now)
    }

    /// The running timer's elapsed seconds, when it started today on this craft. A session counts towards the day it
    /// started, so one that began yesterday is not part of today.
    static func runningSeconds(_ state: TimerState?, craftID: UUID, now: Date, calendar: Calendar = .current) -> TimeInterval {
        guard let state, state.craftId == craftID, state.startedAt >= calendar.startOfDay(for: now) else { return 0 }
        return state.elapsed(at: now)
    }
}
