import Foundation
import SwiftData
import CoreData
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

/// Keeps the running session in step across devices. When "Save to iCloud" is on, every change to the timer made
/// here is written to an `ActiveSession` record, and every record that arrives from another device is turned into
/// what this timer should do (`ActiveSessionSync`). The timer itself stays timestamps on each device.
@MainActor
final class ActiveSessionSyncer {
    private var timer: TimerStore!
    private let enabled: () -> Bool
    private var container: ModelContainer?
    /// The session this device last knew about, so a finish (a timer of nil) can end the right record.
    private var known: TimerState?
    private var observing = false

    init(enabled: @escaping () -> Bool = { CloudSync.isEnabled() }) {
        self.enabled = enabled
    }

    static var deviceName: String {
        #if canImport(UIKit)
        UIDevice.current.name
        #else
        Host.current().localizedName ?? "Mac"
        #endif
    }

    /// Call again whenever the store is replaced (iCloud switched on or off).
    func start(timer: TimerStore, container: ModelContainer) {
        self.timer = timer
        self.container = container
        known = timer.state
        timer.onSyncChange = { [weak self] update in self?.push(update) }
        observeOnce()
        reconcile()
    }

    private func observeOnce() {
        guard !observing else { return }
        observing = true
        let center = NotificationCenter.default
        Task { [weak self] in
            for await _ in center.notifications(named: NSPersistentCloudKitContainer.eventChangedNotification) {
                self?.reconcile()
            }
        }
        #if canImport(UIKit)
        let active = UIApplication.didBecomeActiveNotification
        #else
        let active = NSApplication.didBecomeActiveNotification
        #endif
        Task { [weak self] in
            for await _ in center.notifications(named: active) { self?.reconcile() }
        }
    }

    // MARK: Writing

    /// This device changed the timer (or the watch did): write it down for the others.
    func push(_ update: TimerUpdate) {
        guard enabled(), let container, timer != nil else { return }
        let context = ModelContext(container)
        let rows = (try? context.fetch(FetchDescriptor<ActiveSession>())) ?? []
        if let state = update.state {
            if let row = rows.first(where: { $0.endedAt == nil && $0.record.isSameSession(as: state) }) {
                var record = row.record
                record.pausedAt = state.pausedAt
                record.accumulatedPause = state.accumulatedPause
                record.changedAt = update.changedAt
                row.apply(record)
            } else {
                context.insert(ActiveSession(ActiveSessionRecord(state: state, deviceName: Self.deviceName, changedAt: update.changedAt)))
            }
            known = state
        } else if let ended = known {
            for row in rows where row.endedAt == nil && row.record.isSameSession(as: ended) {
                row.endedAt = update.changedAt
                row.changedAt = update.changedAt
            }
            known = nil
        }
        try? context.save()
        reconcile()
    }

    // MARK: Reading

    /// Looks at every record and does what `ActiveSessionSync` says: take a session started or changed elsewhere,
    /// stop one finished elsewhere, and end this device's own session when an earlier one has won.
    func reconcile() {
        guard enabled(), let container, timer != nil else { return }
        let context = ModelContext(container)
        let rows = (try? context.fetch(FetchDescriptor<ActiveSession>())) ?? []
        let now = Date()
        for row in rows where ActiveSessionSync.isStale(row.record, now: now) { context.delete(row) }
        let records = rows.filter { !ActiveSessionSync.isStale($0.record, now: now) }.map(\.record)

        switch ActiveSessionSync.action(local: timer.state, localChangedAt: timer.changedAt, records: records) {
        case .keep:
            break
        case .adopt(let state, let changedAt, let device):
            timer.applyFromCloud(state, changedAt: changedAt, startedOn: device == Self.deviceName ? nil : device)
            known = state
        case .stop(let at):
            timer.applyFromCloud(nil, changedAt: at, startedOn: nil)
            known = nil
        }

        // A session of this device that lost to an earlier start is over.
        let losers = ActiveSessionSync.losers(records).filter { $0.deviceName == Self.deviceName }
        for row in rows where row.endedAt == nil && losers.contains(where: { $0.isSameSession(as: row.record) }) {
            row.endedAt = now
            row.changedAt = now
        }
        if context.hasChanges { try? context.save() }
    }
}
