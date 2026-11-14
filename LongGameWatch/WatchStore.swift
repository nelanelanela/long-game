import Foundation
import Observation
import WidgetKit

/// Everything the watch app knows: the phone's stored data, the sessions finished here that the phone hasn't
/// confirmed yet, and the running timer (copied to and from the phone, newest change wins).
@MainActor
@Observable
final class WatchStore {
    /// What the phone last sent. Nil until the phone app has been set up.
    private(set) var received: WidgetSnapshot?
    private(set) var pending: [FinishedSession]
    private(set) var timer: TimerState?
    private(set) var timerChangedAt: Date
    /// The session just finished here, while the Finished screen is up.
    var finished: FinishedSession?
    /// Hours just added with Add time, while "30 m added" with Undo shows (6 seconds).
    var justAdded: FinishedSession?
    /// "Removed." after Undo, for 2 seconds.
    var showsRemoved = false

    @ObservationIgnored private let connection = WatchConnection()
    private static let receivedFile = "watch-received.json"
    private static let timerKey = "timer.state.v1"
    private static let changedAtKey = "timer.changedAt.v1"

    init() {
        received = WidgetSnapshot.load(Self.receivedFile)
        pending = PendingSessions.load()
        timerChangedAt = Date(timeIntervalSince1970: UserDefaults.standard.double(forKey: Self.changedAtKey))
        if let data = UserDefaults.standard.data(forKey: Self.timerKey) {
            timer = try? JSONDecoder().decode(TimerState.self, from: data)
        }
        timer?.normalize(at: Date())
        connection.store = self
        connection.activate()
        publishForComplications()
    }

    // MARK: What to show

    /// Nil until the phone has sent its data: the watch then asks for the phone to be set up first.
    func homeState(now: Date = Date()) -> WatchHomeState? {
        guard let received else { return nil }
        return WatchModel.state(snapshot: received, pending: outstanding(now), now: now)
    }

    private func outstanding(_ now: Date) -> [FinishedSession] {
        PendingSessions.outstanding(pending, snapshot: received, now: now)
    }

    // MARK: The timer

    func start(now: Date = Date()) {
        guard timer == nil, let craftId = received?.craftId, let name = received?.craftName else { return }
        timer = TimerState(craftId: craftId, craftName: name, startedAt: now)
        commitTimer(now)
    }

    func pauseOrResume(now: Date = Date()) {
        guard var state = timer else { return }
        state.isPaused(at: now) ? state.resume(at: now) : state.pause(at: now)
        timer = state
        commitTimer(now)
    }

    /// Ends the session. A minute or more is saved: kept here until the phone has it, and sent to the phone.
    func finish(now: Date = Date()) {
        guard var state = timer else { return }
        state.normalize(at: now)
        let elapsed = state.elapsed(at: now)
        timer = nil
        commitTimer(now)
        guard FinishRules.canSave(elapsed: elapsed) else { return }
        let session = FinishedSession(id: UUID(), craftId: state.craftId, start: state.startedAt, durationSec: elapsed.rounded())
        pending.append(session)
        PendingSessions.store(pending)
        connection.send(session)
        finished = session
        publishForComplications()
    }

    // MARK: Add time

    /// What is already counted for today (the phone's data plus what is still on its way).
    func todaySeconds(now: Date = Date()) -> TimeInterval { homeState(now: now)?.widget.todaySeconds ?? 0 }

    /// Hours added for today (manual, at noon like the phone's Add past hours), sent to the phone through the same
    /// queue as a session finished here, with its own id so it is never saved twice.
    func addTime(_ seconds: TimeInterval, now: Date = Date()) {
        guard let craftId = received?.craftId, seconds > 0,
              WatchAddTime.canAdd(seconds, todaySeconds: todaySeconds(now: now)) else { return }
        let session = FinishedSession(id: UUID(), craftId: craftId, start: SessionRules.manualStart(on: now),
                                      durationSec: seconds, isManual: true)
        pending.append(session)
        PendingSessions.store(pending)
        connection.send(session)
        publishForComplications()
        showsRemoved = false
        justAdded = session
        Task {
            try? await Task.sleep(for: .seconds(UndoSave.showFor))
            if justAdded?.id == session.id { justAdded = nil }
        }
    }

    /// Undo: removes what Add time just added, here and on the phone.
    func undoAdd() {
        guard let session = justAdded else { return }
        justAdded = nil
        pending.removeAll { $0.id == session.id }
        PendingSessions.store(pending)
        connection.remove(session.id)
        publishForComplications()
        showsRemoved = true
        Task {
            try? await Task.sleep(for: .seconds(UndoSave.removedFor))
            showsRemoved = false
        }
    }

    private func commitTimer(_ now: Date) {
        persistTimer()
        timerChangedAt = now
        UserDefaults.standard.set(now.timeIntervalSince1970, forKey: Self.changedAtKey)
        connection.send(TimerUpdate(state: timer, changedAt: now))
    }

    private func persistTimer() {
        if let timer, let data = try? JSONEncoder().encode(timer) {
            UserDefaults.standard.set(data, forKey: Self.timerKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.timerKey)
        }
    }

    // MARK: From the phone

    func apply(_ update: TimerUpdate) {
        guard update.supersedes(timerChangedAt) else { return }
        timer = update.state
        timer?.normalize(at: Date())
        timerChangedAt = update.changedAt
        UserDefaults.standard.set(timerChangedAt.timeIntervalSince1970, forKey: Self.changedAtKey)
        persistTimer()
    }

    /// The phone's stored data changed (nil: the phone has no craft now).
    func receive(_ snapshot: WidgetSnapshot?) {
        received = snapshot
        WidgetSnapshot.store(snapshot, fileName: Self.receivedFile)
        // What the phone now holds no longer needs to be kept here.
        pending = outstanding(Date())
        PendingSessions.store(pending)
        publishForComplications()
    }

    /// The complications read the phone's data with the pending sessions added, from the shared folder.
    private func publishForComplications() {
        let merged = received.map { WatchModel.merged($0, pending: outstanding(Date())) }
        if WidgetSnapshot.store(merged) {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
