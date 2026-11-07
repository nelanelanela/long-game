import Foundation
import Observation

/// Owns the one running session. All state is timestamps in UserDefaults, so
/// it survives the app being closed; the screen only ever derives from it.
@MainActor
@Observable
final class TimerStore {
    private(set) var state: TimerState?
    /// A Live Activity "Finish" tap asked the timer screen to open its finish sheet.
    var finishRequested = false
    /// Set when a session was just saved, so Home can count its total up.
    var savedSession = false
    /// When the running timer (or its absence) last changed here or on the watch; the newest change wins.
    private(set) var changedAt: Date

    /// Told after every change made on this device, so the watch can follow.
    @ObservationIgnored var onLocalChange: ((TimerUpdate) -> Void)?
    /// Told after every change made here or on the watch, so the running session can be kept in iCloud.
    @ObservationIgnored var onSyncChange: ((TimerUpdate) -> Void)?
    /// The device the running session was started on, when that is not this one (shown under the clock).
    var startedOn: String?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    private static let changedAtKey = "timer.changedAt.v1"

    init() {
        changedAt = Date(timeIntervalSince1970: UserDefaults.standard.double(forKey: Self.changedAtKey))
        state = TimerPersistence.load()
        state?.normalize(at: Date())
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: .timerChangedExternally, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.reloadFromDisk() }
        })
        observers.append(center.addObserver(forName: .timerFinishRequested, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.reloadFromDisk()
                self?.finishRequested = true
            }
        })
        refreshSurfaces()
    }

    var isActive: Bool { state != nil }

    func start(craft: Craft, now: Date = Date()) {
        guard state == nil else { return }
        startedOn = nil
        state = TimerState(craftId: craft.id, craftName: craft.name, startedAt: now)
        commit()
        FocusMode.shared.runShortcut(starting: true)
        // Milestone and "still practising?" alerts need permission, so ask the first time a session starts.
        Task { if await Notifications.requestIfNeeded() { refreshSurfaces() } }
    }

    func pause(now: Date = Date()) {
        state?.pause(at: now)
        commit()
    }

    func resume(now: Date = Date()) {
        state?.resume(at: now)
        commit()
    }

    func togglePause(now: Date = Date()) {
        guard let s = state else { return }
        s.isPaused(at: now) ? resume(now: now) : pause(now: now)
    }

    /// Ends the session (saved or discarded).
    func clear() {
        let wasActive = state != nil
        state = nil
        startedOn = nil
        commit()
        if wasActive { FocusMode.shared.runShortcut(starting: false) }
    }

    /// Re-reads the clock after the app comes back to the foreground.
    func refresh(now: Date = Date()) {
        state?.normalize(at: now)
        commit()
    }

    private func reloadFromDisk() {
        state = TimerPersistence.load()
        state?.normalize(at: Date())
        refreshSurfaces()
    }

    /// The watch started, paused, resumed or finished the session. Only a newer change is taken, and it is not sent
    /// straight back.
    func applyRemote(_ update: TimerUpdate) {
        guard update.supersedes(changedAt) else { return }
        onSyncChange?(update)
        state = update.state
        state?.normalize(at: Date())
        changedAt = update.changedAt
        UserDefaults.standard.set(changedAt.timeIntervalSince1970, forKey: Self.changedAtKey)
        TimerPersistence.save(state)
        refreshSurfaces()
    }

    /// Another device (through iCloud) started, paused, resumed or finished the session. The watch is told; iCloud is not.
    func applyFromCloud(_ state: TimerState?, changedAt: Date, startedOn device: String?) {
        self.state = state
        self.state?.normalize(at: Date())
        self.startedOn = state == nil ? nil : device
        self.changedAt = max(changedAt, self.changedAt)
        UserDefaults.standard.set(self.changedAt.timeIntervalSince1970, forKey: Self.changedAtKey)
        TimerPersistence.save(self.state)
        refreshSurfaces()
        onLocalChange?(TimerUpdate(state: self.state, changedAt: self.changedAt))
    }

    private func commit() {
        TimerPersistence.save(state)
        changedAt = Date()
        UserDefaults.standard.set(changedAt.timeIntervalSince1970, forKey: Self.changedAtKey)
        refreshSurfaces()
        let update = TimerUpdate(state: state, changedAt: changedAt)
        onLocalChange?(update)
        onSyncChange?(update)
    }

    private func refreshSurfaces() {
        let now = Date()
        Notifications.scheduleLongSession(at: state?.longSessionDate(at: now))
        #if os(iOS)
        LiveActivityManager.sync(state, now: now)
        #endif
        // Mutes the chosen apps while a session exists, and lets them go the moment it ends, wherever it ended.
        FocusMode.shared.sync(sessionActive: state != nil)
    }
}
