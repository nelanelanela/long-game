import Testing
import Foundation
@testable import LongGame

// Update 48: Then and now, and The sun remembers.

private var stUTC: Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "UTC")!
    c.locale = Locale(identifier: "en_GB")
    return c
}

private func stDate(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ min: Int = 0, calendar: Calendar = stUTC) -> Date {
    calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
}

private func photo(_ d: Date) -> ThenAndNow.Photo { .init(sessionId: UUID(), start: d) }

struct ThenAndNowTests {
    @Test func needsTwoPhotos() {
        #expect(ThenAndNow.pair(photos: [], calendar: stUTC) == nil)
        #expect(ThenAndNow.pair(photos: [photo(stDate(2024, 3, 12))], calendar: stUTC) == nil)
    }

    @Test func needsNinetyDaysBetweenEarliestAndLatest() {
        let a = photo(stDate(2026, 1, 1)), b = photo(stDate(2026, 3, 31)) // 89 days
        #expect(ThenAndNow.pair(photos: [a, b], calendar: stUTC) == nil)
        let c = photo(stDate(2026, 4, 1)) // 90 days
        #expect(ThenAndNow.pair(photos: [a, b, c], calendar: stUTC) == .init(then: a, now: c))
    }

    @Test func earliestAndLatestWhateverTheOrder() {
        let a = photo(stDate(2024, 3, 12)), b = photo(stDate(2025, 6, 1)), c = photo(stDate(2026, 11, 5))
        #expect(ThenAndNow.pair(photos: [b, c, a], calendar: stUTC) == .init(then: a, now: c))
    }

    @Test func deletedPhotosFallBack() {
        let a = photo(stDate(2024, 3, 12)), b = photo(stDate(2025, 6, 1)), c = photo(stDate(2026, 11, 5))
        // The latest is deleted: Now becomes the one before.
        #expect(ThenAndNow.pair(photos: [a, b], calendar: stUTC) == .init(then: a, now: b))
        // Only one left: nothing.
        #expect(ThenAndNow.pair(photos: [c], calendar: stUTC) == nil)
    }

    @Test func aChosenPairIsKeptWhileValid() {
        let a = photo(stDate(2024, 3, 12)), b = photo(stDate(2025, 6, 1)), c = photo(stDate(2026, 11, 5))
        let chosen = ThenAndNow.Choice(then: b.sessionId, now: c.sessionId)
        #expect(ThenAndNow.pair(photos: [a, b, c], chosen: chosen, calendar: stUTC) == .init(then: b, now: c))
    }

    @Test func aChosenPairNoLongerValidFallsBack() {
        let a = photo(stDate(2024, 3, 12)), b = photo(stDate(2025, 6, 1)), c = photo(stDate(2026, 11, 5))
        // One of the two was deleted.
        let gone = ThenAndNow.Choice(then: UUID(), now: c.sessionId)
        #expect(ThenAndNow.pair(photos: [a, b, c], chosen: gone, calendar: stUTC) == .init(then: a, now: c))
        // Now is not later than Then.
        let backwards = ThenAndNow.Choice(then: c.sessionId, now: b.sessionId)
        #expect(ThenAndNow.pair(photos: [a, b, c], chosen: backwards, calendar: stUTC) == .init(then: a, now: c))
    }

    @Test func gapInYearsMonthsAndWeeks() {
        #expect(ThenAndNow.gap(from: stDate(2024, 3, 12), to: stDate(2026, 11, 14), calendar: stUTC) == "2 years 8 months later")
        #expect(ThenAndNow.gap(from: stDate(2025, 11, 14), to: stDate(2026, 11, 14), calendar: stUTC) == "1 year later")
        #expect(ThenAndNow.gap(from: stDate(2026, 6, 1), to: stDate(2026, 11, 14), calendar: stUTC) == "5 months later")
        #expect(ThenAndNow.gap(from: stDate(2026, 10, 1), to: stDate(2026, 11, 14), calendar: stUTC) == "6 weeks later")
        #expect(ThenAndNow.gap(from: stDate(2026, 11, 10), to: stDate(2026, 11, 14), calendar: stUTC) == "4 days later")
    }

    @Test func totalAtTheEndOfASession() {
        let ids = (0..<3).map { _ in UUID() }
        let sessions = [(id: ids[0], start: stDate(2024, 1, 1), hours: 2.0),
                        (id: ids[1], start: stDate(2024, 6, 1), hours: 3.0),
                        (id: ids[2], start: stDate(2025, 1, 1), hours: 5.0)]
        #expect(ThenAndNow.total(atEndOf: ids[1], sessions: sessions, baseline: 1_000) == 1_005)
        #expect(ThenAndNow.total(atEndOf: ids[2], sessions: sessions, baseline: 1_000) == 1_010)
    }

