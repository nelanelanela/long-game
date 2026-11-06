import Testing
import Foundation
@testable import LongGame

let utc: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(secondsFromGMT: 0)!
    c.firstWeekday = 2
    return c
}()

func day(_ y: Int, _ m: Int, _ d: Int, hour: Int = 12) -> Date {
    utc.date(from: DateComponents(year: y, month: m, day: d, hour: hour))!
}

func session(_ date: Date, hours: Double) -> SessionRecord {
    SessionRecord(start: date, durationSec: hours * 3600)
}

struct BaselineTests {
    @Test func fullPastYearsCount52Weeks() {
        let est = [YearRate(year: 2023, hoursPerWeek: 5), YearRate(year: 2024, hoursPerWeek: 10)]
        let h = Baseline.hours(estimates: est, onboardingDate: day(2025, 1, 1), calendar: utc)
        #expect(h == 5 * 52 + 10 * 52)
    }

    @Test func onboardingYearUsesWeeksElapsed() {
        // 1 Jan + 70 days = 10 weeks elapsed
        let onboarding = day(2025, 3, 12)
        let weeks = Baseline.weeksElapsedInYear(of: onboarding, calendar: utc)
        #expect(weeks == 10)
        let h = Baseline.hours(estimates: [YearRate(year: 2025, hoursPerWeek: 6)], onboardingDate: onboarding, calendar: utc)
        #expect(h == 60)
    }

    @Test func startingThisYearUsesOnlyThisYear() {
        let h = Baseline.hours(estimates: [YearRate(year: 2025, hoursPerWeek: 4)], onboardingDate: day(2025, 1, 1), calendar: utc)
        #expect(h == 0)
    }

    @Test func designExample() {
        let rates: [Double] = [3, 5, 6, 8, 10, 8, 12, 12]
        let est = rates.enumerated().map { YearRate(year: 2019 + $0.offset, hoursPerWeek: $0.element) }
        let h = Baseline.hours(estimates: est, onboardingDate: day(2026, 10, 25), calendar: utc)
        #expect(abs(h - 3208) < 10)
    }
}

struct TotalsTests {
    @Test func loggedAndTotal() {
        let logged = Totals.loggedHours([session(day(2026, 1, 1), hours: 1.5), session(day(2026, 1, 2), hours: 0.5)])
        #expect(logged == 2)
        #expect(Totals.total(baseline: 100, logged: logged) == 102)
    }

    @Test func progressIsCappedButHoursKeepCounting() {
        #expect(Totals.progress(total: 5000) == 0.5)
        #expect(Totals.progress(total: 12_000) == 1)
        #expect(Totals.wholeHours(total: 12_000.9) == 12_000)
    }

    @Test func percentRoundsButNeverShows100Early() {
        #expect(Totals.percent(total: 3294) == 33)
        #expect(Totals.percent(total: 9999.9) == 99)
        #expect(Totals.percent(total: 10_000) == 100)
    }

    @Test func wholeHoursRoundsDown() {
        #expect(Totals.wholeHours(total: 3294.99) == 3294)
    }
}

struct WeekTests {
    @Test func mondayAndSundayStarts() {
        let thursday = day(2026, 10, 22)
        #expect(WeekMath.startOfWeek(thursday, weekStart: .monday, calendar: utc) == day(2026, 10, 19, hour: 0))
        #expect(WeekMath.startOfWeek(thursday, weekStart: .sunday, calendar: utc) == day(2026, 10, 18, hour: 0))
    }

    @Test func thisWeekCountsOnlyCurrentWeek() {
        let now = day(2026, 10, 22, hour: 18)
        let s = [session(day(2026, 10, 18), hours: 3),   // Sunday, previous week for Monday start
                 session(day(2026, 10, 19), hours: 2),
                 session(day(2026, 10, 22), hours: 1.5)]
        #expect(WeekMath.thisWeekHours(s, now: now, weekStart: .monday, calendar: utc) == 3.5)
        #expect(WeekMath.thisWeekHours(s, now: now, weekStart: .sunday, calendar: utc) == 6.5)
    }
}

