import Testing
import Foundation
@testable import LongGame

struct GaugeGeometryTests {
    @Test func theSunsCentreRunsLinearlyFromTheHorizonToTheTopTick() {
        #expect(GaugeGeometry.centreY(fraction: 0) == 220)
        #expect(GaugeGeometry.centreY(fraction: 1) == 84)
        #expect(GaugeGeometry.centreY(fraction: 0.5) == 152)
        let quarter = GaugeGeometry.centreY(fraction: 0.25), threeQuarters = GaugeGeometry.centreY(fraction: 0.75)
        #expect(abs((220 - quarter) - (quarter - GaugeGeometry.centreY(fraction: 0.5))) < 0.0001)
        #expect(abs((threeQuarters - 84) - (152 - threeQuarters)) < 0.0001)
    }

    @Test func matchesTheDesignedHeights() {
        // design/HomeWeek: 6.5 of 12 h puts the sun's centre and the pill at y = 146
        #expect(abs(GaugeGeometry.centreY(fraction: 6.5 / 12) - 146) < 0.5)
        // design/Home: 3,294 of 10,000 h puts it at y = 175
        #expect(abs(GaugeGeometry.centreY(fraction: 3_294 / 10_000) - 175) < 0.5)
    }

    @Test func aboveTheTopItStaysThereAndBelowZeroItStaysOnTheHorizon() {
        #expect(GaugeGeometry.centreY(fraction: 1.7) == 84)
        #expect(GaugeGeometry.centreY(fraction: -1) == 220)
    }
}

struct HomeGaugeTests {
    @Test func thisWeekRunsFromZeroToTheTargetWithTicksAtZeroHalfAndTarget() {
        let g = HomeGauge.week(hours: 6.5, target: 12)
        #expect(g.ticks.map(\.label) == ["0 h", "6 h", "12 h"])
        #expect(g.ticks.map(\.fraction) == [0, 0.5, 1])
        #expect(g.pill == "6.5 h")
        #expect(abs(g.fraction - 6.5 / 12) < 0.0001)
        #expect(!g.reachedTop)
    }

    @Test func theLongGameRunsFromZeroToTenThousandWithTicksEvery2500() {
        let g = HomeGauge.longGame(total: 3_294.8)
        #expect(g.ticks.map(\.label) == ["0", "2.5k", "5k", "7.5k", "10k"])
        #expect(g.ticks.map(\.fraction) == [0, 0.25, 0.5, 0.75, 1])
        #expect(g.pill == "3,294 h")
        #expect(abs(g.fraction - 0.32948) < 0.0001)
    }

    @Test func atAndAboveTheTopTheSunStaysUpAndCelebrates() {
        let met = HomeGauge.week(hours: 12, target: 12)
        let over = HomeGauge.week(hours: 13.5, target: 12)
        #expect(met.reachedTop && over.reachedTop)
        #expect(over.fraction == 1)
        #expect(over.pill == "13.5 h")
        let past = HomeGauge.longGame(total: 10_250)
        #expect(past.reachedTop)
        #expect(past.fraction == 1)
        #expect(past.pill == "10,250 h")
    }

    @Test func aHalfHourTargetKeepsAReadableMiddleTick() {
        #expect(HomeGauge.week(hours: 1, target: 5).ticks.map(\.label) == ["0 h", "2.5 h", "5 h"])
    }

    @Test func voiceOverHearsWhereTheSunIs() {
        #expect(HomeGauge.week(hours: 6.5, target: 12, daysLeft: 3).description == "The sun is just over halfway to your weekly target. 6.5 of 12 hours, 5.5 to go, 3 days left.")
        #expect(HomeGauge.week(hours: 13.5, target: 12).description == "The sun is above your weekly target. 13.5 of 12 hours.")
        #expect(HomeGauge.longGame(total: 3_294).description == "The sun is a third of the way to the finish line. 3,294 of 10,000 hours.")
    }

    @Test func tickLabelsAbbreviateThousands() {
        #expect(HomeGauge.thousands(0) == "0")
        #expect(HomeGauge.thousands(2_500) == "2.5k")
        #expect(HomeGauge.thousands(10_000) == "10k")
    }

    @Test func theTabsAreStoredByName() {
        #expect(HomeTab(rawValue: "week") == .week)
        #expect(HomeTab(rawValue: "longGame") == .longGame)
        #expect(HomeTab.allCases == [.today, .week, .longGame])
        let settings = AppSettings()
        #expect(settings.lastHomeTab == .today)
        settings.lastHomeTab = .longGame
        #expect(settings.lastHomeTabRaw == "longGame")
        settings.lastHomeTabRaw = "something old"
        #expect(settings.lastHomeTab == .today)
    }
}

