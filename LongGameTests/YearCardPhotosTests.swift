import Testing
import Foundation
@testable import LongGame

struct YearCardPhotosTests {
    private func day(_ d: Int) -> Date {
        Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 3, day: d, hour: 9))!
    }
    private func photo(_ d: Int, views: Int) -> YearPhotoCandidate {
        YearPhotoCandidate(id: UUID(), start: day(d), viewCount: views)
    }

    // MARK: Counting a view

    @Test func aFirstViewAlwaysCounts() {
        #expect(PhotoViews.shouldCount(lastCountedAt: nil, now: day(1)))
    }

    @Test func aViewCountsAtMostOnceAnHour() {
        let last = day(1)
        #expect(!PhotoViews.shouldCount(lastCountedAt: last, now: last.addingTimeInterval(59 * 60)))
        #expect(PhotoViews.shouldCount(lastCountedAt: last, now: last.addingTimeInterval(3600)))
        #expect(PhotoViews.shouldCount(lastCountedAt: last, now: last.addingTimeInterval(5 * 3600)))
    }

    @Test func aPhotoMustBeOnScreenForASecond() {
        #expect(PhotoViews.dwell == 1)
    }

    // MARK: Choosing six

    @Test func theMostViewedComeFirstAndTiesGoToTheNewer() {
        let a = photo(1, views: 5), b = photo(2, views: 5), c = photo(3, views: 9), d = photo(4, views: 0)
        let order = YearPhotoChoice.ranked([a, b, c, d])
        #expect(order == [c.id, b.id, a.id, d.id])
    }

    @Test func sixAreChosenFromTheMostViewed() {
        let all = (1...10).map { photo($0, views: $0 % 4) }
        let chosen = YearPhotoChoice.choose(candidates: all, pinned: [])
        #expect(chosen.count == 6)
        let ranked = YearPhotoChoice.ranked(all)
        #expect(chosen == Array(ranked.prefix(6)))
    }

    @Test func aYearNobodyOpenedShowsItsMostRecentPhotos() {
        let all = (1...8).map { photo($0, views: 0) }
        let chosen = YearPhotoChoice.choose(candidates: all, pinned: [])
        let newest = all.sorted { $0.start > $1.start }.prefix(6).map(\.id)
        #expect(chosen == Array(newest))
    }

    @Test func fewerThanSixPhotosGiveWhatThereIs() {
        let all = [photo(1, views: 1), photo(2, views: 0)]
        #expect(YearPhotoChoice.choose(candidates: all, pinned: []).count == 2)
    }

    @Test func aSwappedPhotoStaysAndTheRestFillIn() {
        let all = (1...10).map { photo($0, views: $0) }
        let lowest = all.first { $0.viewCount == 1 }!   // never in the top six by itself
        let chosen = YearPhotoChoice.choose(candidates: all, pinned: [lowest.id])
        #expect(chosen.first == lowest.id)
        #expect(chosen.count == 6)
        #expect(Set(chosen).count == 6)
    }

    @Test func aPinnedPhotoThatWasDeletedIsDropped() {
        let all = (1...8).map { photo($0, views: 0) }
        let chosen = YearPhotoChoice.choose(candidates: all, pinned: [UUID()])
        #expect(chosen.count == 6)
    }

    @Test func aFullSetOfPinsIsKeptInItsOrder() {
        let all = (1...9).map { photo($0, views: $0) }
        let pins = all.suffix(6).reversed().map(\.id)
        #expect(YearPhotoChoice.choose(candidates: all, pinned: Array(pins)) == Array(pins))
    }

    // MARK: Pins per year

    @Test func pinsSurviveBeingSavedAsText() {
        let a = UUID(), b = UUID()
        let raw = YearCardPins.encode([2025: [a], 2026: [a, b]])
        let back = YearCardPins.decode(raw)
        #expect(back[2025] == [a])
        #expect(back[2026] == [a, b])
    }

    @Test func emptyOrBrokenTextMeansNoPins() {
        #expect(YearCardPins.decode("").isEmpty)
        #expect(YearCardPins.decode("not json").isEmpty)
    }

    // MARK: The count goes with the photo

    @Test func removingAPhotoForgetsItsViews() {
        let s = Session(craftId: UUID(), start: Date(), durationSec: 600, source: .timer, photo: Data([1, 2, 3]))
        s.viewCount = 4
        s.lastCountedAt = Date()
        s.setPhoto(nil)
        #expect(s.viewCount == 0)
        #expect(s.lastCountedAt == nil)
    }

    @Test func countingAViewAddsOneAndRemembersWhen() {
        let s = Session(craftId: UUID(), start: Date(), durationSec: 600, source: .timer, photo: Data([1]))
        let now = Date()
        s.countPhotoView(now: now)
        #expect(s.viewCount == 1 && s.lastCountedAt == now)
        s.countPhotoView(now: now.addingTimeInterval(120))      // too soon
        #expect(s.viewCount == 1)
        s.countPhotoView(now: now.addingTimeInterval(3700))
        #expect(s.viewCount == 2)
    }
}
