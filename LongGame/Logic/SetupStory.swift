import Foundation

/// Update 53: the words and rules behind the shorter onboarding. The setup scene, the link card on "From today on",
/// the finish line under its stepper, and when the two questions moved out of setup are asked.

/// The small white card on "From today on" that links back to "Before today": a bold first part and a muted second.
enum SetupLink: Equatable, Sendable {
    /// Several years entered: the year before the current one.
    case lastYear(hoursPerWeek: Double)
    /// Only the current year, as hours a week.
    case thisYearSoFar(hoursPerWeek: Double)
    /// Started this year and gave a total.
    case soFar(hours: Double)
    /// Started this year from nothing (or no estimates at all).
    case fromZero

    static func make(estimates: [YearRate], currentYear: Int) -> SetupLink {
        if let last = estimates.first(where: { $0.year == currentYear - 1 }) {
            return .lastYear(hoursPerWeek: last.hoursPerWeek)
        }
        guard let this = estimates.first(where: { $0.year == currentYear }) else { return .fromZero }
        if let total = this.totalHours { return total > 0 ? .soFar(hours: total) : .fromZero }
        return this.hoursPerWeek > 0 ? .thisYearSoFar(hoursPerWeek: this.hoursPerWeek) : .fromZero
    }

    /// "Last year: 12 h a week."
    var bold: String {
        switch self {
        case .lastYear(let h): String(localized: "Last year: \(WeeklyTarget.number(h)) h a week.")
        case .thisYearSoFar(let h): String(localized: "This year so far: \(WeeklyTarget.number(h)) h a week.")
        case .soFar(let h): String(localized: "So far: \(DurationFormat.grouped(Totals.wholeHours(total: h))) h.")
        case .fromZero: String(localized: "Starting from zero.")
        }
    }

    /// "Keep that pace, or change it."
    var muted: String {
        switch self {
        case .lastYear, .thisYearSoFar: String(localized: "Keep that pace, or change it.")
        case .soFar: String(localized: "Now choose a pace for each week.")
        case .fromZero: String(localized: "Pick a pace you can keep.")
        }
    }
}

/// The finish line at the chosen pace (the forecast's chosen-pace line), for "From today on" and the setup scene.
enum FinishLineText {
    /// "At this pace, you reach 10,000 h around December 2037", "…after 2056" beyond 30 years, or
    /// "You're already past 10,000 h".
    static func sentence(total: Double, weeklyRate: Double, now: Date, calendar: Calendar = .current) -> String {
        if total >= Totals.goalHours { return String(localized: "You're already past 10,000 h") }
        let line = ForecastEngine.line(total: total, weeklyRate: weeklyRate)
        guard let months = line.monthsToGoal else {
            let year = calendar.component(.year, from: now) + ForecastEngine.horizonYears
            return String(localized: "At this pace, you reach 10,000 h after \(String(year))")
        }
        let date = ForecastText.monthYear(ForecastEngine.date(afterMonths: months, from: now), calendar: calendar)
        return String(localized: "At this pace, you reach 10,000 h around \(date)")
    }

    /// The gold chip in the setup scene: "Finish line ~Dec 2037", "Finish line after 2056", "Finish line reached".
    static func chip(total: Double, weeklyRate: Double, now: Date, calendar: Calendar = .current) -> String {
        if total >= Totals.goalHours { return String(localized: "Finish line reached") }
        let line = ForecastEngine.line(total: total, weeklyRate: weeklyRate)
        return String(localized: "Finish line \(ForecastText.shortFinish(line, now: now, calendar: calendar))")
    }

    /// For VoiceOver: "finish line around December 2037", "finish line after 2056", "finish line reached".
    static func spoken(total: Double, weeklyRate: Double, now: Date, calendar: Calendar = .current) -> String {
        if total >= Totals.goalHours { return String(localized: "finish line reached") }
        let line = ForecastEngine.line(total: total, weeklyRate: weeklyRate)
        guard let months = line.monthsToGoal else {
            let year = calendar.component(.year, from: now) + ForecastEngine.horizonYears
            return String(localized: "finish line after \(String(year))")
        }
        let date = ForecastText.monthYear(ForecastEngine.date(afterMonths: months, from: now), calendar: calendar)
        return String(localized: "finish line around \(date)")
    }
}

