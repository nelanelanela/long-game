import Foundation

/// A brand-new game (update 42, `design/redesign/CalendarEarly.dc.html` and `GrowthEarly.dc.html`): what History holds
/// back until there is enough to go on, so the first days never read as missed or as a slow pace.
enum EarlyDays {
    /// Growth draws the actual-pace line after this many days of sessions.
    static let actualPaceAfterDays = 14

    /// The game's first day: the day setup finished, or an earlier session (past hours added by hand).
    static func firstDay(onboarding: Date, sessionStarts: [Date], calendar: Calendar = .current) -> Date {
        let first = sessionStarts.min().map { min($0, onboarding) } ?? onboarding
        return calendar.startOfDay(for: first)
    }

    /// When the first full week ends: the end of the week the game began in when it began on the week's first day,
    /// else the end of the week after.
    static func firstFullWeekEnds(firstDay: Date, weekStart: WeekStart, calendar: Calendar = .current) -> Date {
        let weekOf = WeekMath.startOfWeek(firstDay, weekStart: weekStart, calendar: calendar)
        let weeks = calendar.startOfDay(for: firstDay) == weekOf ? 1 : 2
        return calendar.date(byAdding: .day, value: 7 * weeks, to: weekOf) ?? firstDay
    }

    /// Calendar: Rhythm shows "–" and the note "Rhythm appears after your first full week" until then.
    static func beforeFirstFullWeek(firstDay: Date, now: Date, weekStart: WeekStart, calendar: Calendar = .current) -> Bool {
        now < firstFullWeekEnds(firstDay: firstDay, weekStart: weekStart, calendar: calendar)
    }

    /// Growth: the actual-pace line and its key row wait for two weeks since the first session.
    static func showsActualPace(sessionStarts: [Date], now: Date, calendar: Calendar = .current) -> Bool {
        guard let first = sessionStarts.min() else { return false }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: first), to: calendar.startOfDay(for: now)).day ?? 0
        return days >= actualPaceAfterDays
    }

    /// Growth's line under the headline while the actual pace waits.
    static var actualPaceWaiting: String { String(localized: "Your actual pace shows after two weeks of playing.") }

    /// A day before the game began: drawn as a pale dot, not a rest day.
    static func isBeforeGame(_ day: Date, firstDay: Date) -> Bool { day < firstDay }
}

extension GrowthChartData {
    /// The same chart without the actual-pace line, in a game's first two weeks.
    func showingActual(_ shows: Bool) -> GrowthChartData {
        guard !shows else { return self }
        var copy = self
        copy.actual = []
        return copy
    }
}

extension Forecast {
    /// The same forecast with another actual-pace line (the chart's axis in a game's first two weeks).
    func withActual(_ line: ScenarioResult) -> Forecast {
        var copy = self
        copy.actual = line
        return copy
    }
}
