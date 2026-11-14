import Testing
import Foundation
@testable import LongGame

// Update 49: a letter to your future self.

private func letter(_ milestone: Int, written: Double, opened: Bool = false) -> Letters.Item {
    .init(id: UUID(), milestone: milestone, totalWhenWritten: written, openedAt: opened ? Date() : nil)
}

struct LettersTests {
    @Test func milestones() {
        #expect(Letters.milestones == [100, 500, 1_000, 2_000, 3_000, 4_000, 5_000, 6_000, 7_000, 8_000, 9_000, 10_000])
    }

    @Test func nextMilestoneForATotal() {
        #expect(Letters.next(after: 0) == 100)
        #expect(Letters.next(after: 100) == 500)       // reached exactly: the next one
        #expect(Letters.next(after: 499.9) == 500)
        #expect(Letters.next(after: 3_210) == 4_000)
        #expect(Letters.next(after: 9_999) == 10_000)
        #expect(Letters.next(after: 10_000) == nil)
    }

    @Test func aPassedMilestoneIsNeverWritten() {
        #expect(Letters.canWrite(for: 4_000, total: 3_210))
        #expect(!Letters.canWrite(for: 3_000, total: 3_210))
        #expect(!Letters.canWrite(for: 3_210, total: 0))   // not a milestone
    }

    @Test func dueWhenReached() {
        let a = letter(4_000, written: 3_000)
        #expect(Letters.due([a], total: 3_999).isEmpty)
        #expect(Letters.due([a], total: 4_000) == [a])
        // Already opened: never again.
        #expect(Letters.due([letter(4_000, written: 3_000, opened: true)], total: 4_500).isEmpty)
    }

    @Test func aSavePassingTwoMilestonesDeliversTheEarlierFirst() {
        let later = letter(1_000, written: 450), earlier = letter(500, written: 120)
        let due = Letters.due([later, earlier], total: 1_020)
        #expect(due.map(\.milestone) == [500, 1_000])
    }

    @Test func hoursAgoRounding() {
        #expect(Letters.hoursBetween(milestone: 4_000, totalWhenWritten: 3_000) == 1_000)
        #expect(Letters.hoursBetween(milestone: 4_000, totalWhenWritten: 2_960) == 1_000) // 1,040 → nearest 100
        #expect(Letters.hoursBetween(milestone: 4_000, totalWhenWritten: 2_940) == 1_100) // 1,060
        #expect(Letters.hoursBetween(milestone: 500, totalWhenWritten: 116) == 380)       // 384 → nearest 10
        #expect(Letters.hoursBetween(milestone: 500, totalWhenWritten: 114) == 390)       // 386
        #expect(Letters.agoLine(milestone: 4_000, totalWhenWritten: 3_000) == "You wrote this 1,000 hours ago")
    }

    @Test func wordsAndCounter() {
        #expect(Letters.toGo(milestone: 4_000, total: 3_000) == "1,000 hours to go.")
        #expect(Letters.counter(112) == "112 / 1,000")
        #expect(Letters.spokenCounter(112) == "112 of 1,000 characters")
        #expect(Letters.clamped(String(repeating: "a", count: 1_200)).count == 1_000)
    }

    @Test func invitationWithAndWithoutAPace() {
        let now = Date(timeIntervalSince1970: 1_780_000_000) // 28 May 2026
        let at = Letters.arrival(milestone: 4_000, total: 3_400, weeklyHours: 12, now: now)
        #expect(at != nil)
        #expect(Letters.arrival(milestone: 4_000, total: 3_400, weeklyHours: nil, now: now) == nil)
        #expect(Letters.invitation(arrival: nil).hasSuffix("until you get there."))
        #expect(Letters.invitation(arrival: at, locale: Locale(identifier: "en_GB")).hasSuffix("at your pace."))
    }
}
