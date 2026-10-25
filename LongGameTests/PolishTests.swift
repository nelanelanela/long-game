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
    func daily(_ days: [Date]) -> [Date: Double] {
        Streaks.dailySeconds(days.map { session($0, hours: 1) }, calendar: utc)
    }

    @Test func remindsTonightWhenAStreakIsAtRisk() {
        let now = day(2026, 10, 25, hour: 10)
        let d = daily([day(2026, 10, 22), day(2026, 10, 23), day(2026, 10, 24)])
        let r = ReminderPlanner.streakReminders(daily: d, now: now, calendar: utc)
        #expect(r.count == 1)
        #expect(r.first?.streak == 3)
        #expect(r.first?.date == day(2026, 10, 25, hour: 20))
    }

    @Test func noReminderForShortStreaks() {
        let now = day(2026, 10, 25, hour: 10)
        let d = daily([day(2026, 10, 23), day(2026, 10, 24)])
        #expect(ReminderPlanner.streakReminders(daily: d, now: now, calendar: utc).isEmpty)
    }

    @Test func afterPracticeRemindsTomorrowInstead() {
        let now = day(2026, 10, 25, hour: 10)
        let d = daily([day(2026, 10, 23), day(2026, 10, 24), day(2026, 10, 25)])
        let r = ReminderPlanner.streakReminders(daily: d, now: now, calendar: utc)
        #expect(r.count == 1)
        #expect(r.first?.date == day(2026, 10, 26, hour: 20))
    }

    @Test func noReminderAfterEightPm() {
        let now = day(2026, 10, 25, hour: 21)
        let d = daily([day(2026, 10, 22), day(2026, 10, 23), day(2026, 10, 24)])
        #expect(ReminderPlanner.streakReminders(daily: d, now: now, calendar: utc).isEmpty)
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
