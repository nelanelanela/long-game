import Foundation

// Your year: the long game in one picture, to keep or share (section 17). Pure functions, nothing stored.
// Calm, not competitive: nothing about other people, and notes never appear.

/// A session with a photo, by id, so the card can pick the year's most recent ones.
struct YearPhoto: Equatable, Sendable {
    var id: UUID
    var start: Date
}

struct YearSummary: Equatable, Sendable {
    var year: Int
    /// Logged hours that started in the year (the onboarding estimate is not included).
    var hours: Double
    /// Days in the year with any logged time.
    var daysOfPractice: Int
    /// The middle number of practice days per week over the year's complete weeks (0 with none).
    var rhythm: Int
    /// 1...12: the month with the most hours, the later one on a tie. Nil with no hours.
    var mostPlayedMonth: Int?
    /// The overall total at the end of the year, or now for the current year.
    var total: Double
    var percent: Int
    /// The level of every day with time logged (days without are rest days).
    var levels: [Date: CalendarLevel]
    /// Set when the game began during this year ("played since 12 March").
    var since: Date?
    /// The year's sessions with a photo, newest first.
    var photos: [YearPhoto]
    /// Whole days from the start of the game or the year until the end of the year or now.
    var daysCovered: Int

    /// The cards and entry rows need at least four weeks of data.
    var hasEnoughData: Bool { daysCovered >= YearSummary.minimumDays && daysOfPractice > 0 }
    /// Photos is only offered with at least six photos from the year.
    var offersPhotosCard: Bool { photos.count >= YearSummary.photosNeeded }

    static let minimumDays = 28
    static let photosNeeded = 6

    // MARK: Which year, and which years

    /// The current year, except from 1 to 15 January, when the year that just ended is shown.
    static func defaultYear(now: Date, calendar: Calendar = .current) -> Int {
        let c = calendar.dateComponents([.year, .month, .day], from: now)
        let year = c.year ?? 2026
        return (c.month == 1 && (c.day ?? 1) <= 15) ? year - 1 : year
    }

    /// Years with any logged time, newest first (the title menu offers these when there is more than one).
    static func yearsWithData(sessions: [SessionRecord], calendar: Calendar = .current) -> [Int] {
        Array(Set(sessions.map { calendar.component(.year, from: $0.start) })).sorted(by: >)
    }

    /// The Long game tab's row shows from 1 December to 15 January only.
    static func showsOnLongGame(now: Date, calendar: Calendar = .current) -> Bool {
        let c = calendar.dateComponents([.month, .day], from: now)
        return c.month == 12 || (c.month == 1 && (c.day ?? 1) <= 15)
    }

    // MARK: Working it out

    static func make(year: Int, sessions: [SessionRecord], photos: [YearPhoto] = [], estimates: [YearRate],
                     onboardingDate: Date, now: Date, weekStart: WeekStart,
                     calendar: Calendar = .current) -> YearSummary {
        let cal = WeekMath.calendar(calendar, weekStart: weekStart)
        let yearStart = cal.date(from: DateComponents(year: year, month: 1, day: 1)) ?? now
        let nextYearStart = cal.date(from: DateComponents(year: year + 1, month: 1, day: 1)) ?? now
        let inYear = sessions.filter { $0.start >= yearStart && $0.start < nextYearStart }

        let hours = Totals.loggedHours(inYear)
        let daily = Practice.dailySeconds(inYear, calendar: cal)
        let levels = daily.filter { $0.value > 0 }.mapValues { CalendarLevel.level(hours: $0 / 3600) }

        // The game began during this year: the numbers count from then.
        let onboarded = cal.startOfDay(for: onboardingDate)
        let began = cal.component(.year, from: onboarded) == year ? onboarded : nil
        let firstDay = max(yearStart, began ?? yearStart)

        // Total: the baseline plus everything logged up to the end of the year (or now).
        let until = min(nextYearStart, now)
        let logged = Totals.loggedHours(sessions.filter { $0.start < until })
        let total = Totals.total(baseline: Baseline.hours(estimates: estimates, onboardingDate: onboardingDate, calendar: cal), logged: logged)

        let lastDay = min(cal.startOfDay(for: now), cal.date(byAdding: .day, value: -1, to: nextYearStart) ?? now)
        let covered = max(0, (cal.dateComponents([.day], from: firstDay, to: lastDay).day ?? -1) + 1)

        return YearSummary(
            year: year, hours: hours, daysOfPractice: levels.count,
            rhythm: rhythm(daily: daily, firstDay: firstDay, yearStart: yearStart, nextYearStart: nextYearStart, now: now, calendar: cal),
            mostPlayedMonth: mostPlayedMonth(inYear, calendar: cal),
            total: total, percent: Totals.percent(total: total), levels: levels, since: began,
            photos: photos.filter { $0.start >= yearStart && $0.start < nextYearStart }.sorted { $0.start > $1.start },
            daysCovered: covered)
    }

    /// The median of practice days per week over the weeks that lie fully inside the year, are already over, and
    /// began on or after the first day of the game.
    static func rhythm(daily: [Date: Double], firstDay: Date, yearStart: Date, nextYearStart: Date, now: Date,
                       calendar cal: Calendar) -> Int {
        let today = cal.startOfDay(for: now)
        var counts: [Int] = []
        var start = WeekMath.startOfWeek(yearStart, weekStart: weekStart(of: cal), calendar: cal)
        if start < yearStart { start = cal.date(byAdding: .day, value: 7, to: start) ?? start }   // the first week is partial
        while let end = cal.date(byAdding: .day, value: 7, to: start), end <= nextYearStart, end <= today {
            if start >= firstDay {
                counts.append((0..<7).reduce(0) { n, offset in
                    guard let day = cal.date(byAdding: .day, value: offset, to: start) else { return n }
                    return n + ((daily[day] ?? 0) > 0 ? 1 : 0)
                })
            }
            start = end
        }
        guard !counts.isEmpty else { return 0 }
        return counts.sorted()[counts.count / 2]
    }