    @Test func wordsAndSpokenCard() {
        #expect(ThenAndNow.between(hours: 984.6, craft: "Piano") == "984 hours of piano between these two.")
        #expect(ThenAndNow.spoken(isThen: true, date: "12 March 2024", hours: 2_310, note: "First try at the nocturne")
                == "Then. 12 March 2024, at 2,310 hours. First try at the nocturne. Photo.")
        #expect(ThenAndNow.spoken(isThen: false, date: "5 November 2026", hours: 3_294, note: nil)
                == "Now. 5 November 2026, at 3,294 hours. Photo.")
    }
}

private func item(_ d: Date, minutes: Double, photo: Bool = false, logged: Date? = nil) -> Memories.Item {
    .init(id: UUID(), start: d, durationSec: minutes * 60, hasPhoto: photo, loggedAt: logged ?? d)
}

struct MemoriesTests {
    // Saturday 14 November 2026.
    let now = stDate(2026, 11, 14, 9)
    /// Started in the app long ago, so "your first day" doesn't apply by itself.
    let start = item(stDate(2023, 1, 5), minutes: 30)

    @Test func aYearAgoTodayBeforeTodaysFirstSession() {
        let sessions = [start, item(stDate(2025, 11, 14, 18), minutes: 20)]
        let m = Memories.today(.init(sessions: sessions), now: now, calendar: stUTC)
        #expect(m?.text == "A year ago today, you played 20 m.")
    }

    @Test func aYearAgoTodayWithTodayWhenItIsMore() {
        let sessions = [start, item(stDate(2025, 11, 14, 18), minutes: 20), item(stDate(2026, 11, 14, 7), minutes: 65)]
        let m = Memories.today(.init(sessions: sessions), now: now, calendar: stUTC)
        #expect(m?.text == "A year ago today, you played 20 m. Today, 1 h 05.")
    }

    @Test func nothingThatStings() {
        // Today 10 m, a year ago 20 m: not shown.
        let sessions = [start, item(stDate(2025, 11, 14, 18), minutes: 20), item(stDate(2026, 11, 14, 7), minutes: 10)]
        #expect(Memories.today(.init(sessions: sessions), now: now, calendar: stUTC) == nil)
        // The same month: only when this year is ahead.
        let november = stDate(2026, 11, 20)
        let behind = [start, item(stDate(2025, 11, 3), minutes: 600), item(stDate(2026, 11, 2), minutes: 300)]
        #expect(Memories.candidates(behind, now: november, calendar: stUTC).contains { if case .sameMonth = $0 { true } else { false } } == false)
    }

    @Test func twoYearsAgoUsesTheMostRecentYear() {
        let sessions = [start, item(stDate(2023, 11, 14), minutes: 90), item(stDate(2024, 11, 14), minutes: 40)]
        let m = Memories.today(.init(sessions: sessions), now: now, calendar: stUTC)
        #expect(m?.text == "Two years ago today, you played 40 m.")
    }

    @Test func yourDayOfTheWeek() {
        // 12 Saturdays and 9 Mondays played: Saturday leads by 3.
        var sessions = [start]
        for w in 1...12 { sessions.append(item(stDate(2026, 11, 14).addingTimeInterval(Double(-7 * w) * 86_400), minutes: 30)) }
        for w in 1...9 { sessions.append(item(stDate(2026, 11, 9).addingTimeInterval(Double(-7 * w) * 86_400), minutes: 30)) }
        let m = Memories.today(.init(sessions: sessions), now: now, calendar: stUTC)
        #expect(m?.text == "Saturdays are your day. 12 of them so far.")
        // A lead of only 1: no memory.
        for w in 10...12 { sessions.append(item(stDate(2026, 11, 9).addingTimeInterval(Double(-7 * w) * 86_400), minutes: 30)) }
        #expect(Memories.today(.init(sessions: sessions), now: now, calendar: stUTC) == nil)
    }

    @Test func fewerThanTenDaysIsNotYourDay() {
        var sessions = [start]
        for w in 1...9 { sessions.append(item(stDate(2026, 11, 14).addingTimeInterval(Double(-7 * w) * 86_400), minutes: 30)) }
        #expect(Memories.today(.init(sessions: sessions), now: now, calendar: stUTC) == nil)
    }

