import Testing
import Foundation
@testable import LongGame

struct MilestoneTests {
    @Test func crossedOnlyOnce() {
        #expect(Milestones.newlyCrossed(total: 99, seen: []) == [])
        #expect(Milestones.newlyCrossed(total: 520, seen: []) == [100, 500])
        #expect(Milestones.newlyCrossed(total: 520, seen: [100, 500]) == [])
        #expect(Milestones.newlyCrossed(total: 1001, seen: [100, 500]) == [1000])
    }

    @Test func tenThousandIsLast() {
        #expect(Milestones.newlyCrossed(total: 12_000, seen: [100, 500, 1000, 2500, 5000, 7500]) == [10_000])
    }

    @Test func messages() {
        #expect(Milestones.message(hours: 10_000, craft: "Piano") == "10,000 hours. The sun has fully risen.")
        #expect(Milestones.message(hours: 500, craft: "Piano").hasSuffix("of piano. Sunrise is coming."))
    }
}

struct ReminderTests {
    /// Wednesday 28 Oct 2026, 10:00.
    let now = day(2026, 10, 28, hour: 10)

    func daily(_ days: [Date]) -> [Date: Double] {
        Practice.dailySeconds(days.map { session($0, hours: 1) }, calendar: utc)
    }

    /// Practised on this Wednesday-of-the-week in 3 of the last 4 weeks.
    var usualWednesdays: [Date] { [day(2026, 10, 21), day(2026, 10, 14), day(2026, 10, 7)] }

    @Test func nudgesTonightOnADayTheUserUsuallyPractises() {
        let r = ReminderPlanner.rhythmNudges(daily: daily(usualWednesdays), now: now, calendar: utc)
        #expect(r.count == 1)
        #expect(r.first?.date == day(2026, 10, 28, hour: 19))
        #expect(r.first?.weekday == 4)
    }

    @Test func noNudgeForADayPractisedOnlyTwiceInFourWeeks() {
        let r = ReminderPlanner.rhythmNudges(daily: daily(Array(usualWednesdays.prefix(2))), now: now, calendar: utc)
        #expect(r.isEmpty)
    }

    @Test func noNudgeOnceTodayIsPlayed() {
        let r = ReminderPlanner.rhythmNudges(daily: daily(usualWednesdays + [day(2026, 10, 28, hour: 8)]), now: now, calendar: utc)
        #expect(r.isEmpty)
    }

    @Test func noNudgeAfterSevenPm() {
        let r = ReminderPlanner.rhythmNudges(daily: daily(usualWednesdays), now: day(2026, 10, 28, hour: 20), calendar: utc)
        #expect(r.isEmpty)
    }

    @Test func atMostTwoNudgesAWeek() {
        // Every day practised for the last four weeks.
        let days = (1...28).map { utc.date(byAdding: .day, value: -$0, to: day(2026, 10, 28))! }
        let r = ReminderPlanner.rhythmNudges(daily: daily(days), now: now, calendar: utc)
        #expect(r.count == 2)
        #expect(r[0].date < r[1].date)
    }

    @Test func messageNamesTheWeekday() {
        #expect(ReminderPlanner.nudgeMessage(weekday: 3, craftName: "Piano", calendar: utc)
                == "Tuesdays usually get a little piano. The sun is up whenever you are.")
    }
}

struct CSVTests {
    @Test func escapesAwkwardFields() {
        #expect(CSVExport.escape("plain") == "plain")
        #expect(CSVExport.escape("a,b") == "\"a,b\"")
        #expect(CSVExport.escape("say \"hi\"") == "\"say \"\"hi\"\"\"")
        #expect(CSVExport.escape("two\nlines") == "\"two\nlines\"")
    }

    @Test func rowsAreSortedWithHeader() {
        let rows = [
            CSVExport.Row(craft: "Piano", start: day(2026, 10, 22), durationSec: 5400, source: "manual", note: "Slow, careful"),
            CSVExport.Row(craft: "Piano", start: day(2026, 10, 20), durationSec: 1800, source: "timer", note: ""),
        ]
        let csv = CSVExport.sessions(rows, calendar: utc)
        let lines = csv.split(separator: "\n").map(String.init)
        #expect(lines[0] == "Craft,Date,Start,Minutes,Source,Note")
        #expect(lines[1] == "Piano,2026-10-20,12:00,30,timer,")
        #expect(lines[2] == "Piano,2026-10-22,12:00,90,manual,\"Slow, careful\"")
    }
}

struct CSVImportTests {
    @Test func readsQuotedFieldsAndRoundTripsExport() {
        let rows = [
            CSVExport.Row(craft: "Piano", start: day(2026, 10, 22), durationSec: 5400, source: "manual", note: "Slow, \"careful\"\nsecond line"),
            CSVExport.Row(craft: "Piano", start: day(2026, 10, 20), durationSec: 1800, source: "timer", note: ""),
        ]
        let parsed = CSVImport.sessions(CSVExport.sessions(rows, calendar: utc), calendar: utc)
        #expect(parsed.skipped == 0)
        #expect(parsed.rows.count == 2)
        #expect(parsed.rows[0].start == day(2026, 10, 20))
        #expect(parsed.rows[0].durationSec == 1800)
        #expect(parsed.rows[1].note == "Slow, \"careful\"\nsecond line")
        #expect(parsed.rows[1].durationSec == 5400)
    }

    @Test func toleratesCRLFBOMAndBadLines() {
        let text = "\u{FEFF}Craft,Date,Start,Minutes,Source,Note\r\nPiano,2026-10-20,12:00,30,timer,\r\nPiano,not a date,12:00,30,timer,\r\nPiano,2026-10-21,12:00,0,timer,\r\n"
        let parsed = CSVImport.sessions(text, calendar: utc)
        #expect(parsed.rows.count == 1)
        #expect(parsed.skipped == 2)
    }

    @Test func plansByNameSkipsDuplicatesAndFallsBackToActive() {
        let piano = UUID(), other = UUID()
        let row = CSVImport.Row(craft: "piano", start: day(2026, 10, 20), durationSec: 1800, source: "timer", note: "")
        let existing: Set<String> = [CSVImport.key(craftId: piano, start: row.start, durationSec: 1800)]
        let crafts = [CSVImport.CraftRef(id: piano, name: "Piano"), CSVImport.CraftRef(id: other, name: "Drawing")]

        let dup = CSVImport.plan(rows: [row], crafts: crafts, activeId: piano, existingKeys: existing)
        #expect(dup.toAdd.isEmpty && dup.duplicates == 1)

        var cello = row; cello.craft = "Cello"
        let fallback = CSVImport.plan(rows: [cello], crafts: crafts, activeId: other, existingKeys: [])
        #expect(fallback.toAdd.first?.craftId == other)

        var violin = row; violin.craft = "Violin"
        let skipped = CSVImport.plan(rows: [cello, violin], crafts: crafts, activeId: other, existingKeys: [])
        #expect(skipped.unmatched == 2)
    }
}
