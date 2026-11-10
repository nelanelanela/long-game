import Foundation
import SwiftData
import CloudKit
import CoreData

/// "Save to iCloud": the SwiftData store mirrored to the person's own private CloudKit database. No account, no
/// sign-in; it uses the iCloud account already on the device.
///
/// iCloud is compiled in only when the `CLOUD_SYNC` build flag is set in project.yml, which needs the iCloud
/// (CloudKit) capability on the app's signing team. Without the flag the store is always local.
enum CloudSync {
    static let containerID = "iCloud.com.wehavesun.LongGame"
    static let zoneName = "com.apple.coredata.cloudkit.zone"
    private static let enabledKey = "sync.enabled"

    static var isAvailable: Bool {
        #if CLOUD_SYNC
        true
        #else
        false
        #endif
    }

    /// The person's choice; nil until they have made one (or the first launch has defaulted it).
    static func preference(_ defaults: UserDefaults = .standard) -> Bool? {
        defaults.object(forKey: enabledKey) == nil ? nil : defaults.bool(forKey: enabledKey)
    }

    static func setPreference(_ on: Bool, _ defaults: UserDefaults = .standard) {
        defaults.set(on, forKey: enabledKey)
    }

    /// Whether the store is mirrored to iCloud: only when it is compiled in and the setting is on.
    static func isEnabled(_ defaults: UserDefaults = .standard) -> Bool {
        isAvailable && (preference(defaults) ?? false)
    }

    /// The database stays in the app's own folder. SwiftData's default (`.automatic`) puts it in the App Group folder
    /// as soon as the app has an App Group (the widgets and the watch need one), which would leave everyone's saved
    /// data behind in the old place.
    static func configuration(for schema: Schema, iCloud: Bool = isEnabled()) -> ModelConfiguration {
        iCloud && isAvailable
            ? ModelConfiguration(schema: schema, groupContainer: .none, cloudKitDatabase: .private(containerID))
            : ModelConfiguration(schema: schema, groupContainer: .none, cloudKitDatabase: .none)
    }

    static func availability(from status: CKAccountStatus) -> AccountAvailability {
        switch status {
        case .available: .available
        case .noAccount: .signedOut
        case .restricted: .restricted
        case .couldNotDetermine, .temporarilyUnavailable: .unknown
        @unknown default: .unknown
        }
    }

    /// Asks the device about its iCloud account.
    static func accountAvailability() async -> AccountAvailability {
        guard isAvailable else { return .signedOut }
        do { return availability(from: try await CKContainer(identifier: containerID).accountStatus()) }
        catch { return .unknown }
    }

    /// Removes the copy in iCloud (the whole private zone SwiftData mirrors into). A zone that is not there is fine.
    static func deleteCloudZone() async throws {
        guard isAvailable else { return }
        let database = CKContainer(identifier: containerID).privateCloudDatabase
        do {
            _ = try await database.deleteRecordZone(withID: CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName))
        } catch let error as CKError where error.code == .zoneNotFound {
            return
        }
    }
}

/// Holds the model container and swaps it when "Save to iCloud" is switched. The same database file is reopened
/// with or without CloudKit mirroring, so nothing on the device is lost either way.
@MainActor
@Observable
final class StoreHost {
    private(set) var container: ModelContainer
    /// Changes whenever the container is replaced, so the screens can start over on the new one.
    private(set) var generation = 0
    /// True when there was no database yet at launch: a new install (or a reset), which may have a game in iCloud.
    let isFreshInstall: Bool

    private let make: (Bool) throws -> ModelContainer
    private let defaults: UserDefaults

    /// The stores that were just replaced. When a store closes, everything read from it (the craft Settings is
    /// showing, say) becomes unusable, and reading it crashes the app. The screens need a moment to redraw with the
    /// new store, so the old one stays open for `retireAfter` and is closed only then.
    private var retired: [ModelContainer] = []
    private var closingRetired: Task<Void, Never>?
    private let retireAfter: Duration