struct WeekBarsTests {
    // Thursday 5 Nov 2026; weeks start on Monday.
    let thursday = day(2026, 11, 5, hour: 18)

    @Test func sevenDaysFromTheWeekStart() {
        let bars = WeekBars.make(sessions: [], now: thursday, weekStart: .monday, calendar: utc)
        #expect(bars.map(\.letter) == ["M", "T", "W", "T", "F", "S", "S"])
        #expect(bars.first?.day == day(2026, 11, 2, hour: 0))
        #expect(bars.last?.day == day(2026, 11, 8, hour: 0))
        let sunday = WeekBars.make(sessions: [], now: thursday, weekStart: .sunday, calendar: utc)
        #expect(sunday.map(\.letter) == ["S", "M", "T", "W", "T", "F", "S"])
        #expect(sunday.first?.day == day(2026, 11, 1, hour: 0))
    }

    @Test func todayAndTheDaysToComeAreMarked() {
        let bars = WeekBars.make(sessions: [], now: thursday, weekStart: .monday, calendar: utc)
        #expect(bars.map(\.isToday) == [false, false, false, true, false, false, false])
        #expect(bars.map(\.isFuture) == [false, false, false, false, true, true, true])
    }

    @Test func eachDayIsColouredLikeTheCalendarLevels() {
        let sessions = [session(day(2026, 11, 2), hours: 2.5), session(day(2026, 11, 3), hours: 1.5),
                        session(day(2026, 11, 5, hour: 9), hours: 3), session(day(2026, 11, 5, hour: 16), hours: 0.5)]
        let bars = WeekBars.make(sessions: sessions, now: thursday, weekStart: .monday, calendar: utc)
        #expect(bars[0].level == .from2to3)
        #expect(bars[1].level == .from1to2)
        #expect(bars[2].level == .rest)
        #expect(bars[3].level == .over3)
        #expect(bars[3].hours == 3.5)
        #expect(bars[4].level == .rest && bars[4].isFuture)
    }

    @Test func barsGrowWithHoursAndRestDaysAreAStub() {
        func bar(_ hours: Double, future: Bool = false) -> DayBar {
            DayBar(day: thursday, hours: hours, level: CalendarLevel.level(hours: hours), isToday: false, isFuture: future, letter: "T")
        }
        #expect(bar(0).height == 4)
        #expect(bar(0, future: true).height == 4)
        #expect(bar(1).height < bar(2).height)
        #expect(bar(2).height < bar(3).height)
        #expect(bar(4).height == 39)
        #expect(bar(9).height == 39)
        // the design: about 2.7 h is 28 pt, about 2 h is 22 pt
        #expect(abs(bar(2.7).height - 28) < 1)
        #expect(abs(bar(2).height - 22) < 1)
    }

    @Test func aSessionCrossingMidnightCountsOnTheDayItStarted() {
        let late = SessionRecord(start: day(2026, 11, 3, hour: 23), durationSec: 3 * 3600)
        let bars = WeekBars.make(sessions: [late], now: thursday, weekStart: .monday, calendar: utc)
        #expect(bars[1].hours == 3)
        #expect(bars[2].hours == 0)
    }

    @Test func sessionsFromOtherWeeksAreLeftOut() {
        let old = session(day(2026, 10, 28), hours: 5)
        let bars = WeekBars.make(sessions: [old], now: thursday, weekStart: .monday, calendar: utc)
        #expect(bars.allSatisfy { $0.hours == 0 })
    }
}

struct YearOutlookTests {
    let start = day(2026, 11, 2, hour: 0)
    var target: TargetRecord { TargetRecord(hoursPerWeek: 12, start: start, end: day(2027, 11, 2, hour: 0)) }

    @Test func theFirstDayAddsAFullYearOfTheTarget() {
        #expect(WeeklyTarget.addedByEnd(target, now: day(2026, 11, 2, hour: 15), calendar: utc) == 624)
    }

    @Test func halfwayThroughItAddsAboutHalf() throws {
        let added = try #require(WeeklyTarget.addedByEnd(target, now: day(2027, 5, 3), calendar: utc))
        #expect(abs(added - 312) < 6)
    }