/// What the setup scene shows: the sun's height and the chips, filled in as setup goes on.
struct SetupSceneState: Equatable, Sendable {
    enum Chip: Equatable, Sendable { case craft, startYear, score, pace, finish }

    var craftName: String
    var startYear: Int?
    var score: Double?
    var weeklyPace: Double?
    /// Step 4 only: the finish line at the chosen pace.
    var showsFinish = false
    /// The chip being changed on this screen.
    var editing: Chip?
    var now: Date = Date()

    /// 0 on the horizon, 1 at the finish line (10,000 h).
    var sunHeight: Double { Totals.progress(total: score ?? 0) }

    var startText: String? { startYear.map { String(localized: "Since \(String($0))") } }
    var scoreText: String? { score.map { "\(DurationFormat.grouped(Totals.wholeHours(total: $0))) h" } }
    var paceText: String? { weeklyPace.map { String(localized: "\(WeeklyTarget.number($0)) h a week") } }
    var finishText: String? {
        guard showsFinish, let pace = weeklyPace else { return nil }
        return FinishLineText.chip(total: score ?? 0, weeklyRate: pace, now: now)
    }

    /// One sentence for VoiceOver: "Your game: Calligraphy, since 2019, 3,100 hours so far, 12 hours a week, finish
    /// line around December 2037." Parts not yet set are left out.
    var spoken: String {
        var parts = [craftName.trimmingCharacters(in: .whitespacesAndNewlines)].filter { !$0.isEmpty }
        if let startYear { parts.append(String(localized: "since \(String(startYear))")) }
        if let score { parts.append(String(localized: "\(DurationFormat.grouped(Totals.wholeHours(total: score))) hours so far")) }
        if let weeklyPace { parts.append(String(localized: "\(WeeklyTarget.number(weeklyPace)) hours a week")) }
        if showsFinish, let weeklyPace { parts.append(FinishLineText.spoken(total: score ?? 0, weeklyRate: weeklyPace, now: now)) }
        guard !parts.isEmpty else { return String(localized: "Your game") }
        return String(localized: "Your game: \(parts.joined(separator: ", ")).")
    }
}

/// "Can we check in?" (update 53): notifications are asked about once, on the first session, instead of in setup.
enum NotificationAskRule {
    /// Shown once ever, while a session is running, and only while iOS has never asked.
    static func shouldShow(alreadyShown: Bool, permission: NotificationPermission, sessionRunning: Bool) -> Bool {
        !alreadyShown && permission == .notAsked && sessionRunning
    }
}

/// "Bring the weather in?" (update 53): the weather invite, a week after setup, instead of a setup step.
enum WeatherInviteRule {
    static let daysAfterSetup = 7

    /// All must hold: 7 days since onboarding, the weather off, never shown before, a session just saved and Home
    /// back with nothing else on top, and no timer running.
    static func shouldShow(now: Date, onboardedAt: Date, weatherOn: Bool, alreadyShown: Bool, sessionJustSaved: Bool,
                           timerRunning: Bool, somethingElseShowing: Bool, calendar: Calendar = .current) -> Bool {
        guard !alreadyShown, !weatherOn, sessionJustSaved, !timerRunning, !somethingElseShowing else { return false }
        guard let due = calendar.date(byAdding: .day, value: daysAfterSetup, to: onboardedAt) else { return false }
        return now >= due
    }
}

/// The time strip on "Before today" and "From today on".
enum SetupTimeStrip: Equatable, Sendable {
    case beforeToday, nextYear

    var spoken: String {
        switch self {
        case .beforeToday: String(localized: "This screen is about the time before today")
        case .nextYear: String(localized: "This screen is about the next 12 months")
        }
    }
}
