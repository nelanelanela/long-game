import Foundation
import SwiftData
import WatchConnectivity

/// The iPhone's side of the conversation with the Apple Watch.
///
/// - The running timer is copied both ways whenever it changes (WatchConnectivity's latest-value context, plus a
///   direct message when the watch is in reach); the newest change wins, so there is one session at a time.
/// - The phone sends the watch its stored data (`WidgetSnapshot`), as a file, whenever it changes.
/// - A session finished on the watch arrives as a `FinishedSession`, is saved here with the same id (never twice),
///   and the data is sent back.
@MainActor
final class WatchBridge: NSObject {
    static let shared = WatchBridge()

    private var timer: TimerStore?
    private var container: ModelContainer?
    /// The data the watch has been (or is about to be) sent.
    private var lastSnapshot: WidgetSnapshot?
    private var hasSent = false

    /// Starts listening. Called once, when the app's scene appears.
    func start(timer: TimerStore, container: ModelContainer) {
        // The container is replaced when "Save to iCloud" is switched, so it is refreshed on every call.
        self.container = container
        guard WCSession.isSupported(), self.timer == nil else { return }
        self.timer = timer
        lastSnapshot = WidgetSnapshot.load()
        timer.onLocalChange = { [weak self] update in self?.send(update) }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    private var canTalk: Bool {
        WCSession.default.activationState == .activated && WCSession.default.isWatchAppInstalled
    }

    // MARK: Sending

    private func send(_ update: TimerUpdate) {
        guard canTalk else { return }
        let payload = WatchMessage.timerPayload(update)
        try? WCSession.default.updateApplicationContext(payload)
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        }
    }

    /// The stored data changed (or was just read at launch): send it if it is different from what the watch has.
    func snapshotChanged(_ snapshot: WidgetSnapshot?) {
        guard snapshot != lastSnapshot || !hasSent else { return }
        lastSnapshot = snapshot
        sendSnapshot()
    }

    private func sendSnapshot() {
        guard canTalk else { return }
        hasSent = true
        let session = WCSession.default
        // Only the latest data matters: drop older ones still waiting to be delivered.
        for transfer in session.outstandingFileTransfers where transfer.file.metadata?[WatchMessage.kindKey] as? String == WatchMessage.snapshotKind {
            transfer.cancel()
        }
        guard let snapshot = lastSnapshot, let data = snapshot.jsonData() else {
            session.transferUserInfo([WatchMessage.snapshotClearedKey: Date().timeIntervalSince1970])
            return
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("snapshot-\(UUID().uuidString).json")
        guard (try? data.write(to: url, options: .atomic)) != nil else { return }
        session.transferFile(url, metadata: [WatchMessage.kindKey: WatchMessage.snapshotKind])
    }

    // MARK: Receiving

    private func adopt(_ update: TimerUpdate?) {
        guard let update else { return }
        timer?.applyRemote(update)
    }

    /// Saves a session the watch finished, unless this phone already has it. Returns whether it was added.
    @discardableResult
    static func save(_ finished: FinishedSession, in context: ModelContext) -> Bool {
        let id = finished.id
        let already = (try? context.fetchCount(FetchDescriptor<Session>(predicate: #Predicate { $0.id == id }))) ?? 0
        guard already == 0 else { return false }
        let crafts = (try? context.fetch(FetchDescriptor<Craft>())) ?? []
        // The craft it was started for, or the active one if that has since been replaced.
        guard let craft = crafts.first(where: { $0.id == finished.craftId }) ?? crafts.first(where: \.isActive) else { return false }
        let session = Session(craftId: craft.id, start: finished.start, durationSec: finished.durationSec,
                              source: finished.isManual == true ? .manual : .timer)
        session.id = finished.id
        context.insert(session)
        try? context.save()
        return true
    }

    /// Undo on the watch: removes the session it added, if this phone already saved it. Returns whether it did.
    @discardableResult
    static func remove(_ id: UUID, in context: ModelContext) -> Bool {
        let found = (try? context.fetch(FetchDescriptor<Session>(predicate: #Predicate { $0.id == id }))) ?? []
        guard !found.isEmpty else { return false }
        for session in found { context.delete(session) }
        try? context.save()
        return true
    }

    private func receiveRemoval(_ id: UUID) {
        guard let container else { return }
        guard Self.remove(id, in: container.mainContext) else { return }
        republish(container.mainContext)
    }

    private func receive(_ finished: FinishedSession) {
        guard let container else { return }
        let context = container.mainContext
        guard Self.save(finished, in: context) else { return }
        republish(context)
    }

    private func republish(_ context: ModelContext) {
        // The app may not be on screen (the watch can wake it in the background), so don't wait for the views.
        let crafts = (try? context.fetch(FetchDescriptor<Craft>())) ?? []
        let sessions = (try? context.fetch(FetchDescriptor<Session>())) ?? []
        let estimates = (try? context.fetch(FetchDescriptor<YearEstimate>())) ?? []
        let settings = (try? context.fetch(FetchDescriptor<AppSettings>()))?.first
        WidgetBridge.publish(WidgetBridge.snapshot(crafts: crafts, sessions: sessions, estimates: estimates, settings: settings))
    }
}

extension WatchBridge: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        guard activationState == .activated else { return }
        // Decoded here, in the callback, so only plain values cross to the main actor.
        let update = WatchMessage.timerUpdate(from: session.receivedApplicationContext)
        Task { @MainActor in
            self.adopt(update)
            self.hasSent = false
            self.sendSnapshot()
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // After switching to another watch: take up the new one.
        session.activate()
    }

    /// The watch app was installed, or the paired watch changed: it needs the data.
    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.hasSent = false
            self.sendSnapshot()
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        let update = WatchMessage.timerUpdate(from: applicationContext)
        Task { @MainActor in self.adopt(update) }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        let update = WatchMessage.timerUpdate(from: message)
        Task { @MainActor in self.adopt(update) }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        if let removed = WatchMessage.removedSession(from: userInfo) {
            Task { @MainActor in self.receiveRemoval(removed) }
            return
        }
        guard let finished = WatchMessage.finishedSession(from: userInfo) else { return }
        Task { @MainActor in self.receive(finished) }
    }
}
