import Testing
import Foundation
import SwiftData
import CloudKit
@testable import LongGame

@MainActor
struct ICloudTests {
    private let schema = Schema([Craft.self, YearEstimate.self, Session.self, AppSettings.self, TargetPeriod.self])

    private func freshDefaults() -> UserDefaults {
        let name = "icloud-tests-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    // MARK: The setting decides the kind of store

    /// CloudKitDatabase is not Equatable; its description names the container when it is the private database.
    private func usesCloudKit(_ config: ModelConfiguration) -> Bool {
        String(describing: config.cloudKitDatabase).contains(CloudSync.containerID)
    }

    @Test func theSettingOffMeansALocalOnlyStore() {
        let config = CloudSync.configuration(for: schema, iCloud: false)
        #expect(!usesCloudKit(config))
    }

    @Test func theSettingOnMeansTheCloudKitPrivateDatabaseWhenItIsCompiledIn() {
        let config = CloudSync.configuration(for: schema, iCloud: true)
        #expect(usesCloudKit(config) == CloudSync.isAvailable)
        // Either way the database stays in the app's own folder.
        #expect(config.url.lastPathComponent == "default.store")
    }

    @Test func isEnabledFollowsThePreference() {
        let d = freshDefaults()
        #expect(CloudSync.preference(d) == nil)
        #expect(!CloudSync.isEnabled(d))
        CloudSync.setPreference(true, d)
        #expect(CloudSync.isEnabled(d) == CloudSync.isAvailable)
        CloudSync.setPreference(false, d)
        #expect(!CloudSync.isEnabled(d))
    }

    // MARK: Account status

    @Test func theDeviceAccountStatusMapsToOurStates() {
        #expect(CloudSync.availability(from: .available) == .available)
        #expect(CloudSync.availability(from: .noAccount) == .signedOut)
        #expect(CloudSync.availability(from: .restricted) == .restricted)
        #expect(CloudSync.availability(from: .couldNotDetermine) == .unknown)
        #expect(CloudSync.availability(from: .temporarilyUnavailable) == .unknown)
    }

    @Test func withoutAnAccountTheSwitchIsOffAndDisabledWithAHint() {
        for availability in [AccountAvailability.signedOut, .restricted, .unknown] {
            let state = ICloudSwitchState.make(availability: availability, wantsOn: true)
            #expect(!state.isOn)
            #expect(!state.isEnabled)
            #expect(state.showsSignInHint)
        }
    }

    @Test func withAnAccountTheSwitchFollowsTheChoice() {
        #expect(ICloudSwitchState.make(availability: .available, wantsOn: true) == .init(isOn: true, isEnabled: true, showsSignInHint: false))
        #expect(ICloudSwitchState.make(availability: .available, wantsOn: false) == .init(isOn: false, isEnabled: true, showsSignInHint: false))
        // Still asking the device: no hint yet, no flash of "Sign in".
        #expect(ICloudSwitchState.make(availability: nil, wantsOn: true) == .init(isOn: true, isEnabled: true, showsSignInHint: false))
    }

    @Test func theStatusLine() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        #expect(SyncStatus.make(enabled: true, availability: .signedOut, syncing: false, lastSync: nil) == .signInNeeded)
        #expect(SyncStatus.make(enabled: false, availability: .available, syncing: false, lastSync: nil) == .off)
        #expect(SyncStatus.make(enabled: true, availability: .available, syncing: true, lastSync: nil) == .syncing)
        #expect(SyncStatus.syncing.text(now: now, calendar: utc) == "Syncing…")
        #expect(SyncStatus.synced(now.addingTimeInterval(-10)).text(now: now, calendar: utc) == "Up to date")
        #expect(SyncStatus.synced(nil).text(now: now, calendar: utc) == "Up to date")
        let earlier = now.addingTimeInterval(-3600)
        let hhmm = { () -> String in
            let f = DateFormatter(); f.calendar = utc; f.timeZone = utc.timeZone; f.dateFormat = "HH:mm"
            return f.string(from: earlier)
        }()
        #expect(SyncStatus.synced(earlier).text(now: now, calendar: utc) == "Last synced \(hhmm)")
        #expect(SyncStatus.signInNeeded.text(now: now) == "Sign in to iCloud in the Settings app to keep a copy.")
    }

    // MARK: Switching and "Delete iCloud copy"

    private func host(_ d: UserDefaults) throws -> (StoreHost, ModelContainer) {
        // One in-memory store stands in for the database file, which is the same file with or without CloudKit.
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        return (try StoreHost(defaults: d, isFreshInstall: false, make: { _ in container }), container)
    }

    @Test func switchingICloudKeepsTheDataOnThisDevice() throws {
        let d = freshDefaults()
        let (host, container) = try host(d)
        let context = container.mainContext
        context.insert(Craft(name: "Piano", startYear: 2020))
        context.insert(AppSettings())
        try context.save()
        let before = host.generation
        try host.setICloud(true)
        try host.setICloud(false)
        #expect(host.generation == before + 2)
        #expect(CloudSync.preference(d) == false)
        #expect(try host.container.mainContext.fetchCount(FetchDescriptor<Craft>()) == 1)
    }

