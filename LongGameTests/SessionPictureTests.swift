import Testing
import Foundation
import CoreGraphics
@testable import LongGame

struct SessionPictureTests {
    private let id = UUID(uuidString: "5B2C1E5A-9D1F-4C55-8E0A-0F3B2A7D4C11")!

    // MARK: Seed

    @Test func theSeedIsStableForTheSameSession() {
        let a = SessionPictureSeed.make(id: id, startMinute: 460, minutes: 40)
        let b = SessionPictureSeed.make(id: id, startMinute: 460, minutes: 40)
        #expect(a == b)
    }

    @Test func theSeedKnownValueNeverChanges() {
        // Pinned: if this changes, every picture ever drawn would change with it.
        #expect(SessionPictureSeed.make(id: id, startMinute: 460, minutes: 40) == 3144901702)
    }

    @Test func theSeedChangesWithTheIdTheStartOrTheLength() {
        let base = SessionPictureSeed.make(id: id, startMinute: 460, minutes: 40)
        #expect(SessionPictureSeed.make(id: UUID(), startMinute: 460, minutes: 40) != base)
        #expect(SessionPictureSeed.make(id: id, startMinute: 461, minutes: 40) != base)
        #expect(SessionPictureSeed.make(id: id, startMinute: 460, minutes: 41) != base)
    }

    @Test func theStartMinuteIsMinutesIntoTheDay() {
        let cal = Calendar(identifier: .gregorian)
        let start = cal.date(from: DateComponents(year: 2026, month: 11, day: 8, hour: 7, minute: 40))!
        #expect(SessionPictureSeed.startMinute(of: start, calendar: cal) == 460)
    }

    // MARK: The same picture every time

    @Test func theSameSessionAlwaysDrawsTheSamePicture() {
        let seed = SessionPictureSeed.make(id: id, startMinute: 460, minutes: 40)
        let a = SessionPictureLayout.make(seed: seed, startMinute: 460, minutes: 40, progress: 0.4)
        let b = SessionPictureLayout.make(seed: seed, startMinute: 460, minutes: 40, progress: 0.4)
        #expect(a == b)
    }

    @Test func differentSessionsDrawDifferentPictures() {
        let a = SessionPictureLayout.make(seed: SessionPictureSeed.make(id: id, startMinute: 460, minutes: 40), startMinute: 460, minutes: 40, progress: 0.4)
        let b = SessionPictureLayout.make(seed: SessionPictureSeed.make(id: UUID(), startMinute: 460, minutes: 40), startMinute: 460, minutes: 40, progress: 0.4)
        #expect(a != b)
    }

    // MARK: Daypart

    @Test(arguments: [(0.0, SessionDaypart.night), (5.49, .night), (5.5, .morning), (9.99, .morning), (10, .midday),
                      (14.49, .midday), (14.5, .afternoon), (17.99, .afternoon), (18, .evening), (21.49, .evening),
                      (21.5, .night), (23.9, .night)])
    func theDaypartFollowsTheStartHour(hour: Double, expected: SessionDaypart) {
        #expect(SessionDaypart.at(startHour: hour) == expected)
    }

    // MARK: Geometry

    @Test func theHorizonAndSunStayInTheirRanges() {
        for i in 0..<200 {
            let seed = SessionPictureSeed.make(id: UUID(), startMinute: i * 7 % 1440, minutes: 5 + i % 120)
            let l = SessionPictureLayout.make(seed: seed, startMinute: i * 7 % 1440, minutes: 5 + i % 120, progress: 0.5)
            #expect(l.horizon >= 150 && l.horizon <= 164)
            #expect(l.sunX >= 60 && l.sunX <= 180)
        }
    }

    @Test func theSunGrowsWithTheSessionUpTo150Minutes() {
        #expect(SessionPictureLayout.sunRadius(minutes: 1) < SessionPictureLayout.sunRadius(minutes: 60))
        #expect(SessionPictureLayout.sunRadius(minutes: 150) == 52)
        #expect(SessionPictureLayout.sunRadius(minutes: 600) == 52)
        #expect(abs(SessionPictureLayout.sunRadius(minutes: 75) - 35) < 1e-9)
    }

    @Test func theSunRisesWithTodaysProgress() {
        let seed = SessionPictureSeed.make(id: id, startMinute: 600, minutes: 30)
        let low = SessionPictureLayout.make(seed: seed, startMinute: 600, minutes: 30, progress: 0)
        let high = SessionPictureLayout.make(seed: seed, startMinute: 600, minutes: 30, progress: 1)
        #expect(abs((low.sunY - high.sunY) - 90) < 1e-9)
        // On the horizon at the start: the sun's centre sits just under it by 15% of its radius.
        #expect(abs(low.sunY - (low.horizon + low.sunRadius * 0.15)) < 1e-9)
    }