struct PaceTests {
    @Test func noDataUsesLatestEstimate() {
        let now = day(2026, 10, 25)
        #expect(abs(Pace.hoursPerWeek(sessions: [], latestEstimate: 12, onboardingDate: now, now: now, calendar: utc) - 12) < 0.2)
    }

    @Test func blendsDuringFirstTwelveWeeks() {
        let onboarding = day(2026, 9, 6, hour: 0)           // 6 weeks before now
        let now = onboarding.addingTimeInterval(6 * 7 * 86_400)
        let s = [session(day(2026, 9, 20), hours: 12)]      // 12 h over 6 weeks = 2 h/wk
        let pace = Pace.hoursPerWeek(sessions: s, latestEstimate: 10, onboardingDate: onboarding, now: now, calendar: utc)
        #expect(abs(pace - (0.5 * 2 + 0.5 * 10)) < 0.0001)
    }

    @Test func afterTwelveWeeksUsesLoggedOnly() {
        let onboarding = day(2026, 1, 1, hour: 0)
        let now = day(2026, 10, 25)
        // 24 hours inside the last 12 weeks = 2 h/wk
        let s = [session(day(2026, 9, 1), hours: 12), session(day(2026, 10, 1), hours: 12), session(day(2026, 3, 1), hours: 100)]
        #expect(abs(Pace.hoursPerWeek(sessions: s, latestEstimate: 10, onboardingDate: onboarding, now: now, calendar: utc) - 2) < 0.0001)
    }
}

struct PracticeDaysTests {
    func daily(_ days: [Date]) -> [Date: Double] {
        Practice.dailySeconds(days.map { session($0, hours: 1) }, calendar: utc)
    }

    @Test func sessionsOnTheSameDayAreOneDay() {
        let d = daily([day(2026, 1, 1, hour: 8), day(2026, 1, 1, hour: 20)])
        #expect(d.count == 1)
        #expect(d[day(2026, 1, 1, hour: 0)] == 7200)
    }

    @Test func midnightCrossingCountsOnStartDay() {
        let s = SessionRecord(start: day(2026, 1, 1, hour: 23), durationSec: 7200)
        let d = Practice.dailySeconds([s], calendar: utc)
        #expect(d[day(2026, 1, 1, hour: 0)] == 7200)
        #expect(d[day(2026, 1, 2, hour: 0)] == nil)
    }

    @Test func activeDaysInWindow() {
        let d = daily([day(2026, 1, 1), day(2026, 6, 1), day(2026, 6, 2)])
        #expect(Practice.activeDays(daily: d, from: day(2026, 5, 1), to: day(2026, 7, 1), calendar: utc) == 2)
    }

    @Test func deletingTheOnlySessionRestoresRestDay() {
        let kept = daily([day(2026, 10, 24)])
        #expect(Practice.activeDays(daily: kept, from: day(2026, 10, 1), to: day(2026, 10, 25), calendar: utc) == 1)
        #expect(Practice.activeDays(daily: [:], from: day(2026, 10, 1), to: day(2026, 10, 25), calendar: utc) == 0)
    }
}

struct CalendarTests {
    @Test func levels() {
        #expect(CalendarLevel.level(hours: 0) == .rest)
        #expect(CalendarLevel.level(hours: 0.25) == .under1)
        #expect(CalendarLevel.level(hours: 1) == .from1to2)
        #expect(CalendarLevel.level(hours: 2.5) == .from2to3)
        #expect(CalendarLevel.level(hours: 3) == .over3)
        #expect(CalendarLevel.level(hours: 9) == .over3)
    }

