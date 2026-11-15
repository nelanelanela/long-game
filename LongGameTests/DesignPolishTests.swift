import Testing
import Foundation
import SwiftUI
@testable import LongGame

// Update 42: the milestone card, Data & storage's words, the first week.

private var polishUTC: Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "UTC")!
    return c
}

private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
    polishUTC.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
}

private let gb = Locale(identifier: "en_GB")

struct MilestoneCardTests {
    @Test func number() {
        #expect(MilestoneCardText.number(1_000) == "1,000 h")
        #expect(MilestoneCardText.number(100) == "100 h")
    }

    @Test func reachedLine() {
        #expect(MilestoneCardText.reached(on: day(2026, 11, 5), startYear: 2019, calendar: polishUTC, locale: gb)
                == "Reached on 5 November 2026 · started in 2019")
        // Started this year: no need to say so.
        #expect(MilestoneCardText.reached(on: day(2026, 11, 5), startYear: 2026, calendar: polishUTC, locale: gb)
                == "Reached on 5 November 2026")
    }

    @Test func spoken() {
        #expect(MilestoneCardText.spoken(hours: 1_000, craft: "Piano", on: day(2026, 11, 5), calendar: polishUTC, locale: gb)
                == "A thousand hours of piano. Reached on 5 November 2026.")
        #expect(MilestoneCardText.spoken(hours: 10_000, craft: "Piano", on: day(2026, 11, 5), calendar: polishUTC, locale: gb)
                == "10,000 hours of piano. Reached on 5 November 2026.")
    }

    @Test func words() {
        #expect(Milestones.words(hours: 100) == "A hundred hours")
        #expect(Milestones.words(hours: 2_500) == "Two and a half thousand hours")
    }

    @Test func fileName() {
        #expect(MilestoneCardText.fileName(hours: 1_000, craft: "Piano") == "Long Game – 1,000 hours of Piano")
        #expect(MilestoneCardText.fileName(hours: 500, craft: "a/b") == "Long Game – 500 hours of ab")
    }

    /// 1080 × 1920, from the 360 pt layout × 3, like the year card.
    @MainActor @Test func rendersAt1080By1920() throws {
        let card = MilestoneCardView(content: .init(hours: 1_000, craftName: "Piano", reached: day(2026, 11, 5), startYear: 2019))
        let url = try #require(YearCardRender.png(card, name: "milestone-card-test"))
        let data = try Data(contentsOf: url)
        let image = try #require(PlatformImage(data: data))
        #if canImport(UIKit)
        #expect(image.size.width * image.scale == 1080)
        #expect(image.size.height * image.scale == 1920)
        #endif
        print("MILESTONECARD|\(url.path)")
    }
}

struct DataStorageTextTests {
    @Test func summary() {
        #expect(DataStorageText.summary(iCloudOn: true, photoBytes: nil) == "iCloud on · export")
        #expect(DataStorageText.summary(iCloudOn: false, photoBytes: 0) == "iCloud off · export")
        let withPhotos = DataStorageText.summary(iCloudOn: true, photoBytes: 486_000_000)
        #expect(withPhotos.hasPrefix("iCloud on · photos "))
        #expect(withPhotos.hasSuffix(" · export"))
    }

    @Test func photos() {
        #expect(DataStorageText.photos(count: 1, bytes: 0).hasPrefix("1 photo · "))
        #expect(DataStorageText.photos(count: 214, bytes: 0).hasPrefix("214 photos · "))
    }
}

struct EarlyDaysTests {
    // 2 November 2026 is a Monday.
    @Test func firstDayIsTheEarlierOfSetupAndSessions() {
        #expect(EarlyDays.firstDay(onboarding: day(2026, 11, 4), sessionStarts: [], calendar: polishUTC)
                == polishUTC.startOfDay(for: day(2026, 11, 4)))
        #expect(EarlyDays.firstDay(onboarding: day(2026, 11, 4), sessionStarts: [day(2026, 10, 1), day(2026, 11, 5)], calendar: polishUTC)
                == polishUTC.startOfDay(for: day(2026, 10, 1)))
    }

    @Test func firstFullWeek() {
        // Began on a Wednesday: the first full week is the next one, Monday 9 to Sunday 15.
        let wed = polishUTC.startOfDay(for: day(2026, 11, 4))
        #expect(EarlyDays.firstFullWeekEnds(firstDay: wed, weekStart: .monday, calendar: polishUTC)
                == polishUTC.startOfDay(for: day(2026, 11, 16)))
        #expect(EarlyDays.beforeFirstFullWeek(firstDay: wed, now: day(2026, 11, 15), weekStart: .monday, calendar: polishUTC))
        #expect(!EarlyDays.beforeFirstFullWeek(firstDay: wed, now: day(2026, 11, 16), weekStart: .monday, calendar: polishUTC))
        // Began on the week's first day: that week is the full one.
        let mon = polishUTC.startOfDay(for: day(2026, 11, 2))
        #expect(EarlyDays.firstFullWeekEnds(firstDay: mon, weekStart: .monday, calendar: polishUTC)
                == polishUTC.startOfDay(for: day(2026, 11, 9)))
        // With Sunday as the week's start, a Monday start waits for the week from Sunday 8.
        #expect(EarlyDays.firstFullWeekEnds(firstDay: mon, weekStart: .sunday, calendar: polishUTC)
                == polishUTC.startOfDay(for: day(2026, 11, 15)))
    }

    @Test func actualPaceAfterTwoWeeks() {
        let starts = [day(2026, 11, 1), day(2026, 11, 3)]
        #expect(!EarlyDays.showsActualPace(sessionStarts: [], now: day(2026, 11, 20), calendar: polishUTC))
        #expect(!EarlyDays.showsActualPace(sessionStarts: starts, now: day(2026, 11, 14), calendar: polishUTC))
        #expect(EarlyDays.showsActualPace(sessionStarts: starts, now: day(2026, 11, 15), calendar: polishUTC))
    }

    @Test func daysBeforeTheGame() {
        let first = polishUTC.startOfDay(for: day(2026, 11, 4))
        #expect(EarlyDays.isBeforeGame(polishUTC.startOfDay(for: day(2026, 11, 3)), firstDay: first))
        #expect(!EarlyDays.isBeforeGame(first, firstDay: first))
    }

    @Test func chartWithoutActualLine() {
        let f = ForecastEngine.forecast(total: 20, chosenPace: 10, actualPace: 2)
        #expect(f.withActual(f.chosen).actual == f.chosen)
        #expect(GrowthKeyText.spoken(f, now: day(2026, 11, 5), showsActual: false).contains("actual") == false)
        #expect(GrowthText.chartLabel(total: 20, forecast: f, now: day(2026, 11, 5), showsActual: false)
            .hasSuffix("Your actual pace shows after two weeks of playing."))
    }

    @Test func yearCardWaitsFourWeeks() {
        #expect(YearSummary.minimumDays == 28)
    }
}
