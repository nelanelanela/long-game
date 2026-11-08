import Testing
import Foundation
@testable import LongGame

@MainActor
struct PhotoStorageTests {
    private let cal = Calendar(identifier: .gregorian)
    private func date(_ y: Int, _ m: Int = 6, _ d: Int = 1) -> Date { cal.date(from: DateComponents(year: y, month: m, day: d, hour: 12))! }
    private func stat(_ y: Int, _ m: Int = 6, _ d: Int = 1, bytes: Int = 1_000) -> PhotoStat {
        PhotoStat(id: UUID(), start: date(y, m, d), bytes: bytes)
    }

    // MARK: Grouping

    @Test func photosAreGroupedByYearNewestYearFirst() {
        let groups = PhotoStorage.groups([stat(2024), stat(2026), stat(2025), stat(2026)], calendar: cal)
        #expect(groups.map(\.year) == [2026, 2025, 2024])
        #expect(groups.map(\.count) == [2, 1, 1])
    }

    @Test func aYearAddsUpItsBytes() {
        let groups = PhotoStorage.groups([stat(2025, bytes: 100), stat(2025, bytes: 250), stat(2026, bytes: 7)], calendar: cal)
        #expect(groups.first { $0.year == 2025 }?.bytes == 350)
        #expect(PhotoStorage.totalBytes([stat(2025, bytes: 100), stat(2026, bytes: 7)]) == 107)
    }

    @Test func aCardShowsTheFiveNewestAndTheLastSaysHowManyMore() {
        let photos = (1...9).map { stat(2025, 3, $0) }
        let group = PhotoStorage.groups(photos, calendar: cal)[0]
        #expect(group.newest.count == 5)
        #expect(group.newest.first == photos.last!.id)                 // newest first
        #expect(PhotoStorage.moreCount(group) == 9 - 4)                // the fifth tile reads "+5"
    }

    @Test func fiveOrFewerPhotosNeedNoPlusTile() {
        let group = PhotoStorage.groups((1...5).map { stat(2025, 3, $0) }, calendar: cal)[0]
        #expect(PhotoStorage.moreCount(group) == nil)
        #expect(PhotoStorage.groups([], calendar: cal).isEmpty)
    }

    // MARK: Wording

    @Test func sizesAreReadable() {
        #expect(ByteText.size(0) == "0 KB")
        #expect(ByteText.size(486_000_000).contains("MB") && ByteText.size(486_000_000).contains("486"))
        #expect(ByteText.size(3_100_000).contains("MB"))
        #expect(ByteText.size(254_000).contains("KB"))
    }

    // MARK: Deleting a year's photos

    private func session(_ y: Int, photo: Bool = true, note: String? = "keep me") -> Session {
        Session(craftId: UUID(), start: date(y), durationSec: 1_800, source: .timer, note: note,
                photo: photo ? Data(repeating: 1, count: 500) : nil)
    }

    @Test func onlyThatYearsPhotosGoAndTheSessionsStayUntouched() {
        let a = session(2025), b = session(2025), c = session(2026), d = session(2025, photo: false)
        let result = PhotoLibrary.removePhotos(inYear: 2025, from: [a, b, c, d], calendar: cal)
        #expect(result.removed == 2)
        #expect(result.bytes == 1_000)
        #expect(!a.hasPhoto && a.photo == nil && !b.hasPhoto)
        #expect(c.hasPhoto && c.photo != nil)                         // another year's photo stays
        // Hours, notes and dates are exactly as they were.
        #expect(a.durationSec == 1_800 && a.note == "keep me" && a.start == date(2025))
        #expect(d.durationSec == 1_800)
    }

    @Test func deletingAYearsPhotosForgetsTheirViews() {
        let a = session(2025)
        a.viewCount = 5
        a.lastCountedAt = Date()
        let other = session(2026)
        other.viewCount = 3
        PhotoLibrary.removePhotos(inYear: 2025, from: [a, other], calendar: cal)
        #expect(a.viewCount == 0 && a.lastCountedAt == nil)
        #expect(other.viewCount == 3)
    }

    @Test func aYearWithNoPhotosRemovesNothing() {
        let result = PhotoLibrary.removePhotos(inYear: 2020, from: [session(2025)], calendar: cal)
        #expect(result.removed == 0 && result.bytes == 0)
    }

    @Test func thePinsForThatYearAreForgottenToo() {
        let id = UUID()
        let raw = YearCardPins.encode([2025: [id], 2026: [id]])
        let after = YearCardPins.decode(YearCardPins.removing(year: 2025, from: raw))
        #expect(after[2025] == nil)
        #expect(after[2026] == [id])
    }

    // MARK: Clearing the default pictures

    @Test func clearingThePictureCacheLeavesThePhotosAlone() throws {
        let kept = session(2025)
        let dir = SessionPictureCache.directory
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data(repeating: 9, count: 4_096).write(to: dir.appendingPathComponent("x-\(UUID().uuidString).png"))
        #expect(SessionPictureCache.sizeOnDisk() >= 4_096)
        SessionPictureCache.clear()
        #expect(SessionPictureCache.sizeOnDisk() == 0)
        #expect(kept.hasPhoto && kept.photo?.count == 500)
    }
}
