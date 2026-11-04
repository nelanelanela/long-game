import Testing
import Foundation
import SwiftData
import ImageIO
import UniformTypeIdentifiers
import CoreGraphics
@testable import LongGame

/// A plain-colour test picture, written as JPEG with location and camera details in its metadata.
private func testPhoto(width: Int, height: Int, withMetadata: Bool = true) -> Data {
    let space = CGColorSpaceCreateDeviceRGB()
    let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    ctx.setFillColor(CGColor(red: 0.9, green: 0.6, blue: 0.2, alpha: 1))
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let image = ctx.makeImage()!
    let out = NSMutableData()
    let dest = CGImageDestinationCreateWithData(out, UTType.jpeg.identifier as CFString, 1, nil)!
    var props: [CFString: Any] = [:]
    if withMetadata {
        props[kCGImagePropertyGPSDictionary] = [kCGImagePropertyGPSLatitude: 51.5, kCGImagePropertyGPSLatitudeRef: "N",
                                                kCGImagePropertyGPSLongitude: 0.12, kCGImagePropertyGPSLongitudeRef: "W"]
        props[kCGImagePropertyExifDictionary] = [kCGImagePropertyExifUserComment: "taken at home"]
        props[kCGImagePropertyTIFFDictionary] = [kCGImagePropertyTIFFMake: "Acme", kCGImagePropertyTIFFModel: "Cam 1"]
    }
    CGImageDestinationAddImage(dest, image, props as CFDictionary)
    CGImageDestinationFinalize(dest)
    return out as Data
}

struct PhotoProcessingTests {
    @Test func theTestPictureReallyCarriesLocationAndCameraDetails() {
        let source = testPhoto(width: 400, height: 300)
        let keys = PhotoProcessing.metadataKeys(source)
        #expect(keys.contains(kCGImagePropertyGPSDictionary as String))
        #expect(keys.contains(kCGImagePropertyTIFFDictionary as String))
    }

    @Test func aBigPhotoIsCutDownToTheLimitOnItsLongestSide() throws {
        let out = try #require(PhotoProcessing.prepare(testPhoto(width: 4000, height: 3000)))
        let size = try #require(PhotoProcessing.pixelSize(out))
        #expect(Int(max(size.width, size.height)) == PhotoProcessing.maxSide)
        // The proportions stay: 4:3.
        #expect(abs(size.width / size.height - 4.0 / 3.0) < 0.01)
        let tall = try #require(PhotoProcessing.prepare(testPhoto(width: 2500, height: 5000)))
        let tallSize = try #require(PhotoProcessing.pixelSize(tall))
        #expect(Int(tallSize.height) == 2048 && Int(tallSize.width) == 1024)
    }

    @Test func aSmallPhotoIsNeverEnlarged() throws {
        let out = try #require(PhotoProcessing.prepare(testPhoto(width: 800, height: 600)))
        let size = try #require(PhotoProcessing.pixelSize(out))
        #expect(Int(size.width) == 800 && Int(size.height) == 600)
    }

    @Test func theResultIsAJPEG() throws {
        let out = try #require(PhotoProcessing.prepare(testPhoto(width: 640, height: 480)))
        #expect(Array(out.prefix(3)) == [0xFF, 0xD8, 0xFF])
        let type = CGImageSourceCreateWithData(out as CFData, nil).flatMap(CGImageSourceGetType)
        #expect(type as String? == UTType.jpeg.identifier)
    }

    @Test func locationAndOtherDetailsAreStripped() throws {
        let out = try #require(PhotoProcessing.prepare(testPhoto(width: 640, height: 480)))
        #expect(PhotoProcessing.metadataKeys(out).isEmpty)
    }

    @Test func somethingThatIsNotAPictureIsRefused() {
        #expect(PhotoProcessing.prepare(Data("not a picture".utf8)) == nil)
        #expect(PhotoProcessing.prepare(Data()) == nil)
    }

    @Test func thumbnailsAreMadeAtTheSmallSize() throws {
        let out = try #require(PhotoProcessing.prepare(testPhoto(width: 3000, height: 2000)))
        let thumb = try #require(PhotoProcessing.thumbnail(out, maxPixel: 168))
        #expect(max(thumb.width, thumb.height) == 168)
    }
}

struct NoteLimitTests {
    @Test func aNoteIsAtMost500Characters() {
        #expect(SessionRules.maxNoteLength == 500)
        let long = String(repeating: "a", count: 700)
        #expect(SessionRules.clampedNote(long).count == 500)
        #expect(SessionRules.clampedNote("short") == "short")
        #expect(SessionRules.savedNote(long)?.count == 500)
    }

    @Test func aBlankNoteIsNotSaved() {
        #expect(SessionRules.savedNote("") == nil)
        #expect(SessionRules.savedNote("  \n ") == nil)
        #expect(SessionRules.savedNote("  Slower in bar 12 \n") == "Slower in bar 12")
    }
}

struct NoteCSVTests {
    private func row(_ note: String) -> CSVExport.Row {
        CSVExport.Row(craft: "Piano", start: day(2026, 10, 22, hour: 18), durationSec: 4500, source: "timer", note: note)
    }

