import Foundation

// One running session on every device. The session that is running is a small record kept in iCloud (the same store
// as the rest of the game): when it started, whether it is paused, how long it was paused, and which device began it.
// Each device keeps its own timer from these timestamps; this file only decides which record is "the" session and what
// a device should do about it. Pure functions, so every rule can be tested.

/// The synced copy of the running timer.
struct ActiveSessionRecord: Equatable, Codable, Sendable, Identifiable {
    var id: UUID
    var craftId: UUID
    var craftName: String
    var startedAt: Date
    var pausedAt: Date?
    var accumulatedPause: TimeInterval
    var deviceName: String
    /// When this record last changed on any device; the newest change wins.
    var changedAt: Date
    /// Set when the session was finished or discarded on any device. The record then only says "this one is over".
    var endedAt: Date?

    init(id: UUID = UUID(), state: TimerState, deviceName: String, changedAt: Date, endedAt: Date? = nil) {
        self.id = id
        craftId = state.craftId
        craftName = state.craftName
        startedAt = state.startedAt
        pausedAt = state.pausedAt
        accumulatedPause = state.accumulatedPause
        self.deviceName = deviceName
        self.changedAt = changedAt
        self.endedAt = endedAt
    }

    var isLive: Bool { endedAt == nil }

    var timerState: TimerState {
        TimerState(craftId: craftId, craftName: craftName, startedAt: startedAt, pausedAt: pausedAt, accumulatedPause: accumulatedPause)
    }

    /// The same session, whichever device wrote the record: it began at the same moment on the same craft.
    func isSameSession(as other: ActiveSessionRecord) -> Bool {
        craftId == other.craftId && abs(startedAt.timeIntervalSince(other.startedAt)) < 0.001
    }

    func isSameSession(as state: TimerState) -> Bool {
        craftId == state.craftId && abs(startedAt.timeIntervalSince(state.startedAt)) < 0.001
    }

    /// Whether `a` starts before `b`. A tie (two devices at the very same moment) goes to the smaller id, so every
    /// device picks the same one.
    static func starts(_ a: ActiveSessionRecord, before b: ActiveSessionRecord) -> Bool {
        if a.startedAt != b.startedAt { return a.startedAt < b.startedAt }
        return a.id.uuidString < b.id.uuidString
    }
}

/// What a device should do with its own timer.
enum ActiveSessionAction: Equatable, Sendable {
    /// Nothing to change.
    case keep
    /// Take this state (a session started, paused or resumed elsewhere), as changed at `changedAt`.
    case adopt(TimerState, changedAt: Date, startedOn: String)
    /// The session was finished or discarded on another device: stop the timer here without saving anything.
    case stop(at: Date)
}

enum ActiveSessionSync {
    /// Several records of the same session (one per device that wrote it) become one: the newest change wins, and a
    /// finished session stays finished.
    static func merge(_ records: [ActiveSessionRecord]) -> [ActiveSessionRecord] {
        var merged: [ActiveSessionRecord] = []
        for record in records {
            if let at = merged.firstIndex(where: { $0.isSameSession(as: record) }) {
                let old = merged[at]
                var winner = record.changedAt >= old.changedAt ? record : old
                // The first record of a session keeps its id and the device that began it.
                if let ended = old.endedAt ?? record.endedAt { winner.endedAt = ended }
                merged[at] = winner
            } else {
                merged.append(record)
            }
        }
        return merged
    }

    /// The session that counts: of all the sessions still running, the one that started first.
    static func winner(_ records: [ActiveSessionRecord]) -> ActiveSessionRecord? {
        merge(records).filter(\.isLive).min { ActiveSessionRecord.starts($0, before: $1) }
    }

    /// Sessions that began later than the winner while it was running. They lose and are ended.
    static func losers(_ records: [ActiveSessionRecord]) -> [ActiveSessionRecord] {
        guard let winner = winner(records) else { return [] }
        return merge(records).filter { $0.isLive && !$0.isSameSession(as: winner) }
    }

    /// What this device does with its timer, given what it has (`local`, last changed at `localChangedAt`) and every
    /// record that is in iCloud.
    static func action(local: TimerState?, localChangedAt: Date, records: [ActiveSessionRecord]) -> ActiveSessionAction {
        let all = merge(records)
        let winner = winner(records)

        guard let local else {
            // Nothing runs here: pick up the session that is running elsewhere.
            if let winner { return .adopt(winner.timerState, changedAt: winner.changedAt, startedOn: winner.deviceName) }
            return .keep
        }

        if let winner, !winner.isSameSession(as: local) {
            // Another session began earlier: it wins, and this one gives way to it.
            if winner.startedAt < local.startedAt {
                return .adopt(winner.timerState, changedAt: winner.changedAt, startedOn: winner.deviceName)
            }
            return .keep
        }

        guard let mine = all.first(where: { $0.isSameSession(as: local) }) else { return .keep }   // not shared yet
        if let ended = mine.endedAt { return .stop(at: ended) }
        // The same session: a newer pause, resume or other change on another device is taken.
        if mine.changedAt > localChangedAt, mine.timerState != local {
            return .adopt(mine.timerState, changedAt: mine.changedAt, startedOn: mine.deviceName)
        }
        return .keep
    }

    /// Finished records are only needed long enough for every device to hear about them.
    static let endedKeptFor: TimeInterval = 24 * 3600

    static func isStale(_ record: ActiveSessionRecord, now: Date) -> Bool {
        guard let ended = record.endedAt else { return false }
        return now.timeIntervalSince(ended) > endedKeptFor
    }
}

/// "Started on Natalia's Mac" under the clock, when the running session began on another device.
enum ActiveSessionText {
    static func startedOn(_ device: String) -> String { String(localized: "Started on \(device)") }
}
