import Testing
import Foundation
import SwiftData
@testable import LongGame

/// The performance pass of 15 November 2026 (docs/PERFORMANCE_PLAN.md): Home keeps its session values between
/// redraws, and thumbnails of saved photos never hold on to an old photo.
@MainActor
struct SessionRecordsCacheTests {
    private func container() throws -> ModelContainer {
        let schema = Schema([Craft.self, YearEstimate.self, Session.self, AppSettings.self, TargetPeriod.self])
        return try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
    }

    private func sessions(_ context: ModelContext) throws -> [Session] {
        try context.fetch(FetchDescriptor<Session>(sortBy: [SortDescriptor(\.start, order: .reverse)]))
    }

    @Test func valuesMatchAPlainRead() throws {
        let context = ModelContext(try container())
        let craft = UUID()
        for day in 0..<30 {
            context.insert(Session(craftId: craft, start: Date(timeIntervalSince1970: 1_700_000_000 - Double(day) * 86_400),
                                   durationSec: Double(600 + day * 60), source: day.isMultiple(of: 5) ? .catchUp : .manual))
        }
        let list = try sessions(context)
        let cache = SessionRecordsCache()
        #expect(cache.records(for: list) == list.map(\.record))
        // Asked again with nothing changed: the same values.
        #expect(cache.records(for: list) == list.map(\.record))
    }

    @Test func anEditIsSeen() async throws {
        let context = ModelContext(try container())
        let session = Session(craftId: UUID(), start: Date(timeIntervalSince1970: 1_700_000_000), durationSec: 600, source: .manual)
        context.insert(session)
        let list = try sessions(context)
        let cache = SessionRecordsCache()
        #expect(cache.records(for: list).map(\.durationSec) == [600])
        let before = cache.version
        session.durationSec = 1_800
        #expect(cache.records(for: list).map(\.durationSec) == [1_800])
        // And Home is told to redraw.
        await Task.yield()
        #expect(cache.version != before)
    }

    @Test func aNewOrRemovedSessionIsSeen() throws {
        let context = ModelContext(try container())
        let craft = UUID()
        context.insert(Session(craftId: craft, start: Date(timeIntervalSince1970: 1_700_000_000), durationSec: 600, source: .manual))
        let cache = SessionRecordsCache()
        #expect(cache.records(for: try sessions(context)).count == 1)
        let added = Session(craftId: craft, start: Date(timeIntervalSince1970: 1_700_090_000), durationSec: 900, source: .timer)
        context.insert(added)
        #expect(cache.records(for: try sessions(context)).map(\.durationSec) == [900, 600])
        context.delete(added)
        #expect(cache.records(for: try sessions(context)).map(\.durationSec) == [600])
    }
}

@MainActor
struct ThumbnailGenerationTests {
    @Test func settingAPhotoMovesItsGenerationOn() throws {
        let session = Session(craftId: UUID(), start: .now, durationSec: 600, source: .manual)
        let before = ThumbnailCache.generation(session.id)
        session.setPhoto(Data([1, 2, 3]))
        #expect(ThumbnailCache.generation(session.id) == before + 1)
        session.setPhoto(nil)
        #expect(ThumbnailCache.generation(session.id) == before + 2)
    }

    @Test func aTodayRowWithASavedPhotoCarriesNoBytes() {
        let row = TodaySession(id: UUID(), start: .now, end: .now, durationSec: 60, note: nil, photo: nil, hasSavedPhoto: true)
        #expect(row.hasPhoto)
        #expect(row.photo == nil)
    }
}

/// Export is now built in the background from its own read of the database: it still holds every session of every
/// craft and every letter.
struct ExportFilesTests {
    @Test func everySessionAndLetterIsExported() throws {
        let schema = Schema([Craft.self, YearEstimate.self, Session.self, AppSettings.self, TargetPeriod.self, Letter.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let context = ModelContext(container)
        let piano = Craft(name: "Piano", startYear: 2020)
        let clay = Craft(name: "Clay", startYear: 2018)
        context.insert(piano)
        context.insert(clay)
        context.insert(Session(craftId: piano.id, start: Date(timeIntervalSince1970: 1_700_000_000), durationSec: 3_600, source: .manual, note: "Scales"))
        context.insert(Session(craftId: clay.id, start: Date(timeIntervalSince1970: 1_600_000_000), durationSec: 1_800, source: .timer))
        context.insert(Letter(craftId: piano.id, text: "Keep going", totalWhenWritten: 10, milestone: 100))
        try context.save()

        let files = ExportFiles.write(container: container)
        let sessions = try String(contentsOf: try #require(files.sessions), encoding: .utf8)
        #expect(sessions.contains("Piano"))
        #expect(sessions.contains("Clay"))
        #expect(sessions.contains("Scales"))
        #expect(sessions.split(separator: "\n").count == 3)   // the header and two sessions
        // A sealed letter is listed, its words kept back until it is opened (as before).
        let letters = try String(contentsOf: try #require(files.letters), encoding: .utf8)
        #expect(letters.contains("sealed until 100 h"))
        #expect(!letters.contains("Keep going"))
    }
}
