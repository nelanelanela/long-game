import Testing
import Foundation
import SwiftUI
import ImageIO
@testable import LongGame

private let early = day(2025, 6, 1, hour: 0)      // the game began before 2026

private func make(_ year: Int = 2026, sessions: [SessionRecord], photos: [YearPhoto] = [], estimates: [YearRate] = [],
                  onboarding: Date = early, now: Date, weekStart: WeekStart = .monday) -> YearSummary {
    YearSummary.make(year: year, sessions: sessions, photos: photos, estimates: estimates, onboardingDate: onboarding,
                     now: now, weekStart: weekStart, calendar: utc)
}

struct YearHoursAndDaysTests {
    @Test func onlySessionsStartedInTheYearCountAndTheEstimateIsLeftOut() {
        let sessions = [session(day(2025, 12, 31, hour: 20), hours: 3),   // last year
                        session(day(2026, 1, 3), hours: 2), session(day(2026, 6, 10), hours: 1.5),
                        session(day(2027, 1, 2), hours: 4)]               // next year
        let s = make(sessions: sessions, estimates: [YearRate(year: 2025, hoursPerWeek: 10)], now: day(2026, 12, 20))
        #expect(s.hours == 3.5)
        #expect(s.daysOfPractice == 2)
    }

    @Test func severalSessionsOnOneDayAreOneDayOfPractice() {
        let sessions = [session(day(2026, 3, 2, hour: 8), hours: 1), session(day(2026, 3, 2, hour: 19), hours: 1.5),
                        session(day(2026, 3, 3), hours: 0.5)]
        let s = make(sessions: sessions, now: day(2026, 12, 20))
        #expect(s.daysOfPractice == 2)
        #expect(s.levels[day(2026, 3, 2, hour: 0)] == .from2to3)
        #expect(s.levels[day(2026, 3, 3, hour: 0)] == .under1)
        #expect(s.levels[day(2026, 3, 4, hour: 0)] == nil)
    }

    @Test func theTotalIsTheBaselinePlusEverythingLoggedUpToTheEndOfThatYear() {
        let sessions = [session(day(2026, 5, 4), hours: 10), session(day(2027, 2, 1), hours: 100)]
        let estimates = [YearRate(year: 2025, hoursPerWeek: 10)]
        let past = make(sessions: sessions, estimates: estimates, now: day(2027, 3, 1))
        let baseline = Baseline.hours(estimates: estimates, onboardingDate: early, calendar: utc)
        #expect(abs(past.total - (baseline + 10)) < 0.0001)
        // The year in progress counts up to now.
        let current = make(2027, sessions: sessions, estimates: estimates, now: day(2027, 3, 1))
        #expect(abs(current.total - (baseline + 110)) < 0.0001)
        #expect(current.percent == Totals.percent(total: current.total))
    }
}

struct YearRhythmTests {
    /// Mon, Wed and Fri of every week from the week of 5 Jan.
    private func threeDays(until end: Date) -> [SessionRecord] {
        var out: [SessionRecord] = []
        var monday = day(2026, 1, 5, hour: 0)
        while monday < end {
            for offset in [0, 2, 4] { out.append(session(utc.date(byAdding: .day, value: offset, to: monday)!, hours: 1)) }
            monday = utc.date(byAdding: .day, value: 7, to: monday)!
        }
        return out
    }

    @Test func rhythmIsTheMedianPracticeDaysPerCompleteWeek() {
        let s = make(sessions: threeDays(until: day(2026, 2, 20, hour: 0)), now: day(2026, 3, 1))
        #expect(s.rhythm == 3)
    }

    @Test func oneBusyWeekDoesNotMoveTheMedian() {
        var sessions = threeDays(until: day(2026, 2, 20, hour: 0))
        for offset in [1, 3, 5, 6] { sessions.append(session(utc.date(byAdding: .day, value: offset, to: day(2026, 1, 19, hour: 12))!, hours: 1)) }
        #expect(make(sessions: sessions, now: day(2026, 3, 1)).rhythm == 3)
    }