    @Test func aStoreThatCannotBeOpenedChangesNothing() throws {
        let d = freshDefaults()
        struct Boom: Error {}
        var allow = true
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let host = try StoreHost(defaults: d, isFreshInstall: false, make: { _ in
            if allow { return container }
            throw Boom()
        })
        CloudSync.setPreference(false, d)
        allow = false
        #expect(throws: Boom.self) { try host.setICloud(true) }
        #expect(CloudSync.preference(d) == false)
        #expect(host.generation == 0)
    }

    @Test func deletingTheICloudCopyLeavesTheLocalDataAndTurnsSyncOff() async throws {
        let d = freshDefaults()
        CloudSync.setPreference(true, d)
        let (host, container) = try host(d)
        let context = container.mainContext
        let craft = Craft(name: "Piano", startYear: 2020)
        context.insert(craft)
        context.insert(Session(craftId: craft.id, start: Date(), durationSec: 3600, source: .manual))
        context.insert(AppSettings())
        try context.save()

        var removedRemote = false
        try await host.deleteICloudCopy { removedRemote = true }

        #expect(removedRemote)
        #expect(!host.iCloudOn)
        #expect(CloudSync.preference(d) == false)
        #expect(try host.container.mainContext.fetchCount(FetchDescriptor<Craft>()) == 1)
        #expect(try host.container.mainContext.fetchCount(FetchDescriptor<Session>()) == 1)
    }

    @Test func iCloudIsNotRemovedIfSyncCouldNotBeStopped() async throws {
        let d = freshDefaults()
        struct Boom: Error {}
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        var fail = false
        let host = try StoreHost(defaults: d, isFreshInstall: false, make: { _ in
            if fail { throw Boom() }
            return container
        })
        CloudSync.setPreference(true, d)
        fail = true
        var removedRemote = false
        await #expect(throws: Boom.self) { try await host.deleteICloudCopy { removedRemote = true } }
        #expect(!removedRemote)
    }

    // MARK: Welcome back

    @Test func aFoundGameShowsWelcomeBack() {
        let game = FoundGame(craftName: "Piano", hours: 3294)
        #expect(WelcomeBack.decide(.found(game)) == .welcomeBack(game))
        #expect(game.summary == "Piano · 3,294 hours")
        #expect(FoundGame(craftName: "Piano", hours: 1).summary == "Piano · 1 hour")
    }

    @Test func noGameOrNoAnswerShowsTheNormalWelcome() {
        #expect(WelcomeBack.decide(.notFound) == .normalOnboarding)
        #expect(WelcomeBack.decide(.timedOut) == .normalOnboarding)
    }

    @Test func onlyAFreshInstallWithAUsableAccountLooksInICloud() {
        #expect(ICloudLaunch.shouldLookForGame(isFreshInstall: true, hasActiveCraft: false, availability: .available))
        #expect(ICloudLaunch.shouldLookForGame(isFreshInstall: true, hasActiveCraft: false, availability: .unknown))
        #expect(!ICloudLaunch.shouldLookForGame(isFreshInstall: false, hasActiveCraft: false, availability: .available))
        #expect(!ICloudLaunch.shouldLookForGame(isFreshInstall: true, hasActiveCraft: true, availability: .available))
        #expect(!ICloudLaunch.shouldLookForGame(isFreshInstall: true, hasActiveCraft: false, availability: .signedOut))
        #expect(!ICloudLaunch.shouldLookForGame(isFreshInstall: true, hasActiveCraft: false, availability: .restricted))
    }

    @Test func theProbeFindsAGameThatIsThereAndSteady() async {
        let game = FoundGame(craftName: "Piano", hours: 3294)
        let outcome = await WelcomeBack.probe(timeout: .seconds(2), pollEvery: .milliseconds(10)) { game }
        #expect(outcome == .found(game))
    }

    @Test func theProbeWaitsForTheHoursToFinishArriving() async {
        let counter = Counter()
        let outcome = await WelcomeBack.probe(timeout: .seconds(2), pollEvery: .milliseconds(10)) {
            // The craft arrives first, then its hours in two steps, then nothing changes.
            switch counter.next() {
            case 0: FoundGame(craftName: "Piano", hours: 0)
            case 1: FoundGame(craftName: "Piano", hours: 1200)
            default: FoundGame(craftName: "Piano", hours: 3294)
            }
        }
        #expect(outcome == .found(FoundGame(craftName: "Piano", hours: 3294)))
    }

    @Test func theProbeGivesUpAfterTheTimeoutWhenNothingArrives() async {
        let started = ContinuousClock.now
        let outcome = await WelcomeBack.probe(timeout: .milliseconds(150), pollEvery: .milliseconds(10)) { nil }
        #expect(outcome == .timedOut)
        #expect(ContinuousClock.now - started < .seconds(2))
    }

    @Test func aGameStillChangingAtTheDeadlineIsStillOffered() async {
        let counter = Counter()
        let outcome = await WelcomeBack.probe(timeout: .milliseconds(150), pollEvery: .milliseconds(10)) {
            FoundGame(craftName: "Piano", hours: counter.next())
        }
        guard case .found(let game) = outcome else { Issue.record("expected a found game, got \(outcome)"); return }
        #expect(game.craftName == "Piano")
    }

    @Test func thePhoneWaitsAtMostThreeSecondsByDefault() {
        #expect(WelcomeBack.timeout == .seconds(3))
    }
}

@MainActor
private final class Counter {
    private var n = -1
    func next() -> Int { n += 1; return n }
}
