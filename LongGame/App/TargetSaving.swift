import Foundation
import SwiftData

/// Saves a new year of pace: the old target moves into the history and the new one covers the next 12 months
/// from today.
enum TargetSaving {
    static func apply(hours: Double, now: Date = Date(), settings: AppSettings, context: ModelContext,
                      calendar: Calendar = .current) {
        if let closed = TargetHistory.closing(settings.currentTarget, on: now, calendar: calendar) {
            context.insert(TargetPeriod(hoursPerWeek: closed.hoursPerWeek, start: closed.start, end: closed.end))
        }
        let start = WeeklyTarget.startDay(now, calendar: calendar)
        settings.weeklyTargetHours = WeeklyTarget.clamped(hours)
        settings.targetSetAt = start
        settings.targetEndsAt = WeeklyTarget.endDate(from: start, calendar: calendar)
        try? context.save()
    }
}
