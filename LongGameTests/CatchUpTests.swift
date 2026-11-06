import Testing
import Foundation
@testable import LongGame

private let cal: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Europe/London")!
    return c
}()

private func day(_ m: Int, _ d: Int, _ h: Int = 12) -> Date {
    cal.date(from: DateComponents(year: 2026, month: m, day: d, hour: h))!
}

struct CatchUpGapTests {
    @Test func gapRunsFromDayAfterLastSessionToYesterday() throws {
        // Last session Thu 2 Oct, today Sat 25 Oct -> 3 Oct ... 24 Oct = 22 days
        let gap = try #require(CatchUp.gap(sessionStarts: [day(9, 20), day(10, 2, 18)], onboardingDate: day(1, 1),
                                           today: day(10, 25, 9), calendar: cal))
        #expect(gap.first == cal.startOfDay(for: day(10, 3)))
        #expect(gap.last == cal.startOfDay(for: day(10, 24)))
        #expect(gap.days == 22)
        #expect(gap.weeks == 3)
        #expect(gap.hasSessions)
        #expect(!gap.usesAverage)
    }

    @Test func withoutSessionsTheGapStartsOnTheOnboardingDate() throws {
        let gap = try #require(CatchUp.gap(sessionStarts: [], onboardingDate: day(10, 1, 20), today: day(10, 25), calendar: cal))
        #expect(gap.first == cal.startOfDay(for: day(10, 1)))
        #expect(gap.days == 24)
        #expect(!gap.hasSessions)
    }

    @Test func noGapWhenPlayedYesterdayOrToday() {
        #expect(CatchUp.gap(sessionStarts: [day(10, 24)], onboardingDate: day(1, 1), today: day(10, 25), calendar: cal) == nil)
        #expect(CatchUp.gap(sessionStarts: [day(10, 25)], onboardingDate: day(1, 1), today: day(10, 25), calendar: cal) == nil)
    }

    @Test func twentyEightDaysSwitchesToTheAverage() throws {
        let gap = try #require(CatchUp.gap(sessionStarts: [day(9, 26)], onboardingDate: day(1, 1), today: day(10, 25), calendar: cal))
        #expect(gap.days == 28)
        #expect(gap.usesAverage)
        let shorter = try #require(CatchUp.gap(sessionStarts: [day(9, 27)], onboardingDate: day(1, 1), today: day(10, 25), calendar: cal))
        #expect(shorter.days == 27)
        #expect(!shorter.usesAverage)
    }
}

struct CatchUpWeekBlockTests {
    @Test func twentyTwoDaysMakeThreeBlocksWithTheLeftoverInTheOldest() throws {
        let gap = try #require(CatchUp.gap(sessionStarts: [day(10, 2)], onboardingDate: day(1, 1), today: day(10, 25), calendar: cal))
        let blocks = CatchUp.blocks(for: gap, calendar: cal)
        #expect(blocks.map(\.days) == [8, 7, 7])
        #expect(blocks[0].first == cal.startOfDay(for: day(10, 3)))
        #expect(blocks[0].last == cal.startOfDay(for: day(10, 10)))
        #expect(blocks[1].first == cal.startOfDay(for: day(10, 11)))
        #expect(blocks[2].last == cal.startOfDay(for: day(10, 24)))
    }

    @Test func exactWeeksHaveNoLeftover() throws {
        let gap = try #require(CatchUp.gap(sessionStarts: [day(10, 10)], onboardingDate: day(1, 1), today: day(10, 25), calendar: cal))
        #expect(gap.days == 14)
        #expect(CatchUp.blocks(for: gap, calendar: cal).map(\.days) == [7, 7])
    }

    @Test func blocksCoverTheGapWithoutOverlap() throws {
        for days in 7...27 {
            let last = day(10, 24)
            let first = cal.date(byAdding: .day, value: -(days - 1), to: last)!
            let gap = CatchUp.Gap(first: first, last: last, days: days, anchor: first, hasSessions: true)
            let blocks = CatchUp.blocks(for: gap, calendar: cal)
            #expect(blocks.reduce(0) { $0 + $1.days } == days)
            #expect(blocks.first?.first == first)
            #expect(blocks.last?.last == last)
            for (a, b) in zip(blocks, blocks.dropFirst()) {
                #expect(cal.date(byAdding: .day, value: 1, to: a.last) == b.first)
            }
        }
    }

    @Test func rangeLabels() {
        #expect(CatchUp.rangeLabel(first: day(10, 3), last: day(10, 10), calendar: cal) == "3–10 Oct")
        #expect(CatchUp.rangeLabel(first: day(9, 28), last: day(10, 4), calendar: cal) == "28 Sep – 4 Oct")
    }
}

