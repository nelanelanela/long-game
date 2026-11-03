import Foundation
import WatchConnectivity

/// The watch's side of the conversation with the iPhone (see `WatchBridge` on the phone).
final class WatchConnection: NSObject, WCSessionDelegate, @unchecked Sendable {
    /// Set once by the store, on the main actor, before the session starts.
    @MainActor weak var store: WatchStore?

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // MARK: Sending

    @MainActor
    func send(_ update: TimerUpdate) {
        guard WCSession.default.activationState == .activated else { return }
        let payload = WatchMessage.timerPayload(update)
        try? WCSession.default.updateApplicationContext(payload)
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        }
    }

    /// Queued by the system, so it still arrives when the phone is out of reach at the moment.
    @MainActor
    func send(_ session: FinishedSession) {
        guard WCSession.isSupported() else { return }
        WCSession.default.transferUserInfo(WatchMessage.sessionPayload(session))
    }

    // MARK: Receiving

    // The timer's update is decoded here, in the callback, so only a plain value crosses to the main actor.

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        guard activationState == .activated else { return }
        adopt(WatchMessage.timerUpdate(from: session.receivedApplicationContext))
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        adopt(WatchMessage.timerUpdate(from: applicationContext))
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        adopt(WatchMessage.timerUpdate(from: message))
    }

    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        guard file.metadata?[WatchMessage.kindKey] as? String == WatchMessage.snapshotKind,
              let data = try? Data(contentsOf: file.fileURL), let snapshot = WidgetSnapshot.from(jsonData: data) else { return }
        Task { @MainActor in self.store?.receive(snapshot) }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard userInfo[WatchMessage.snapshotClearedKey] != nil else { return }
        Task { @MainActor in self.store?.receive(nil) }
    }

    private func adopt(_ update: TimerUpdate?) {
        guard let update else { return }
        Task { @MainActor in self.store?.apply(update) }
    }
}