    @Test func oneLineForEveryFiveMinutesFromTwoToEighteen() {
        #expect(SessionPictureLayout.lineCount(minutes: 1) == 2)
        #expect(SessionPictureLayout.lineCount(minutes: 10) == 2)
        #expect(SessionPictureLayout.lineCount(minutes: 40) == 8)
        #expect(SessionPictureLayout.lineCount(minutes: 90) == 18)
        #expect(SessionPictureLayout.lineCount(minutes: 300) == 18)
        let l = SessionPictureLayout.make(seed: 1, startMinute: 600, minutes: 40, progress: 0.5)
        #expect(l.lines.count == 8)
    }

    @Test func starsOnlyAtNightAndInTheEvening() {
        func stars(_ minute: Int) -> Int {
            SessionPictureLayout.make(seed: 9, startMinute: minute, minutes: 30, progress: 0.5).stars.count
        }
        #expect(stars(2 * 60) == 14)       // night
        #expect(stars(19 * 60) == 14)      // evening
        #expect(stars(8 * 60) == 0)        // morning
        #expect(stars(12 * 60) == 0)       // midday
        #expect(stars(16 * 60) == 0)       // afternoon
    }

    // MARK: Sunrise progress at the end of a session

    private func at(_ h: Int, _ m: Int = 0) -> Date {
        Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 11, day: 8, hour: h, minute: m))!
    }

    @Test func theFirstSessionOfTheDayEndsPartWayUp() {
        let morning = SessionSunrise.Entry(id: UUID(), start: at(7, 40), durationSec: 40 * 60)
        let p = SessionSunrise.progressAtEnd(of: morning.id, among: [morning], target: 105 * 60)
        #expect(abs(p - 40.0 / 105) < 1e-9)
    }

    @Test func aLaterSessionStartsWhereTheDayLeftOff() {
        let morning = SessionSunrise.Entry(id: UUID(), start: at(7, 40), durationSec: 40 * 60)
        let evening = SessionSunrise.Entry(id: UUID(), start: at(18), durationSec: 25 * 60)
        let day = [evening, morning]   // any order in, the day's order is by start time
        #expect(abs(SessionSunrise.progressAtEnd(of: morning.id, among: day, target: 105 * 60) - 40.0 / 105) < 1e-9)
        #expect(abs(SessionSunrise.progressAtEnd(of: evening.id, among: day, target: 105 * 60) - 65.0 / 105) < 1e-9)
    }

    @Test func onceTheStretchIsCoveredEverySessionAfterItIsFullyUp() {
        let a = SessionSunrise.Entry(id: UUID(), start: at(8), durationSec: 2 * 3600)
        let b = SessionSunrise.Entry(id: UUID(), start: at(15), durationSec: 600)
        #expect(SessionSunrise.progressAtEnd(of: a.id, among: [a, b], target: 3600) == 1)
        #expect(SessionSunrise.progressAtEnd(of: b.id, among: [a, b], target: 3600) == 1)
    }

    @Test func aCatchUpEntryIsPlacedByTheDaysOrderToo() {
        let timer = SessionSunrise.Entry(id: UUID(), start: at(9), durationSec: 30 * 60)
        let catchUp = SessionSunrise.Entry(id: UUID(), start: at(12), durationSec: 30 * 60)
        #expect(abs(SessionSunrise.progressAtEnd(of: catchUp.id, among: [timer, catchUp], target: 120 * 60) - 0.5) < 1e-9)
    }

    // MARK: Cache

    @Test func clearingTheCacheEmptiesItAndReportsWhatItFreed() throws {
        let dir = SessionPictureCache.directory
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("test-\(UUID().uuidString).png")
        try Data(repeating: 7, count: 2_048).write(to: file)
        #expect(SessionPictureCache.sizeOnDisk() >= 2_048)
        let freed = SessionPictureCache.clear()
        #expect(freed >= 2_048)
        #expect(SessionPictureCache.sizeOnDisk() == 0)
        #expect(!FileManager.default.fileExists(atPath: file.path))
    }

    @Test func theFileNameHoldsEveryNumberThatChangesThePicture() {
        let a = SessionPictureCache.Key(seed: 1, startMinute: 460, minutes: 40, progress: 0.4, pixels: 120)
        #expect(a.fileName == "1-460-40-400-120.png")
        #expect(SessionPictureCache.Key(seed: 1, startMinute: 460, minutes: 40, progress: 0.5, pixels: 120).fileName != a.fileName)
        #expect(SessionPictureCache.Key(seed: 1, startMinute: 460, minutes: 40, progress: 0.4, pixels: 168).fileName != a.fileName)
    }

    @Test func theSpokenLabelNamesThePartOfTheDayAndTheLength() {
        let cal = Calendar(identifier: .gregorian)
        let start = cal.date(from: DateComponents(year: 2026, month: 11, day: 8, hour: 7, minute: 40))!
        let text = SessionPictureText.spoken(start: start, durationSec: 40 * 60, calendar: cal)
        #expect(text.hasPrefix("Session picture, morning, "))
        #expect(text.contains("40"))
    }
}
