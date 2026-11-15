import Foundation
import Observation
import os

/// The craft's sessions as plain values, kept between Home's redraws.
///
/// Home redraws every second while a session runs (and every 30 s otherwise) so its numbers follow the clock.
/// Reading thousands of sessions out of the store on each of those redraws was the slow part, and it made SwiftUI
/// watch three properties of every session. This keeps the values from the last read and reads again only when
/// they can have changed:
/// - a session was added, removed or re-sorted (the query's list holds different objects), or
/// - a start, length or kind of a session that was read changed (an edit here or from iCloud), seen through
///   Observation, the same mechanism SwiftUI itself uses.
///
/// When that happens `version` changes, which SwiftUI watches, so Home redraws with the fresh values.
@MainActor
@Observable
final class SessionRecordsCache {
    /// Changes whenever the cached values were dropped; read by Home so an edit redraws it.
    private(set) var version = 0

    @ObservationIgnored private var objects: [Session] = []
    @ObservationIgnored private var cached: [SessionRecord] = []
    /// Set from any thread the moment a watched session changes.
    @ObservationIgnored private let stale = OSAllocatedUnfairLock(initialState: true)

    func records(for sessions: [Session]) -> [SessionRecord] {
        _ = version
        let changed = stale.withLock { $0 } || sessions.count != objects.count || !sessions.elementsEqual(objects, by: ===)
        guard changed else { return cached }
        stale.withLock { $0 = false }
        objects = sessions
        cached = Signposts.measure("Session records") {
            withObservationTracking {
                sessions.map(\.record)
            } onChange: { [weak self, stale] in
                stale.withLock { $0 = true }
                Task { @MainActor in self?.version &+= 1 }
            }
        }
        return cached
    }
}
