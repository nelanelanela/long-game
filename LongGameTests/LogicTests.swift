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

struct StreakTests {
    func daily(_ days: [Date]) -> [Date: Double] {
        Streaks.dailySeconds(days.map { session($0, hours: 1) }, calendar: utc)
    }

    @Test func currentStreakIncludingToday() {
        let d = daily([day(2026, 10, 23), day(2026, 10, 24), day(2026, 10, 25)])
        #expect(Streaks.current(daily: d, today: day(2026, 10, 25), calendar: utc) == 3)
    }

    @Test func currentStreakSurvivesUntilEndOfToday() {
        let d = daily([day(2026, 10, 23), day(2026, 10, 24)])
        #expect(Streaks.current(daily: d, today: day(2026, 10, 25), calendar: utc) == 2)
    }

    @Test func gapBreaksStreak() {
        let d = daily([day(2026, 10, 20), day(2026, 10, 24)])
        #expect(Streaks.current(daily: d, today: day(2026, 10, 25), calendar: utc) == 1)
        #expect(Streaks.current(daily: d, today: day(2026, 10, 27), calendar: utc) == 0)
    }

    @Test func longestStreak() {
        let d = daily([day(2026, 1, 1), day(2026, 1, 2), day(2026, 1, 3), day(2026, 1, 10), day(2026, 1, 11)])
        #expect(Streaks.longest(daily: d, calendar: utc) == 3)
        #expect(Streaks.longest(daily: [:], calendar: utc) == 0)
    }

    @Test func sessionsOnTheSameDayAreOneDay() {
        let d = daily([day(2026, 1, 1, hour: 8), day(2026, 1, 1, hour: 20)])
        #expect(d.count == 1)
        #expect(Streaks.longest(daily: d, calendar: utc) == 1)
    }

    @Test func midnightCrossingCountsOnStartDay() {
        let s = SessionRecord(start: day(2026, 1, 1, hour: 23), durationSec: 7200)
        let d = Streaks.dailySeconds([s], calendar: utc)
        #expect(d[day(2026, 1, 1, hour: 0)] == 7200)
        #expect(d[day(2026, 1, 2, hour: 0)] == nil)
    }

    @Test func activeDaysInWindow() {
        let d = daily([day(2026, 1, 1), day(2026, 6, 1), day(2026, 6, 2)])
        #expect(Streaks.activeDays(daily: d, from: day(2026, 5, 1), to: day(2026, 7, 1), calendar: utc) == 2)
    }