    private static func weekStart(of cal: Calendar) -> WeekStart { cal.firstWeekday == 1 ? .sunday : .monday }

    /// The month (1...12) with the most hours; on a tie, the later month.
    static func mostPlayedMonth(_ sessions: [SessionRecord], calendar: Calendar) -> Int? {
        var perMonth: [Int: Double] = [:]
        for s in sessions { perMonth[calendar.component(.month, from: s.start), default: 0] += s.durationSec }
        guard let top = perMonth.values.max(), top > 0 else { return nil }
        return perMonth.filter { abs($0.value - top) < 1 }.keys.max()
    }

    // MARK: The year's strip

    /// 53 (or 54) columns of 7 days in week order; nil for days outside the year or still to come.
    static func grid(year: Int, levels: [Date: CalendarLevel], now: Date, weekStart: WeekStart,
                     calendar: Calendar = .current) -> [[CalendarLevel?]] {
        let cal = WeekMath.calendar(calendar, weekStart: weekStart)
        guard let yearStart = cal.date(from: DateComponents(year: year, month: 1, day: 1)),
              let nextYear = cal.date(from: DateComponents(year: year + 1, month: 1, day: 1)) else { return [] }
        let today = cal.startOfDay(for: now)
        var column = WeekMath.startOfWeek(yearStart, weekStart: weekStart, calendar: calendar)
        var result: [[CalendarLevel?]] = []
        while column < nextYear {
            result.append((0..<7).map { offset in
                guard let day = cal.date(byAdding: .day, value: offset, to: column),
                      day >= yearStart, day < nextYear, day <= today else { return nil }
                return levels[day] ?? .rest
            })
            column = cal.date(byAdding: .day, value: 7, to: column) ?? nextYear
        }
        return result
    }
}

/// The words on the cards, so they can be tested and read aloud.
enum YearCardText {
    /// "3,294": commas on every device, like the rest of the app and the "of 10,000" beside it (some regions
    /// would write "3 294").
    private static func number(_ n: Int, locale: Locale = .current) -> String {
        DurationFormat.grouped(n)
    }

    /// "+624 h", or "241 days" with hours hidden.
    static func big(_ s: YearSummary, showHours: Bool, locale: Locale = .current) -> String {
        showHours ? "+" + number(Int(s.hours.rounded()), locale: locale) + " h"
                  : String(localized: "\(s.daysOfPractice) days")
    }

    /// "played this year", "played since 12 March", or "of practice this year" with hours hidden.
    static func caption(_ s: YearSummary, showHours: Bool, calendar: Calendar = .current) -> String {
        if let since = s.since {
            let day = dayMonth(since, calendar: calendar)
            return showHours ? String(localized: "played since \(day)") : String(localized: "of practice since \(day)")
        }
        return showHours ? String(localized: "played this year") : String(localized: "of practice this year")
    }

    /// "March" in the user's language.
    static func monthName(_ month: Int, locale: Locale = .current) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        let names = calendar.monthSymbols
        return names.indices.contains(month - 1) ? names[month - 1] : ""
    }

    /// "Jan", "Apr", "Jul", "Oct", "Dec" in the user's language.
    static func monthLabels(locale: Locale = .current) -> [String] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        return [1, 4, 7, 10, 12].map { calendar.shortMonthSymbols[$0 - 1] }
    }

    static func dayMonth(_ date: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        CachedFormatter.template("dMMMM", calendar: calendar, locale: locale).string(from: date)
    }

    /// "3,294 h" or, with hours hidden, "33%".
    static func totalValue(_ s: YearSummary, showHours: Bool, locale: Locale = .current) -> String {
        showHours ? number(Totals.wholeHours(total: s.total), locale: locale) + " h" : "\(s.percent)%"
    }

    /// "of 10,000" or "of the way".
    static func totalCaption(showHours: Bool) -> String {
        showHours ? String(localized: "of 10,000") : String(localized: "of the way")
    }

    /// "241 days of practice · 3,294 of 10,000 h", or "241 days of practice · 33% of the way".
    static func photoFooter(_ s: YearSummary, showHours: Bool, locale: Locale = .current) -> String {
        let days = String(localized: "\(s.daysOfPractice) days of practice")
        let tail = showHours
            ? String(localized: "\(number(Totals.wholeHours(total: s.total), locale: locale)) of 10,000 h")
            : String(localized: "\(s.percent)% of the way")
        return days + " · " + tail
    }

    /// What VoiceOver reads for a card.
    static func spoken(_ s: YearSummary, showHours: Bool, locale: Locale = .current) -> String {
        let month = s.mostPlayedMonth.map { monthName($0, locale: locale) } ?? "–"
        if showHours {
            return String(localized: "Your \(String(s.year)) in the long game: \(number(Int(s.hours.rounded()), locale: locale)) hours played, practised \(s.rhythm) days a week, most in \(month), \(number(Totals.wholeHours(total: s.total), locale: locale)) of 10,000 hours")
        }
        return String(localized: "Your \(String(s.year)) in the long game: practised on \(s.daysOfPractice) days, \(s.rhythm) days a week, most in \(month), \(s.percent) percent of the way to 10,000 hours")
    }
}
