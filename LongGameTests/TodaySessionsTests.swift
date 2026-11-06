import Testing
import Foundation
@testable import LongGame

private func s(_ h: Int, _ m: Int, minutes: Int, note: String? = nil, photo: Bool = false) -> TodaySession {
    let start = day(2026, 11, 11, hour: h).addingTimeInterval(Double(m) * 60)
    return TodaySession(id: UUID(), start: start, end: start.addingTimeInterval(Double(minutes) * 60),
                        durationSec: Double(minutes) * 60, note: note, photo: photo ? Data([1]) : nil)
}

struct TodaySessionsTests {
    @Test func onlySessionsThatStartedTodayOldestFirst() {
        let now = day(2026, 11, 11, hour: 15)
        let late = day(2026, 11, 11, hour: 14), early = day(2026, 11, 11, hour: 7)
        let yesterday = day(2026, 11, 10, hour: 23), tomorrow = day(2026, 11, 12, hour: 0)
        let all = [late, yesterday, early, tomorrow]
        let out = TodaySessions.startedToday(all, start: { $0 }, now: now, calendar: utc)
        #expect(out == [early, late])
    }

    @Test func aSessionCrossingMidnightCountsOnTheDayItStarted() {
        let started = day(2026, 11, 10, hour: 23)
        #expect(TodaySessions.startedToday([started], start: { $0 }, now: day(2026, 11, 11, hour: 8), calendar: utc).isEmpty)
        #expect(TodaySessions.startedToday([started], start: { $0 }, now: day(2026, 11, 10, hour: 23), calendar: utc).count == 1)
    }

    @Test func noSessionsMeansNoRows() {
        #expect(TodaySessions.startedToday([Date](), start: { $0 }, now: day(2026, 11, 11), calendar: utc).isEmpty)
    }

    @Test func rowsAddUpToTheBigNumber() {
        let rows = [s(7, 40, minutes: 40), s(12, 0, minutes: 15), s(18, 10, minutes: 5)]
        let total = rows.reduce(0) { $0 + $1.durationSec }
        let plan = Stretch.plan(sessions: rows.map { SessionRecord(start: $0.start, durationSec: $0.durationSec) },
                                weeklyTargetHours: 7, now: day(2026, 11, 11, hour: 20), weekStart: .monday, calendar: utc)
        #expect(plan.doneSaved == total)
        #expect(StretchText.clock(seconds: plan.doneSaved) == "1 h 00")
    }

    @Test func theTimeRangeReadsLikeTheDesign() {
        let row = s(7, 40, minutes: 40)
        #expect(TodaySessions.timeRange(start: row.start, end: row.end, calendar: utc) == "07:40 – 08:20")
    }

    @Test func theDurationAndTheRunningLabel() {
        #expect(TodaySessions.duration(40 * 60) == "40 m")
        #expect(TodaySessions.duration(65 * 60) == "1 h 05")
        #expect(TodaySessions.nowLabel(seconds: 12 * 60 + 30) == "Now · 12 m")
    }

    @Test func theNoteIsOneLineOrNone() {
        #expect(TodaySessions.noteLine(nil) == nil)
        #expect(TodaySessions.noteLine("") == nil)
        #expect(TodaySessions.noteLine("  \n ") == nil)
        #expect(TodaySessions.noteLine("Scales and arpeggios") == "Scales and arpeggios")
        #expect(TodaySessions.noteLine("First line\nSecond line") == "First line")
    }

    @Test func voiceOverReadsEachRow() {
        let row = s(7, 40, minutes: 40, note: "Scales and arpeggios", photo: true)
        #expect(TodaySessions.spoken(row, calendar: utc) == "7:40 to 8:20, 40 minutes, Scales and arpeggios. Has a photo.")
        let plain = s(9, 5, minutes: 65)
        #expect(TodaySessions.spoken(plain, calendar: utc) == "9:05 to 10:10, 1 hour 5 minutes.")
        #expect(TodaySessions.spokenNow(seconds: 12 * 60) == "Now, 12 minutes. Session running.")
    }
}