    @Test func commasQuotesAndNewLinesInANoteAreEscaped() {
        #expect(CSVExport.escape("plain") == "plain")
        #expect(CSVExport.escape("left hand, bar 12") == "\"left hand, bar 12\"")
        #expect(CSVExport.escape("she said \"slower\"") == "\"she said \"\"slower\"\"\"")
        #expect(CSVExport.escape("line one\nline two") == "\"line one\nline two\"")
    }

    @Test func aNastyNoteSurvivesTheTripThroughExportAndImport() {
        let note = "Bar 12, \"rushing\"\nTry again, slower"
        let csv = CSVExport.sessions([row(note)], calendar: utc)
        let parsed = CSVImport.sessions(csv, calendar: utc)
        #expect(parsed.rows.count == 1)
        #expect(parsed.rows.first?.note == note)
    }

    @Test func theFileHasNoPhotoColumn() {
        let csv = CSVExport.sessions([row("hi")], calendar: utc)
        #expect(csv.hasPrefix("Craft,Date,Start,Minutes,Source,Note\n"))
        #expect(!csv.lowercased().contains("photo"))
    }
}

struct PhotoDayTests {
    @Test func aDayHasAPhotoWhenAnySessionOnItDoes() {
        let sessions: [(start: Date, hasPhoto: Bool)] = [
            (day(2026, 10, 22, hour: 9), false), (day(2026, 10, 22, hour: 18), true),
            (day(2026, 10, 23, hour: 18), false),
        ]
        let days = SessionPhotos.daysWithPhoto(sessions, calendar: utc)
        #expect(days == [day(2026, 10, 22, hour: 0)])
        #expect(SessionPhotos.daysWithPhoto([], calendar: utc).isEmpty)
    }

    @Test func partsOfTheDayAndTheViewerCaption() {
        #expect(SessionPhotos.dayPart(day(2026, 10, 22, hour: 7), calendar: utc) == .morning)
        #expect(SessionPhotos.dayPart(day(2026, 10, 22, hour: 13), calendar: utc) == .afternoon)
        #expect(SessionPhotos.dayPart(day(2026, 10, 22, hour: 19), calendar: utc) == .evening)
        #expect(SessionPhotos.dayPart(day(2026, 10, 22, hour: 23), calendar: utc) == .night)
        #expect(SessionPhotos.dayPart(day(2026, 10, 22, hour: 3), calendar: utc) == .night)
        #expect(SessionPhotos.caption(start: day(2026, 10, 22, hour: 19), durationSec: 75 * 60, calendar: utc) == "Evening · 1 h 15")
        #expect(SessionPhotos.caption(start: day(2026, 10, 22, hour: 7), durationSec: 40 * 60, calendar: utc) == "Morning · 40 m")
    }

    @Test func theSpokenLabelNamesTheDayAndTheSession() {
        #expect(SessionPhotos.spokenLabel(start: day(2026, 10, 22, hour: 19), calendar: utc)
                == "Photo from Thursday 22 October, evening session")
    }
}

@MainActor
struct SessionPhotoStorageTests {
    private func container() throws -> ModelContainer {
        let schema = Schema([Craft.self, YearEstimate.self, Session.self, AppSettings.self, TargetPeriod.self])
        return try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
    }

    @Test func aSessionKeepsItsPhotoAndNote() throws {
        let context = ModelContext(try container())
        let photo = try #require(PhotoProcessing.prepare(testPhoto(width: 300, height: 200)))
        let s = Session(craftId: UUID(), start: Date(), durationSec: 600, source: .timer, note: "Good", photo: photo)
        context.insert(s)
        try context.save()
        let fetched = try #require(try context.fetch(FetchDescriptor<Session>()).first)
        #expect(fetched.photo == photo && fetched.hasPhoto && fetched.note == "Good")
    }

    @Test func aSessionWithoutAPhotoIsUnchanged() throws {
        let context = ModelContext(try container())
        context.insert(Session(craftId: UUID(), start: Date(), durationSec: 600, source: .manual))
        try context.save()
        let fetched = try #require(try context.fetch(FetchDescriptor<Session>()).first)
        #expect(fetched.photo == nil && !fetched.hasPhoto)
    }

    @Test func removingThePhotoClearsIt() throws {
        let context = ModelContext(try container())
        let s = Session(craftId: UUID(), start: Date(), durationSec: 600, source: .timer, photo: Data([1, 2, 3]))
        context.insert(s)
        s.setPhoto(nil)
        try context.save()
        #expect(s.photo == nil && !s.hasPhoto)
    }

    @Test func deletingASessionDeletesItsPhoto() throws {
        let context = ModelContext(try container())
        let photo = try #require(PhotoProcessing.prepare(testPhoto(width: 300, height: 200)))
        let s = Session(craftId: UUID(), start: Date(), durationSec: 600, source: .timer, photo: photo)
        context.insert(s)
        try context.save()
        context.delete(s)
        try context.save()
        #expect(try context.fetch(FetchDescriptor<Session>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Session>(predicate: #Predicate { $0.hasPhoto })).isEmpty)
    }
}