    @Test func aPhotosAnniversary() {
        let shot = item(stDate(2024, 11, 14, 19), minutes: 30, photo: true)
        let m = Memories.today(.init(sessions: [start, shot]), now: now, calendar: stUTC)
        #expect(m?.text == "Two years ago today, you took this photo.")
        if case .photo(_, let id, _) = m { #expect(id == shot.id) } else { Issue.record("not a photo memory") }
    }

    @Test func theSameMonthAYearOn() {
        let november = stDate(2026, 11, 20)
        let sessions = [start, item(stDate(2025, 11, 3), minutes: 18 * 60), item(stDate(2026, 11, 2), minutes: 22 * 60)]
        let m = Memories.today(.init(sessions: sessions), now: november, calendar: stUTC)
        #expect(m?.text == "Last November: 18 h. This November so far: 22 h.")
        // Before the 10th: not yet.
        #expect(Memories.today(.init(sessions: sessions), now: stDate(2026, 11, 9), calendar: stUTC) == nil)
    }

    @Test func yourFirstDay() {
        let first = item(stDate(2023, 11, 14, 8), minutes: 30)
        let m = Memories.today(.init(sessions: [first]), now: now, calendar: stUTC)
        #expect(m?.text == "Three years ago today, you played your first session here.")
    }

    @Test func orderOfPreference() {
        // First day, a photo and a year ago today all apply: the first day wins, then the photo.
        let first = item(stDate(2023, 11, 14, 8), minutes: 30, photo: true)
        let year = item(stDate(2025, 11, 14), minutes: 20)
        let all = Memories.candidates([first, year], now: now, calendar: stUTC)
        #expect(all.count == 3)
        if case .firstDay = all[0] {} else { Issue.record("first day should come first") }
        if case .photo = all[1] {} else { Issue.record("then the photo") }
        if case .yearAgo = all[2] {} else { Issue.record("then a year ago today") }
    }

    @Test func the29thOfFebruary() {
        let leap = item(stDate(2024, 2, 29), minutes: 30)
        // In a year without one, it is remembered on the 28th.
        #expect(Memories.yearsAgo(leap.start, today: stDate(2025, 2, 28), calendar: stUTC) == 1)
        #expect(Memories.yearsAgo(leap.start, today: stDate(2025, 3, 1), calendar: stUTC) == nil)
        // In a leap year, on the 29th itself, and the 28th is the 28th.
        #expect(Memories.yearsAgo(leap.start, today: stDate(2028, 2, 29), calendar: stUTC) == 4)
        #expect(Memories.yearsAgo(leap.start, today: stDate(2028, 2, 28), calendar: stUTC) == nil)
        #expect(Memories.yearsAgo(stDate(2027, 2, 28), today: stDate(2028, 2, 28), calendar: stUTC) == 1)
    }

    @Test func timeZonesAroundMidnight() {
        // 23:30 UTC on 13 November is already 14 November in Paris.
        var paris = Calendar(identifier: .gregorian)
        paris.timeZone = TimeZone(identifier: "Europe/Paris")!
        let late = stDate(2025, 11, 13, 23, 30)
        #expect(Memories.yearsAgo(late, today: stDate(2026, 11, 14, 12, calendar: paris), calendar: paris) == 1)
        #expect(Memories.yearsAgo(late, today: stDate(2026, 11, 14), calendar: stUTC) == nil)
    }

    @Test func atMostOneEverySevenDays() {
        let sessions = [start, item(stDate(2025, 11, 14), minutes: 20)]
        // Shown 3 days ago: not today.
        #expect(Memories.today(.init(sessions: sessions, lastShownDay: stDate(2026, 11, 11)), now: now, calendar: stUTC) == nil)
        // Shown 7 days ago: today is fine.
        #expect(Memories.today(.init(sessions: sessions, lastShownDay: stDate(2026, 11, 7)), now: now, calendar: stUTC) != nil)
        // Shown earlier today: it stays all day.
        #expect(Memories.today(.init(sessions: sessions, lastShownDay: stDate(2026, 11, 14, 7)), now: now, calendar: stUTC) != nil)
    }

    @Test func neverWithAnAnniversaryOrAMilestone() {
        let sessions = [start, item(stDate(2025, 11, 14), minutes: 20)]
        #expect(Memories.today(.init(sessions: sessions, anniversaryToday: true), now: now, calendar: stUTC) == nil)
        #expect(Memories.today(.init(sessions: sessions, milestoneToday: true), now: now, calendar: stUTC) == nil)
    }

    @Test func neverInTheFirstMonthOrWhenSwitchedOff() {
        let new = item(stDate(2026, 10, 30), minutes: 30)
        #expect(Memories.today(.init(sessions: [new]), now: now, calendar: stUTC) == nil)
        let sessions = [start, item(stDate(2025, 11, 14), minutes: 20)]
        #expect(Memories.today(.init(sessions: sessions, enabled: false), now: now, calendar: stUTC) == nil)
    }
}
