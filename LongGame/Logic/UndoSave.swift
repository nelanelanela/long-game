import Foundation

/// The Undo inside Home's "40 m added" toast: which sessions a save created, and whether Undo is offered at all.
enum UndoSave {
    /// How long the toast with Undo stays (with VoiceOver it waits until focus moves away instead).
    static let showFor: TimeInterval = 6
    /// How long "Removed." stays after Undo.
    static let removedFor: TimeInterval = 2

    /// The ids a save created: the sessions there now that weren't there before. Nil when there is nothing to undo,
    /// or when the save opened a milestone celebration (the session can still be edited in History).
    static func offer(before: Set<UUID>, after: [UUID], celebrates: Bool) -> [UUID]? {
        guard !celebrates else { return nil }
        let created = after.filter { !before.contains($0) }
        return created.isEmpty ? nil : created
    }

    /// The sessions Undo deletes: exactly those the save created, nothing else.
    static func toRemove<T>(_ sessions: [T], id: (T) -> UUID, offered: [UUID]) -> [T] {
        let ids = Set(offered)
        return sessions.filter { ids.contains(id($0)) }
    }
}