    @Test func theWeekInProgressAndTheFirstPartialWeekAreLeftOut() {
        // Today is Wednesday 7 Jan 2026: no complete week of the year yet.
        let sessions = [session(day(2026, 1, 1), hours: 1), session(day(2026, 1, 2), hours: 1), session(day(2026, 1, 5), hours: 1)]
        #expect(make(sessions: sessions, now: day(2026, 1, 7)).rhythm == 0)
    }

    @Test func theWeekStartChangesWhichDaysShareAWeek() {
        let sessions = [day(2026, 1, 5), day(2026, 1, 10), day(2026, 1, 11), day(2026, 1, 12), day(2026, 1, 13), day(2026, 1, 16)]
            .map { session($0, hours: 1) }
        let now = day(2026, 1, 20)
        // Monday weeks: 5-11 has 3 days, 12-18 has 3 days.
        #expect(make(sessions: sessions, now: now, weekStart: .monday).rhythm == 3)
        // Sunday weeks: 4-10 has 2 days, 11-17 has 4 days.
        #expect(make(sessions: sessions, now: now, weekStart: .sunday).rhythm == 4)
    }

    @Test func weeksBeforeTheGameBeganDoNotCount() {
        // The game began on Thursday 12 Mar 2026; the first week that counts starts on Monday 16 Mar.
        let sessions = [session(day(2026, 3, 12), hours: 1), session(day(2026, 3, 16), hours: 1), session(day(2026, 3, 17), hours: 1),
                        session(day(2026, 3, 23), hours: 1)]
        let s = make(sessions: sessions, onboarding: day(2026, 3, 12, hour: 9), now: day(2026, 4, 5))
        #expect(s.rhythm == 2)   // weeks of 16 Mar (2 days) and 23 Mar (1 day): the middle one is 2
    }
}

struct YearMonthTests {
    @Test func theMonthWithTheMostHoursWins() {
        let sessions = [session(day(2026, 1, 5), hours: 2), session(day(2026, 3, 9), hours: 6), session(day(2026, 3, 10), hours: 1),
                        session(day(2026, 4, 6), hours: 5)]
        #expect(make(sessions: sessions, now: day(2026, 12, 1)).mostPlayedMonth == 3)
    }

    @Test func aTieGoesToTheLaterMonth() {
        let sessions = [session(day(2026, 1, 5), hours: 5), session(day(2026, 2, 9), hours: 3), session(day(2026, 2, 10), hours: 2),
                        session(day(2026, 6, 6), hours: 5)]
        #expect(make(sessions: sessions, now: day(2026, 12, 1)).mostPlayedMonth == 6)
    }

    @Test func noHoursNoMonth() {
        #expect(make(sessions: [], now: day(2026, 12, 1)).mostPlayedMonth == nil)
    }

    @Test func monthNamesFollowTheLanguage() {
        #expect(YearCardText.monthName(3, locale: Locale(identifier: "en_GB")) == "March")
        #expect(YearCardText.monthName(3, locale: Locale(identifier: "de_DE")) == "März")
        #expect(YearCardText.monthLabels(locale: Locale(identifier: "en_GB")) == ["Jan", "Apr", "Jul", "Oct", "Dec"])
    }
}

struct YearChoiceTests {
    @Test func theCurrentYearUntilTheFirstFifteenDaysOfJanuary() {
        #expect(YearSummary.defaultYear(now: day(2026, 12, 31), calendar: utc) == 2026)
        #expect(YearSummary.defaultYear(now: day(2027, 1, 1), calendar: utc) == 2026)
        #expect(YearSummary.defaultYear(now: day(2027, 1, 15, hour: 23), calendar: utc) == 2026)
        #expect(YearSummary.defaultYear(now: day(2027, 1, 16, hour: 0), calendar: utc) == 2027)
        #expect(YearSummary.defaultYear(now: day(2026, 7, 4), calendar: utc) == 2026)
    }

    @Test func theLongGameRowShowsFromTheFirstOfDecemberToTheFifteenthOfJanuary() {
        #expect(!YearSummary.showsOnLongGame(now: day(2026, 11, 30, hour: 23), calendar: utc))
        #expect(YearSummary.showsOnLongGame(now: day(2026, 12, 1, hour: 0), calendar: utc))
        #expect(YearSummary.showsOnLongGame(now: day(2027, 1, 15, hour: 20), calendar: utc))
        #expect(!YearSummary.showsOnLongGame(now: day(2027, 1, 16, hour: 0), calendar: utc))
        #expect(!YearSummary.showsOnLongGame(now: day(2026, 6, 15), calendar: utc))
    }