    @Test func gridHas53WeeksOfSevenDaysEndingThisWeek() {
        let today = day(2026, 10, 22)
        let grid = CalendarGrid.weeks(endingOn: today, weekStart: .monday, calendar: utc)
        #expect(grid.count == 53)
        #expect(grid.allSatisfy { $0.count == 7 })
        #expect(grid.last?.first == day(2026, 10, 19, hour: 0))
        #expect(grid.last?.map { utc.startOfDay(for: $0) }.contains(utc.startOfDay(for: today)) == true)
        #expect(utc.component(.weekday, from: grid[0][0]) == 2)
    }

    @Test func gridRespectsSundayStart() {
        let grid = CalendarGrid.weeks(endingOn: day(2026, 10, 22), weekStart: .sunday, calendar: utc)
        #expect(utc.component(.weekday, from: grid[10][0]) == 1)
    }
}

struct ForecastTests {
    let now = day(2026, 10, 25)
    // 52 weeks = 364 days; a month is 30.436875 days, so 10 h a week adds 10 × 30.436875 / 7 hours a month.
    private func perMonth(_ rate: Double) -> Double { rate * ForecastEngine.daysPerMonth / 7 }

    @Test func theFinishIsTodayPlusHoursToGoOverTheRate() {
        // 1,500 h to go at 10 h/wk = 150 weeks.
        let r = ForecastEngine.line(total: 8_500, weeklyRate: 10)
        #expect(abs((r.monthsToGoal ?? 0) - 1_500 / perMonth(10)) < 1e-9)
        #expect(r.points.count == 2)
        #expect(r.points.last?.hours == 10_000)
        let weeks = (r.monthsToGoal ?? 0) * ForecastEngine.daysPerMonth / 7
        #expect(abs(weeks - 150) < 1e-9)
    }

    @Test func severalPaces() {
        for (rate, total) in [(6.0, 3_294.0), (7, 100), (12, 5_000), (30, 9_000), (168, 0)] {
            let months = ForecastEngine.line(total: total, weeklyRate: rate).monthsToGoal
            #expect(abs((months ?? 0) - (10_000 - total) / perMonth(rate)) < 1e-9)
        }
    }

    @Test func aPaceOfZeroNeverArrives() {
        let r = ForecastEngine.line(total: 100, weeklyRate: 0)
        #expect(r.monthsToGoal == nil)
        #expect(r.points.last?.monthsFromNow == Double(ForecastEngine.horizonMonths))
        #expect(r.points.last?.hours == 100)
        #expect(ForecastEngine.line(total: 100, weeklyRate: -3).monthsToGoal == nil)
    }

    @Test func beyondThirtyYearsLeavesTheDateOutButKeepsTheLine() {
        // 1 h/wk for 30 years is about 1,566 h.
        let r = ForecastEngine.line(total: 3_000, weeklyRate: 1)
        #expect(r.monthsToGoal == nil)
        let end = r.points.last
        #expect(end?.monthsFromNow == Double(ForecastEngine.horizonMonths))
        #expect(abs((end?.hours ?? 0) - (3_000 + perMonth(1) * 360)) < 1e-6)
        #expect(ForecastText.headline(r, now: now, calendar: utc) == "After 2056")
        #expect(ForecastText.year(r, now: now, calendar: utc) == "after 2056")
        #expect(ForecastText.homeMastery(r, now: now, calendar: utc) == "after 2056")
    }

    @Test func alreadyPastTenThousand() {
        let r = ForecastEngine.line(total: 10_500, weeklyRate: 5)
        #expect(r.monthsToGoal == 0)
        #expect(r.points.count == 1)
    }

    @Test func theChosenLineAddsTheWhatIfExtraAndTheRecentLineDoesNot() {
        let base = ForecastEngine.forecast(total: 3_294, chosenPace: 12, recentPace: 8)
        let more = ForecastEngine.forecast(total: 3_294, chosenPace: 12, extra: 5, recentPace: 8)
        #expect(base.chosenRate == 12 && more.chosenRate == 17)
        #expect((more.chosen.monthsToGoal ?? 0) < (base.chosen.monthsToGoal ?? 0))
        #expect(more.recent == base.recent)
    }