    @Test func nothingWithoutATargetOrAfterItsYear() {
        #expect(WeeklyTarget.addedByEnd(nil, now: start, calendar: utc) == nil)
        #expect(WeeklyTarget.addedByEnd(target, now: day(2027, 11, 2, hour: 1), calendar: utc) == nil)
    }

    @Test func theStatNamesTheMonthItEnds() {
        #expect(DateText.monthYear(target.end, calendar: utc) == "Nov 2027")
    }

    @Test func thePercentIsNeverHundredBeforeTheTargetIsMet() {
        #expect(WeekTarget(hoursThisWeek: 11.97, target: 12, daysLeft: 1).percent == 99)
        #expect(WeekTarget(hoursThisWeek: 12, target: 12, daysLeft: 1).percent == 100)
        #expect(WeekTarget(hoursThisWeek: 13.5, target: 12, daysLeft: 1).percent == 113)
        #expect(WeekTarget(hoursThisWeek: 6.5, target: 12, daysLeft: 3).percent == 54)
    }
}

/// The faster ways of working out days and dates give exactly what the plain ways did.
struct SpeedupTests {
    /// São Paulo moved its clocks at midnight (4 November 2018 began at 01:00), the hardest case for "the start of the day".
    private var saoPaulo: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        return c
    }

    private func sessions(around day: Date, calendar: Calendar) -> [SessionRecord] {
        // Every 5 hours over three weeks, in a jumbled order, with catch-ups mixed in.
        var all: [SessionRecord] = []
        for step in 0..<100 {
            let i = (step * 37) % 100
            let offset: TimeInterval = Double(i - 50) * 5 * 3600
            all.append(SessionRecord(start: day.addingTimeInterval(offset), durationSec: Double(600 + i * 7),
                                     isCatchUp: i % 9 == 0))
        }
        return all
    }

    @Test(arguments: [false, true])
    func dailyTotalsMatchAskingTheCalendarForEachSession(sorted: Bool) {
        let cal = saoPaulo
        let day = cal.date(from: DateComponents(year: 2018, month: 11, day: 4, hour: 12))!
        var list = sessions(around: day, calendar: cal)
        if sorted { list.sort { $0.start > $1.start } }
        var plain: [Date: Double] = [:]
        for s in list { plain[cal.startOfDay(for: s.start), default: 0] += s.durationSec }
        #expect(Practice.dailySeconds(list, calendar: cal) == plain)
        let hours = IPadFigures.daily(list, calendar: cal)
        #expect(hours.keys.sorted() == plain.keys.sorted())
        for (k, v) in plain { #expect(abs(hours[k]! - v / 3600) < 1e-9) }
    }

    @Test(arguments: [WeekStart.monday, .sunday])
    func theWeekBarsOnlyLookAtThisWeekButShowTheSameDays(weekStart: WeekStart) {
        let cal = saoPaulo
        let now = cal.date(from: DateComponents(year: 2018, month: 11, day: 6, hour: 18))!
        let list = sessions(around: now, calendar: cal)
        let bars = WeekBars.make(sessions: list, now: now, weekStart: weekStart, calendar: cal)
        let wcal = WeekMath.calendar(cal, weekStart: weekStart)
        let plain = Practice.dailySeconds(list, calendar: wcal)
        #expect(bars.count == 7)
        for bar in bars { #expect(abs(bar.hours - (plain[bar.day] ?? 0) / 3600) < 1e-9) }
        #expect(bars.reduce(0) { $0 + $1.hours } > 0)
    }

    @Test func aFormatterIsMadeOnceAndFollowsTheTimeZone() {
        var london = Calendar(identifier: .gregorian)
        london.timeZone = TimeZone(identifier: "Europe/London")!
        var tokyo = london
        tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let a = CachedFormatter.pattern("HH:mm", calendar: london)
        #expect(a === CachedFormatter.pattern("HH:mm", calendar: london))
        let date = london.date(from: DateComponents(year: 2026, month: 1, day: 10, hour: 20))!
        #expect(a.string(from: date) == "20:00")
        #expect(CachedFormatter.pattern("HH:mm", calendar: tokyo).string(from: date) == "05:00")
        #expect(CachedFormatter.template("dMMMM", calendar: london, locale: Locale(identifier: "en_GB")).string(from: date) == "10 January")
        #expect(CachedFormatter.template("dMMMM", calendar: london, locale: Locale(identifier: "en_US")).string(from: date) == "January 10")
    }
}
