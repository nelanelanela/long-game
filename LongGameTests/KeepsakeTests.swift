import Testing
import Foundation
import CoreGraphics
@testable import LongGame

// Update 49: the keepsake poster.

private var kUTC: Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "UTC")!
    return c
}

private func kDate(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
    kUTC.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
}

private func s(_ d: Date, _ hours: Double) -> SessionRecord { SessionRecord(start: d, durationSec: hours * 3600) }

struct KeepsakeTests {
    @Test func firstAndLastDayAndRestDays() {
        let sessions = [s(kDate(2026, 1, 1, 9), 0.5), s(kDate(2026, 1, 3, 20), 2.5), s(kDate(2026, 1, 3, 21), 1)]
        let days = Keepsake.days(sessions: sessions, through: kDate(2026, 1, 5), calendar: kUTC)
        #expect(days.count == 5)                         // 1 to 5 January
        #expect(days.first == .under1)                   // the first session's day
        #expect(days[1] == .rest)                        // a rest day is included
        #expect(days[2] == .over3)                       // two sessions on one day add up
        #expect(days.last == .rest)                      // through the last day
        #expect(Keepsake.daysPlayed(days) == 2)
    }

    @Test func dayReachedWithHoursBefore() {
        let sessions = [s(kDate(2026, 1, 1), 2), s(kDate(2026, 1, 2), 3), s(kDate(2026, 1, 3), 1)]
        #expect(Keepsake.dayReached(1_004, sessions: sessions, baseline: 1_000, calendar: kUTC) == kUTC.startOfDay(for: kDate(2026, 1, 2)))
        #expect(Keepsake.dayReached(2_000, sessions: sessions, baseline: 1_000, calendar: kUTC) == nil)
    }

    @Test func spanRightAfterSetupWithNothingLogged() {
        // All 1,000 hours came before the app, no sessions yet: the poster still has days, from setup to today.
        let span = Keepsake.span(1_000, sessions: [], baseline: 1_200, began: kDate(2026, 11, 15, 9),
                                 today: kDate(2026, 11, 15, 14), calendar: kUTC)
        #expect(span.first == kUTC.startOfDay(for: kDate(2026, 11, 15)))
        #expect(span.last == kUTC.startOfDay(for: kDate(2026, 11, 15)))
        #expect(Keepsake.days(sessions: [], through: span.last, calendar: kUTC).isEmpty)
    }

    @Test func spanFromFirstSessionToDayReached() {
        let sessions = [s(kDate(2026, 1, 1), 2), s(kDate(2026, 1, 2), 3)]
        let span = Keepsake.span(1_004, sessions: sessions, baseline: 1_000, began: kDate(2025, 12, 1),
                                 today: kDate(2026, 3, 1), calendar: kUTC)
        #expect(span.first == kUTC.startOfDay(for: kDate(2026, 1, 1)))
        #expect(span.last == kUTC.startOfDay(for: kDate(2026, 1, 2)))
        // Not reached in the log: runs to today rather than giving up.
        let open = Keepsake.span(5_000, sessions: sessions, baseline: 1_000, began: kDate(2025, 12, 1),
                                 today: kDate(2026, 3, 1), calendar: kUTC)
        #expect(open.last == kUTC.startOfDay(for: kDate(2026, 3, 1)))
    }

    @Test func lastThousand() {
        #expect(Keepsake.lastThousand(total: 999) == nil)
        #expect(Keepsake.lastThousand(total: 1_000) == 1_000)
        #expect(Keepsake.lastThousand(total: 3_456) == 3_000)
    }

    @Test func aWeekAndTenYearsBothFit() {
        let box = CGSize(width: 500, height: 600)
        for count in [7, 3_653] {
            let cell = Keepsake.cell(dayCount: count, in: box)
            let rows = CGFloat((count + Keepsake.perRow - 1) / Keepsake.perRow)
            #expect(cell * CGFloat(Keepsake.perRow) <= box.width + 0.001)
            #expect(cell * rows <= box.height + 0.001)
        }
        // A week: limited by the width, not tiny.
        #expect(abs(Keepsake.cell(dayCount: 7, in: box) - CGFloat(500) / 28) < 0.001)
    }

    @Test func hoursBeforeLeftOutWhenNone() {
        #expect(Keepsake.before(0) == nil)
        #expect(Keepsake.before(2_190.6) == "2,190 hours came before")
    }

    @Test func wordsAndFileName() {
        #expect(Keepsake.fileName(hours: 3_000, craft: "Piano") == "Long Game – 3,000 hours of piano.pdf")
        #expect(Keepsake.playedLine(653) == "653 days played · each row is four weeks")
        #expect(Keepsake.spoken(hours: 3_000, craft: "Piano", played: 653) == "Poster: 3,000 hours of piano, 653 days played.")
    }

    @Test func paperDefaultsAndSizes() {
        #expect(Keepsake.defaultPaper(locale: Locale(identifier: "en_GB")) == .a3)
        #expect(Keepsake.defaultPaper(locale: Locale(identifier: "en_US")) == .in18x24)
        #expect(abs(Keepsake.Paper.a4.size.width - 595.28) < 0.01)
        #expect(Keepsake.Paper.in18x24.size == CGSize(width: 1_296, height: 1_728))
    }

    @Test @MainActor func thePDFHasOnePageOfTheRightSize() throws {
        let sessions = (0..<40).map { s(kDate(2026, 1, 1).addingTimeInterval(Double($0) * 86_400 * 2), 1.5) }
        for paper in Keepsake.Paper.allCases {
            let poster = KeepsakePoster.Content(hours: 1_000, craft: "Piano", days: Keepsake.days(sessions: sessions, through: kDate(2026, 3, 31), calendar: kUTC),
                                               firstDay: kDate(2026, 1, 1), lastDay: kDate(2026, 3, 31), baseline: 900)
            let url = try #require(KeepsakePDF.make(poster, paper: paper, look: .paper))
            let doc = try #require(CGPDFDocument(url as CFURL))
            #expect(doc.numberOfPages == 1)
            let box = try #require(doc.page(at: 1)?.getBoxRect(.mediaBox))
            #expect(abs(box.width - paper.size.width) < 0.5)
            #expect(abs(box.height - paper.size.height) < 0.5)
        }
    }
}
