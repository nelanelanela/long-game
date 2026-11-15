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