    @Test func yearsWithDataAreListedNewestFirst() {
        let sessions = [session(day(2024, 5, 1), hours: 1), session(day(2026, 5, 1), hours: 1), session(day(2025, 5, 1), hours: 1),
                        session(day(2026, 6, 1), hours: 1)]
        #expect(YearSummary.yearsWithData(sessions: sessions, calendar: utc) == [2026, 2025, 2024])
    }
}

struct YearDataTests {
    @Test func underFourWeeksOfDataTheEntriesAreHidden() {
        // The game began on 10 Dec; on 20 Dec there are only 11 days.
        let s = make(sessions: [session(day(2026, 12, 12), hours: 1)], onboarding: day(2026, 12, 10, hour: 9), now: day(2026, 12, 20))
        #expect(!s.hasEnoughData)
        #expect(s.since == day(2026, 12, 10, hour: 0))
        // Four weeks in, they show.
        let later = make(sessions: [session(day(2026, 12, 12), hours: 1)], onboarding: day(2026, 12, 3, hour: 9), now: day(2026, 12, 31))
        #expect(later.hasEnoughData)
        // A whole year of nothing logged is not data either.
        #expect(!make(sessions: [], now: day(2026, 12, 20)).hasEnoughData)
    }

    @Test func aGameThatBeganDuringTheYearSaysSinceWhen() {
        let s = make(sessions: [session(day(2026, 3, 20), hours: 1)], estimates: [YearRate(year: 2026, hoursPerWeek: 4)],
                     onboarding: day(2026, 3, 12, hour: 9), now: day(2026, 12, 1))
        #expect(s.since == day(2026, 3, 12, hour: 0))
        #expect(s.hours == 1)   // the estimate for the weeks before is not "played this year"
        #expect(s.total > 40)   // ...but it is in the total
        let caption = YearCardText.caption(s, showHours: true, calendar: utc)
        #expect(caption.hasPrefix("played since"))
        let other = make(sessions: [session(day(2026, 3, 20), hours: 1)], now: day(2026, 12, 1))
        #expect(other.since == nil)
        #expect(YearCardText.caption(other, showHours: true) == "played this year")
        #expect(YearCardText.caption(other, showHours: false) == "of practice this year")
    }

    @Test func aSessionCrossingMidnightOnNewYearsEveBelongsToTheYearItStartedIn() {
        let late = SessionRecord(start: day(2026, 12, 31, hour: 23), durationSec: 7200)
        let s2026 = make(sessions: [late], now: day(2027, 1, 3))
        let s2027 = make(2027, sessions: [late], now: day(2027, 1, 3))
        #expect(s2026.hours == 2 && s2026.daysOfPractice == 1)
        #expect(s2027.hours == 0 && s2027.daysOfPractice == 0)
        #expect(s2026.levels[day(2026, 12, 31, hour: 0)] == .from2to3)
    }

    @Test func photosAreTheYearsAndNewestFirst() {
        let a = YearPhoto(id: UUID(), start: day(2026, 2, 1)), b = YearPhoto(id: UUID(), start: day(2026, 9, 1))
        let c = YearPhoto(id: UUID(), start: day(2025, 9, 1)), d = YearPhoto(id: UUID(), start: day(2026, 5, 1))
        let s = make(sessions: [], photos: [a, b, c, d], now: day(2026, 12, 1))
        #expect(s.photos.map(\.id) == [b.id, d.id, a.id])
        #expect(!s.offersPhotosCard)
        let six = (1...6).map { YearPhoto(id: UUID(), start: day(2026, $0, 3)) }
        #expect(make(sessions: [], photos: six, now: day(2026, 12, 1)).offersPhotosCard)
    }

