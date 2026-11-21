import Testing
import Foundation
import SwiftData
@testable import LongGame

/// Update 50: a store made by the version on `main` (the last one before the redesign) opens in this version with
/// nothing lost. The fixture in `Fixtures/MainStore` was made by running `main` with `-demoData` in the Simulator,
/// plus three sessions given a photo and a note and a few settings changed (in a throwaway copy, so `main`'s store
/// layout is exactly as shipped there). Since then the store has only gained things: new fields with defaults on
/// Session and AppSettings, and the Letter table, which SwiftData adds by itself.
@MainActor
struct MigrationTests {
    private func openFixture() throws -> ModelContainer {
        let bundle = try #require(Bundle.allBundles.first { $0.bundlePath.hasSuffix(".xctest") })
        let source = try #require(bundle.url(forResource: "default", withExtension: "store"))
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("migration-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let copy = folder.appendingPathComponent("default.store")
        try FileManager.default.copyItem(at: source, to: copy)
        let schema = Schema([Craft.self, YearEstimate.self, Session.self, AppSettings.self, TargetPeriod.self,
                             ActiveSession.self, Letter.self])
        return try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: copy, cloudKitDatabase: .none))
    }

    @Test func mainStoreOpensWithNothingLost() throws {
        let container = try openFixture()
        let context = container.mainContext

        let crafts = try context.fetch(FetchDescriptor<Craft>())
        #expect(crafts.count == 1)
        #expect(crafts.first?.name == "Piano")
        #expect(crafts.first?.startYear == 2019)

        let sessions = try context.fetch(FetchDescriptor<Session>())
        #expect(sessions.count == 94)
        let withPhotos = sessions.filter(\.hasPhoto)
        #expect(withPhotos.count == 3)
        #expect(withPhotos.allSatisfy { ($0.photo?.count ?? 0) > 0 })
        #expect(Set(withPhotos.compactMap(\.note)) == ["Fixture photo 1", "Fixture photo 2", "Fixture photo 3"])
        // New on Session since main: defaults.
        #expect(sessions.allSatisfy { $0.viewCount == 0 && !$0.hidesDefaultPicture })

        let estimates = try context.fetch(FetchDescriptor<YearEstimate>())
        #expect(estimates.count == 8)
        // Update 53's optional total opens empty: every year keeps its hours a week.
        #expect(estimates.allSatisfy { $0.totalHours == nil })

        let settings = try #require(try context.fetch(FetchDescriptor<AppSettings>()).first)
        #expect(settings.weekStart == .sunday)
        #expect(settings.reminderDays == [2, 4, 6])
        // main's Home then celebrated 2,500 (the sample total is past it) and saved that too.
        #expect(Set(settings.milestonesSeen) == [100, 500, 1_000, 2_500], "\(settings.milestonesSeen)")
        // New on AppSettings since main: their defaults.
        #expect(settings.appearance == .automatic)
        #expect(settings.sunRemembers)
        #expect(!settings.weatherInScene)
        #expect(!settings.thousandsAdopted)
        #expect(!settings.notificationAskShown)
        #expect(!settings.weatherInviteShown)

        #expect(try context.fetch(FetchDescriptor<Letter>()).isEmpty)
    }

    /// The new table works in the migrated store.
    @Test func lettersCanBeAddedToAMigratedStore() throws {
        let container = try openFixture()
        let context = container.mainContext
        let craft = try #require(try context.fetch(FetchDescriptor<Craft>()).first)
        context.insert(Letter(craftId: craft.id, text: "Hello", totalWhenWritten: 1_000, milestone: 2_000))
        try context.save()
        #expect(try context.fetch(FetchDescriptor<Letter>()).count == 1)
    }

    /// Updating at the fixture's total doesn't celebrate thousands already passed.
    @Test func updatingKeepsOldThousandsQuiet() throws {
        let seen = Milestones.adoptingThousands(total: 3_294, seen: [100, 500, 1_000])
        #expect(Milestones.newlyCrossed(total: 3_294, seen: seen) == [2_500])
    }
}