    init(defaults: UserDefaults = .standard, isFreshInstall: Bool? = nil, retireAfter: Duration = .seconds(3),
         make: ((Bool) throws -> ModelContainer)? = nil) throws {
        self.defaults = defaults
        self.retireAfter = retireAfter
        let schema = Schema([Craft.self, YearEstimate.self, Session.self, AppSettings.self, TargetPeriod.self, ActiveSession.self])
        self.make = make ?? { iCloud in
            try ModelContainer(for: schema, configurations: CloudSync.configuration(for: schema, iCloud: iCloud))
        }
        let fresh = isFreshInstall ?? !FileManager.default.fileExists(atPath: CloudSync.configuration(for: schema, iCloud: false).url.path)
        self.isFreshInstall = fresh
        // On a new install iCloud is on from the start (the choice screen shows it on by default), so a game that is
        // already in the person's iCloud can arrive. An existing install never turns itself on.
        if fresh, CloudSync.preference(defaults) == nil, CloudSync.isAvailable { CloudSync.setPreference(true, defaults) }
        container = try self.make(CloudSync.isEnabled(defaults))
    }

    var iCloudOn: Bool { CloudSync.isEnabled(defaults) }

    /// Switches iCloud on or off and reopens the store. If the new store cannot be opened, nothing changes.
    func setICloud(_ on: Bool) throws {
        guard on != iCloudOn || CloudSync.preference(defaults) == nil else { return }
        try container.mainContext.save()
        let next = try make(on && CloudSync.isAvailable)
        CloudSync.setPreference(on, defaults)
        retire(container)
        container = next
        generation += 1
        if let row = (try? next.mainContext.fetch(FetchDescriptor<AppSettings>()))?.first, row.syncEnabled != on {
            row.syncEnabled = on
            try? next.mainContext.save()
        }
    }

    /// "Delete iCloud copy": stops syncing first (so the copy on this iPhone cannot be sent up again or taken down
    /// with it), then removes only the iCloud data. The games on this device stay.
    func deleteICloudCopy(removeRemote: () async throws -> Void = { try await CloudSync.deleteCloudZone() }) async throws {
        try setICloud(false)
        // Wait for the old, mirrored store to close, so nothing it still holds can be sent up after the copy is gone.
        await closingRetired?.value
        try await removeRemote()
    }

    /// Keeps a replaced store open a little longer (see `retired`). Each switch restarts the wait.
    private func retire(_ old: ModelContainer) {
        retired.append(old)
        closingRetired?.cancel()
        let wait = retireAfter
        closingRetired = Task { [weak self] in
            try? await Task.sleep(for: wait)
            guard !Task.isCancelled else { return }
            self?.retired.removeAll()
        }
    }
}

/// What Settings and the onboarding card show about iCloud: the account, and how the sync is going.
@MainActor
@Observable
final class ICloudMonitor {
    /// nil while the first answer is on its way.
    private(set) var availability: AccountAvailability?
    private(set) var syncing = false
    private(set) var lastSync: Date?
    private var observing = false

    func refresh() async {
        availability = await CloudSync.accountAvailability()
    }

    /// The account status, asking if it has not been asked yet.
    func availabilityNow() async -> AccountAvailability {
        if let availability { return availability }
        await refresh()
        return availability ?? .unknown
    }

    /// Starts following the account and SwiftData's CloudKit events. Safe to call again.
    func start() {
        guard !observing, CloudSync.isAvailable else { return }
        observing = true
        let center = NotificationCenter.default
        Task { [weak self] in
            for await note in center.notifications(named: NSPersistentCloudKitContainer.eventChangedNotification) {
                let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                    as? NSPersistentCloudKitContainer.Event
                await self?.handle(endDate: event?.endDate, succeeded: event?.succeeded ?? false)
            }
        }
        Task { [weak self] in
            for await _ in center.notifications(named: .CKAccountChanged) { await self?.refresh() }
        }
    }

    private func handle(endDate: Date?, succeeded: Bool) {
        if let endDate {
            syncing = false
            if succeeded { lastSync = endDate }
        } else {
            syncing = true
        }
    }

    func status(enabled: Bool, now: Date = Date()) -> SyncStatus {
        SyncStatus.make(enabled: enabled, availability: availability, syncing: syncing, lastSync: lastSync)
    }
}
