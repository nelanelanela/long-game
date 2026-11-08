import Foundation
import SwiftData

/// Reading and removing the photos people added to their sessions. The default pictures are never involved: they take
/// no space of their own and are drawn again whenever needed.
@MainActor
enum PhotoLibrary {
    /// Every photo's size, read in the background so Settings never waits for it.
    static func loadStats(container: ModelContainer) async -> [PhotoStat] {
        await Task.detached(priority: .utility) {
            let context = ModelContext(container)
            let rows = (try? context.fetch(FetchDescriptor<Session>(predicate: #Predicate { $0.hasPhoto }))) ?? []
            return rows.map { PhotoStat(id: $0.id, start: $0.start, bytes: $0.photo?.count ?? 0) }
        }.value
    }

    /// Takes the photos off every session that started in `year`, with their view counts. The sessions, their hours,
    /// notes and everything else stay. Returns how many photos went and how many bytes that frees.
    @discardableResult
    static func removePhotos(inYear year: Int, from sessions: [Session], calendar: Calendar = .current) -> (removed: Int, bytes: Int) {
        var removed = 0, bytes = 0
        for session in sessions where session.hasPhoto && calendar.component(.year, from: session.start) == year {
            bytes += session.photo?.count ?? 0
            session.setPhoto(nil)
            removed += 1
        }
        return (removed, bytes)
    }
}