    @Test func theStripHasAColumnPerWeekAndLeavesOutDaysOutsideTheYearOrToCome() {
        let levels: [Date: CalendarLevel] = [day(2026, 1, 1, hour: 0): .under1, day(2026, 1, 6, hour: 0): .from2to3]
        let monday = YearSummary.grid(year: 2026, levels: levels, now: day(2026, 1, 8), weekStart: .monday, calendar: utc)
        #expect(monday.count == 53)
        // The first column starts Mon 29 Dec 2025: Mon, Tue, Wed are last year; Thu 1 Jan is the 4th row.
        #expect(monday[0][0] == nil && monday[0][2] == nil)
        #expect(monday[0][3] == .under1)
        #expect(monday[0][4] == .rest)
        #expect(monday[1][1] == .from2to3)
        // Today is Thu 8 Jan: Friday on is still to come.
        #expect(monday[1][3] == .rest && monday[1][4] == nil)
        let sunday = YearSummary.grid(year: 2026, levels: levels, now: day(2026, 12, 31), weekStart: .sunday, calendar: utc)
        #expect(sunday[0][4] == .under1)   // the week starts on Sunday 28 Dec, so Thursday is the 5th row
        #expect(sunday.allSatisfy { $0.count == 7 })
    }

    @Test func theWordsOnTheCard() {
        let s = make(sessions: [session(day(2026, 3, 9), hours: 600), session(day(2026, 3, 10), hours: 24)],
                     estimates: [], now: day(2026, 12, 1))
        let en = Locale(identifier: "en_GB")
        #expect(YearCardText.big(s, showHours: true, locale: en) == "+624 h")
        #expect(YearCardText.big(s, showHours: false) == "2 days")
        #expect(YearCardText.totalCaption(showHours: true) == "of 10,000")
        #expect(YearCardText.totalCaption(showHours: false) == "of the way")
        #expect(YearCardText.totalValue(s, showHours: false) == "\(s.percent)%")
        let spoken = YearCardText.spoken(s, showHours: true, locale: en)
        #expect(spoken.hasPrefix("Your 2026 in the long game: 624 hours played"))
        #expect(spoken.contains("most in March"))
        #expect(!YearCardText.spoken(s, showHours: false, locale: en).contains("624"))
        let thousands = make(sessions: [session(day(2026, 3, 9), hours: 1240)], now: day(2026, 12, 1))
        #expect(YearCardText.big(thousands, showHours: true, locale: en) == "+1,240 h")
    }
}

@MainActor
struct YearCardRenderTests {
    private func render(_ style: YearCardStyle, showHours: Bool = true) throws -> PlatformImage {
        let summary = YearSummary.sample()
        return try #require(YearCardRender.image(summary: summary, craftName: "Piano", style: style, showHours: showHours,
                                                 now: day(2026, 12, 20), weekStart: .monday, photos: []))
    }

    @Test func storiesRenderAt1080By1920() throws {
        for style in [YearCardStyle.sunrise, .evening] {
            let image = try render(style)
            #expect(Int(image.pixelSize.width) == 1080 && Int(image.pixelSize.height) == 1920)
        }
    }

    @Test func thePhotoCardRendersAt1080By1080() throws {
        let image = try render(.photos, showHours: false)
        #expect(Int(image.pixelSize.width) == 1080 && Int(image.pixelSize.height) == 1080)
    }

    @Test func theCardIgnoresTheSystemAppearance() throws {
        // Light and dark system settings give the same picture (the card fixes its own look).
        let summary = YearSummary.sample()
        func pixels(_ scheme: ColorScheme) -> Data? {
            let card = YearCardView(summary: summary, craftName: "Piano", style: .sunrise, now: day(2026, 12, 20)).environment(\.colorScheme, scheme)
            let r = ImageRenderer(content: card)
            r.scale = 1
            return r.platformImage?.pngData()
        }
        // Compared pixel by pixel with a tiny tolerance: the sky's gradients are dithered (a little random noise
        // against banding), so two renders can differ by 1 step in 255 in the sky. Anything more is a real change.
        #expect(Self.nearlySame(pixels(.light), pixels(.light)), "rendering is repeatable")
        #expect(Self.nearlySame(pixels(.light), pixels(.dark)))
    }

    /// True when two PNGs have the same size and no colour channel differs by more than `tolerance` (of 255).
    private static func nearlySame(_ a: Data?, _ b: Data?, tolerance: Int = 2) -> Bool {
        func rgba(_ data: Data?) -> (Int, Int, [UInt8])? {
            guard let data, let src = CGImageSourceCreateWithData(data as CFData, nil),
                  let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return nil }
            let w = img.width, h = img.height
            var buf = [UInt8](repeating: 0, count: w * h * 4)
            let drawn = buf.withUnsafeMutableBytes { raw -> Bool in
                guard let ctx = CGContext(data: raw.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                          space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
                ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
                return true
            }
            return drawn ? (w, h, buf) : nil
        }
        guard let x = rgba(a), let y = rgba(b), x.0 == y.0, x.1 == y.1 else { return false }
        return zip(x.2, y.2).allSatisfy { abs(Int($0) - Int($1)) <= tolerance }
    }
}