    @Test func extraHoursMakeItSooner() {
        // 6,706 h to go: 12 h/wk is 1,285 weeks away, 17 h/wk about 960 weeks.
        let sooner = ForecastEngine.monthsSooner(total: 3_294, chosenPace: 12, extra: 5)
        #expect((sooner ?? 0) > 12)
        #expect(ForecastEngine.monthsSooner(total: 3_294, chosenPace: 12, extra: 0) == 0)
        #expect(ForecastEngine.monthsSooner(total: 3_294, chosenPace: 0, extra: 0) == nil)
    }

    @Test func theRecentPaceEqualOrFasterIsSaidInWords() {
        let slower = ForecastEngine.forecast(total: 3_294, chosenPace: 12, recentPace: 8)
        #expect(!slower.recentIsAsFast)
        #expect(ForecastText.recentLine(slower, now: now, calendar: utc).hasPrefix("At your recent pace: around "))
        for recent in [12.0, 15] {
            let f = ForecastEngine.forecast(total: 3_294, chosenPace: 12, recentPace: recent)
            #expect(f.recentIsAsFast)
            #expect(ForecastText.recentLine(f, now: now, calendar: utc) == "You're already playing at this pace")
        }
        let never = ForecastEngine.forecast(total: 3_000, chosenPace: 12, recentPace: 1)
        #expect(ForecastText.recentLine(never, now: now, calendar: utc) == "At your recent pace: after 2056")
    }

    @Test func textFormatting() {
        let r = ScenarioResult(monthsToGoal: 12, points: [])
        #expect(ForecastText.headline(r, now: now, calendar: utc).hasSuffix("2027"))
        #expect(ForecastText.homeMastery(r, now: now, calendar: utc) == "~2027")
        #expect(ForecastText.whatIf(extra: 0, total: 3_000, chosenPace: 12, now: now, calendar: utc) == "On top of your chosen pace of 12 h a week.")
        #expect(ForecastText.whatIf(extra: 0, total: 3_000, chosenPace: 7.5, now: now, calendar: utc) == "On top of your chosen pace of 7.5 h a week.")
        #expect(ForecastText.whatIf(extra: 10, total: 3_000, chosenPace: 10, now: now, calendar: utc).hasPrefix("About"))
    }

    @Test func crossedTheFinishLine() {
        let text = ForecastText.crossed(on: day(2035, 5, 12), calendar: utc, locale: Locale(identifier: "en_GB"))
        #expect(text == "You crossed the finish line on 12 May 2035")
    }
}

@Suite struct ForecastPaceTests {
    // 1,900 h over 6 years (Jan 2020 – Jan 2026) ≈ 6.1 h/wk lifetime average.
    @Test func lifetimeAverageIsTheStartingPace() {
        let est = (2020...2025).map { YearRate(year: $0, hoursPerWeek: 6.09) }
        let now = day(2026, 1, 1)
        let total = 6.09 * 52 * 6
        let r = ForecastEngine.forecastPace(total: total, estimates: est, sessions: [], onboardingDate: now, now: now, calendar: utc)
        #expect(abs(r - 6.09 * 52 * 6 / (365.0 * 6 + 2) * 7) < 0.1)
    }

    @Test func recentEntriesPullThePaceTheirWay() {
        let est = (2020...2025).map { YearRate(year: $0, hoursPerWeek: 6) }
        let onboarding = day(2026, 1, 1), now = day(2026, 4, 1)
        let none = ForecastEngine.forecastPace(total: 1900, estimates: est, sessions: [], onboardingDate: onboarding, now: now, calendar: utc)
        let busy = (0..<12).map { session(day(2026, 1, 5 + $0 * 7), hours: 20) }
        let more = ForecastEngine.forecastPace(total: 1900 + 240, estimates: est, sessions: busy, onboardingDate: onboarding, now: now, calendar: utc)
        #expect(more > none)
        #expect(none > 0)
    }
}
