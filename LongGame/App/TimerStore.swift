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

    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    init() {
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
        state = TimerState(craftId: craft.id, craftName: craft.name, startedAt: now)
        commit()
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
        state = nil
        commit()
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

    private func commit() {
        TimerPersistence.save(state)
        refreshSurfaces()
    }

    private func refreshSurfaces() {
        let now = Date()
        Notifications.scheduleLongSession(at: state?.longSessionDate(at: now))
        LiveActivityManager.sync(state, now: now)
    }
}