struct SampleYearTests {
    private let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    @Test func theGeneratorRepeatsForTheSameSeed() {
        var a = SeededRandom(seed: 2026), b = SeededRandom(seed: 2026), c = SeededRandom(seed: 2027)
        let first = (0..<20).map { _ in a.next() }
        #expect(first == (0..<20).map { _ in b.next() })
        #expect(first != (0..<20).map { _ in c.next() })
        for _ in 0..<1_000 {
            let u = a.unit()
            #expect(u >= 0 && u < 1)
        }
    }

    @Test func theSampleYearIsTheSameEveryTime() {
        let one = SampleYear.days(year: 2026, calendar: cal)
        #expect(one == SampleYear.days(year: 2026, calendar: cal))
        #expect(one.count == 365)
        #expect(SampleYear.days(year: 2028, calendar: cal).count == 366)
        #expect(one.map(\.level) != SampleYear.days(year: 2025, calendar: cal).map(\.level))
    }

    @Test func everyDayIsInOrderAndInsideItsLevel() {
        let days = SampleYear.days(year: 2026, calendar: cal)
        #expect(days.first?.date == cal.date(from: DateComponents(year: 2026, month: 1, day: 1)))
        for (a, b) in zip(days, days.dropFirst()) { #expect(cal.dateComponents([.day], from: a.date, to: b.date).day == 1) }
        for d in days {
            if d.level == .rest {
                #expect(d.minutes == 0 && !d.hasPhoto)
            } else {
                #expect(CalendarLevel.level(hours: Double(d.minutes) / 60) == d.level)
            }
        }
    }

    @Test func itLooksLikeARealYear() {
        // Over a few years, so the shares are not down to one lucky seed.
        let days = (2024...2028).flatMap { SampleYear.days(year: $0, calendar: cal) }
        let practice = days.filter { $0.level != .rest }
        let restShare = Double(days.count - practice.count) / Double(days.count)
        #expect(restShare > 0.15 && restShare < 0.35)
        let photoShare = Double(practice.filter(\.hasPhoto).count) / Double(practice.count)
        #expect(photoShare > 0.10 && photoShare < 0.19)
        // Every level shows up, and weekends rest more than weekdays.
        for level in CalendarLevel.allCases { #expect(days.contains { $0.level == level }) }
        func restShareOf(weekend: Bool) -> Double {
            let set = days.filter { [1, 7].contains(cal.component(.weekday, from: $0.date)) == weekend }
            return Double(set.filter { $0.level == .rest }.count) / Double(set.count)
        }
        #expect(restShareOf(weekend: true) > restShareOf(weekend: false))
    }

    @Test func theRuleMatchesTheDesign() {
        #expect(SampleYear.restChance(weekend: false, energy: 0, isBreak: false) == 0.20)
        #expect(abs(SampleYear.restChance(weekend: true, energy: 1, isBreak: false) - 0.20) < 1e-9)
        #expect(SampleYear.restChance(weekend: false, energy: 0.5, isBreak: true) == 0.85)
        #expect(SampleYear.level(x: 0.32) == .under1)
        #expect(SampleYear.level(x: 0.33) == .from1to2)
        #expect(SampleYear.level(x: 0.58) == .from2to3)
        #expect(SampleYear.level(x: 0.84) == .over3)
    }

    @Test func thePreviewSummaryUsesTheSampleYear() {
        let summary = YearSummary.sample()
        let practice = SampleYear.days(year: 2026, calendar: Calendar(identifier: .gregorian)).filter { $0.level != .rest }
        #expect(summary.daysOfPractice == practice.count)
        #expect(summary.levels.count == practice.count)
    }
}