struct CatchUpSplitTests {
    @Test func evenSplitKeepsTheTotalExact() {
        for hours in [1.0, 5, 12, 13, 40, 168] {
            for days in [7, 8, 13, 28, 71, 365] {
                let minutes = CatchUp.dailyMinutes(totalHours: hours, days: days)
                #expect(minutes.count == days)
                #expect(minutes.reduce(0, +) == Int((hours * 60).rounded()))
                #expect(minutes.allSatisfy { $0 >= 0 })
            }
        }
    }

    @Test func remainderLandsOnTheLastDay() {
        // 1 h over 8 days: 7.5 -> 8 min x 7 = 56, last day 4 min
        #expect(CatchUp.dailyMinutes(totalHours: 1, days: 8) == [8, 8, 8, 8, 8, 8, 8, 4])
        // 7 h over 7 days: exactly an hour a day
        #expect(CatchUp.dailyMinutes(totalHours: 7, days: 7) == Array(repeating: 60, count: 7))
    }

    @Test func averageTotalIsAverageTimesDaysOverSeven() {
        #expect(CatchUp.averageTotal(hoursPerWeek: 10, days: 71) == 10 * 71.0 / 7)
        #expect(CatchUp.minutesPerDay(totalHours: 8, days: 8) == 60)
        // Every hour of every week: 168 h a week for 28 days.
        #expect(CatchUp.averageTotal(hoursPerWeek: 168, days: 28) == 672)
    }

    @Test func defaultFollowsPaceAndStaysOnTheSlider() {
        #expect(CatchUp.defaultHours(pace: 11.8) == 12)
        #expect(CatchUp.defaultHours(pace: -3) == 0)
        #expect(CatchUp.defaultHours(pace: 90) == 90)
        #expect(CatchUp.defaultHours(pace: 400) == 168)
    }

    @Test func sessionsStartAtNoon() {
        #expect(cal.component(.hour, from: CatchUp.noon(of: day(10, 3, 0), calendar: cal)) == 12)
    }
}

struct CatchUpPromptRuleTests {
    private func gap(_ days: Int) -> CatchUp.Gap {
        let last = day(10, 24)
        let first = cal.date(byAdding: .day, value: -(days - 1), to: last)!
        return CatchUp.Gap(first: first, last: last, days: days, anchor: first, hasSessions: true)
    }

    @Test func needsSevenDays() {
        #expect(!CatchUp.shouldPrompt(gap: gap(6), lastPromptAt: nil, now: day(10, 25), calendar: cal))
        #expect(CatchUp.shouldPrompt(gap: gap(7), lastPromptAt: nil, now: day(10, 25), calendar: cal))
        #expect(!CatchUp.shouldPrompt(gap: nil, lastPromptAt: nil, now: day(10, 25), calendar: cal))
    }

    @Test func askedAtMostOnceEverySevenDays() {
        let now = day(10, 25)
        #expect(!CatchUp.shouldPrompt(gap: gap(14), lastPromptAt: day(10, 24), now: now, calendar: cal))
        #expect(!CatchUp.shouldPrompt(gap: gap(14), lastPromptAt: day(10, 19, 8), now: now, calendar: cal))
        #expect(CatchUp.shouldPrompt(gap: gap(14), lastPromptAt: day(10, 18, 23), now: now, calendar: cal))
    }
}

struct LabelTests {
    @Test func pluralisation() {
        #expect(Labels.hours(1) == "1 hour")
        #expect(Labels.hours(24) == "24 hours")
        #expect(Labels.days(1) == "1 day")
        #expect(Labels.days(12) == "12 days")
        #expect(Labels.weeksHavePassed(1) == "1 week has passed")
        #expect(Labels.weeksHavePassed(3) == "3 weeks have passed")
        #expect(Labels.addHours(24) == "Add 24 hours")
        #expect(Labels.shortHours(24) == "24 h")
        #expect(Labels.extraPerWeek(2) == "+2 h/wk")
        #expect(Labels.aboutPerDay(minutes: 65) == "about 1 h 05 m a day")
        #expect(Labels.aboutPerDay(minutes: 25) == "about 25 m a day")
    }
}

struct CatchUpCalendarTests {
    private func rec(_ d: Int, hours: Double, catchUp: Bool) -> SessionRecord {
        SessionRecord(start: day(10, d), durationSec: hours * 3600, isCatchUp: catchUp)
    }

    @Test func calendarColoursShowAllCatchUpDays() {
        let daily = Practice.dailySeconds([rec(1, hours: 0.5, catchUp: true)], calendar: cal)
        #expect(daily[cal.startOfDay(for: day(10, 1))] == 1800)
    }

    @Test func catchUpAddsToRealSessionsOnTheSameDay() {
        let daily = Practice.dailySeconds([rec(1, hours: 0.2, catchUp: false), rec(1, hours: 0.5, catchUp: true)], calendar: cal)
        #expect(abs((daily[cal.startOfDay(for: day(10, 1))] ?? 0) - 0.7 * 3600) < 0.001)
    }
}