    @Test func deletingTheOnlySessionRestoresRestDay() {
        let kept = daily([day(2026, 10, 24)])
        #expect(Streaks.current(daily: kept, today: day(2026, 10, 25), calendar: utc) == 1)
        #expect(Streaks.current(daily: [:], today: day(2026, 10, 25), calendar: utc) == 0)
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
    @Test func trendOfRisingYears() {
        let rates = (0..<5).map { YearRate(year: 2020 + $0, hoursPerWeek: Double(2 * $0 + 3)) }
        #expect(abs(ForecastEngine.trend(yearly: rates) - 2) < 0.0001)
    }

    @Test func trendIsClamped() {
        let rates = [YearRate(year: 2020, hoursPerWeek: 0), YearRate(year: 2021, hoursPerWeek: 30)]
        #expect(ForecastEngine.trend(yearly: rates) == 2)
        let falling = [YearRate(year: 2020, hoursPerWeek: 30), YearRate(year: 2021, hoursPerWeek: 0)]
        #expect(ForecastEngine.trend(yearly: falling) == -2)
    }

    @Test func trendNeedsTwoYears() {
        #expect(ForecastEngine.trend(yearly: [YearRate(year: 2020, hoursPerWeek: 5)]) == 0)
    }

    @Test func flatPaceReachesGoalOnTime() {
        // 10 h/wk, no trend: 1,500 h to go; low scenario uses 0.75 r = 7.5 h/wk
        let r = ForecastEngine.simulate(.low, total: 8500, pace: 10, trend: 0)
        let expected = 1500 / (7.5 * 52 / 12)
        #expect(abs((r.monthsToGoal ?? 0) - expected) < 0.01)
        let mid = ForecastEngine.simulate(.mid, total: 8500, pace: 10, trend: 0)
        #expect(abs((mid.monthsToGoal ?? 0) - 1500 / (10 * 52 / 12)) < 0.01)
    }

    @Test func scenariosAreOrdered() {
        let f = ForecastEngine.forecast(total: 3294, pace: 12, trend: 0.8)
        let high = f.high.monthsToGoal!, mid = f.mid.monthsToGoal!, low = f.low.monthsToGoal!
        #expect(high < mid && mid < low)
    }

    @Test func midRateIsCapped() {
        let rate = ForecastEngine.weeklyRate(.mid, years: 20, pace: 10, trend: 2, extra: 0)
        #expect(rate == 15)
        #expect(ForecastEngine.weeklyRate(.high, years: 20, pace: 10, trend: 2, extra: 0) == 20)
    }

    @Test func ratesNeverGoNegative() {
        #expect(ForecastEngine.weeklyRate(.mid, years: 10, pace: 2, trend: -2, extra: 0) == 0)
    }

    @Test func zeroPaceNeverReaches() {
        let r = ForecastEngine.simulate(.mid, total: 100, pace: 0, trend: 0)
        #expect(r.monthsToGoal == nil)
        #expect(r.points.count == ForecastEngine.horizonMonths + 1)
    }

    @Test func slowPaceDoesNotReachWithin15Years() {
        // 1 h/wk for 15 years is 780 h
        #expect(ForecastEngine.simulate(.mid, total: 3000, pace: 1, trend: 0).monthsToGoal == nil)
    }

    @Test func alreadyThere() {
        let r = ForecastEngine.simulate(.mid, total: 10_500, pace: 5, trend: 0)
        #expect(r.monthsToGoal == 0)
    }

    @Test func extraHoursMakeItSooner() {
        let sooner = ForecastEngine.monthsSooner(total: 3294, pace: 12, trend: 0.5, extra: 5)
        #expect((sooner ?? 0) > 12)
        #expect(ForecastEngine.monthsSooner(total: 3294, pace: 12, trend: 0.5, extra: 0) == 0)
    }

    @Test func interpolatesInsideCrossingMonth() {
        // 52/12 * 12 = 52 h per month; 26 h to go => half a month
        let r = ForecastEngine.simulate(.low, total: 9974, pace: 16, trend: 0)  // low rate 12
        #expect(abs((r.monthsToGoal ?? 0) - 0.5) < 0.0001)
    }

    @Test func yearlyRatesUseLoggedDataForCurrentYear() {
        let est = [YearRate(year: 2025, hoursPerWeek: 5), YearRate(year: 2026, hoursPerWeek: 5)]
        let onboarding = day(2026, 1, 1, hour: 0)
        let now = day(2026, 1, 1, hour: 0).addingTimeInterval(10 * 7 * 86_400)
        let s = [session(day(2026, 2, 1), hours: 40)]    // 40 h over 10 weeks = 4 h/wk
        let rates = ForecastEngine.yearlyRates(estimates: est, sessions: s, onboardingDate: onboarding, now: now, calendar: utc)
        #expect(rates.map(\.year) == [2025, 2026])
        #expect(abs(rates[1].hoursPerWeek - 4) < 0.0001)
    }

    @Test func yearlyRatesKeepEstimateWithLessThanTwoWeeks() {
        let est = [YearRate(year: 2026, hoursPerWeek: 7)]
        let now = day(2026, 10, 25)
        let rates = ForecastEngine.yearlyRates(estimates: est, sessions: [session(day(2026, 10, 24), hours: 1)],
                                               onboardingDate: day(2026, 10, 20, hour: 0), now: now, calendar: utc)
        #expect(rates[0].hoursPerWeek == 7)
    }

    @Test func textFormatting() {
        let now = day(2026, 10, 25)
        let r = ScenarioResult(monthsToGoal: 12, points: [])
        #expect(ForecastText.headline(r, now: now, calendar: utc).hasSuffix("2027"))
        #expect(ForecastText.headline(ScenarioResult(monthsToGoal: nil, points: []), now: now, calendar: utc) == "After 2041")
        #expect(ForecastText.homeMastery(r, now: now, calendar: utc) == "~2027")
        #expect(ForecastText.whatIf(extra: 0, total: 3000, pace: 10, trend: 0, now: now, calendar: utc).hasPrefix("Based on"))
        #expect(ForecastText.whatIf(extra: 10, total: 3000, pace: 10, trend: 0, now: now, calendar: utc).hasPrefix("About"))
    }
}
