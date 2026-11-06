import Foundation

// What the widgets show, worked out from the shared snapshot with the same Logic as the app.

/// The widget's numbers at one moment.
struct WidgetState: Equatable, Sendable {
    var craftName: String
    var week: HomeGauge
    var longGame: HomeGauge
    var weekHours: Double
    var weekTarget: Double
    var total: Double
    var todaySeconds: Double

    var weekPercent: Int { WeekTarget(hoursThisWeek: weekHours, target: weekTarget, daysLeft: 0).percent }
    var longGamePercent: Int { Totals.percent(total: total) }

    func gauge(for tab: HomeTab) -> HomeGauge { tab == .longGame ? longGame : week }

    /// Shown in the widget gallery and while a widget loads: the design's Piano example.
    static let sample = WidgetState(
        craftName: "Piano", week: .week(hours: 6.5, target: 12), longGame: .longGame(total: 3_294),
        weekHours: 6.5, weekTarget: 12, total: 3_294, todaySeconds: 5_400)
}

enum WidgetModel {
    static func records(_ snapshot: WidgetSnapshot) -> [SessionRecord] {
        snapshot.sessions.map { SessionRecord(start: $0.start, durationSec: $0.seconds) }
    }

    static func make(_ snapshot: WidgetSnapshot, at now: Date, calendar: Calendar = .current) -> WidgetState {
        let weekStart = WeekStart(rawValue: snapshot.weekStart) ?? .monday
        let sessions = records(snapshot)
        let rates = snapshot.estimates.map { YearRate(year: $0.year, hoursPerWeek: $0.hoursPerWeek) }

        let baseline = Baseline.hours(estimates: rates, onboardingDate: snapshot.onboardingDate, calendar: calendar)
        let total = Totals.total(baseline: baseline, logged: Totals.loggedHours(sessions))
        let weekHours = WeekMath.thisWeekHours(sessions, now: now, weekStart: weekStart, calendar: calendar)

        // The same fallback as Home: with no target chosen yet, the actual pace stands in for it.
        let latest = rates.max(by: { $0.year < $1.year })?.hoursPerWeek ?? 0
        let pace = Pace.hoursPerWeek(sessions: sessions, latestEstimate: latest, onboardingDate: snapshot.onboardingDate,
                                     now: now, calendar: calendar)
        let target = snapshot.target?.hoursPerWeek ?? WeeklyTarget.suggested(pace: pace)

        let today = calendar.startOfDay(for: now)
        let todaySeconds = sessions.filter { calendar.startOfDay(for: $0.start) == today }.reduce(0) { $0 + $1.durationSec }

        return WidgetState(craftName: snapshot.craftName,
                           week: .week(hours: weekHours, target: target), longGame: .longGame(total: total),
                           weekHours: weekHours, weekTarget: target, total: total, todaySeconds: todaySeconds)
    }

    /// When the widget's picture changes by itself: now, then every midnight until the next week starts (a new day
    /// resets "Today", a new week resets the sun). The app also reloads the widgets whenever it saves.
    static func timelineDates(from now: Date, weekStart: WeekStart, calendar: Calendar = .current) -> [Date] {
        let weekEnd = WeekMath.startOfWeek(now, weekStart: weekStart, calendar: calendar)
        let nextWeek = calendar.date(byAdding: .day, value: 7, to: weekEnd) ?? now.addingTimeInterval(7 * 86_400)
        var dates = [now]
        var day = calendar.startOfDay(for: now)
        while let next = calendar.date(byAdding: .day, value: 1, to: day), next <= nextWeek {
            dates.append(next)
            day = next
        }
        return dates
    }
}

/// The address a widget opens: Home on a tab.
enum WidgetLink {
    static let scheme = "longgame"

    static func url(for tab: HomeTab) -> URL {
        URL(string: "\(scheme)://home/\(tab.rawValue)") ?? URL(fileURLWithPath: "/")
    }

    static func tab(from url: URL) -> HomeTab? {
        guard url.scheme == scheme, url.host == "home" else { return nil }
        return HomeTab(rawValue: url.lastPathComponent)
    }
}
