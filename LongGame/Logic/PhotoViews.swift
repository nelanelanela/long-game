import Foundation

// Which photos the Photos year card shows (update prompt 32, part 10). A photo's views are counted quietly: opening it
// in the photo viewer counts once it has been on screen for a second, at most once an hour. The count is never shown,
// and goes away with the photo.

enum PhotoViews {
    /// How long a photo must be on screen before the open counts.
    static let dwell: TimeInterval = 1
    /// A photo counts at most once in this time.
    static let cooldown: TimeInterval = 3600

    static func shouldCount(lastCountedAt: Date?, now: Date) -> Bool {
        guard let lastCountedAt else { return true }
        return now.timeIntervalSince(lastCountedAt) >= cooldown
    }
}

struct YearPhotoCandidate: Equatable, Sendable {
    var id: UUID
    var start: Date
    var viewCount: Int
}

enum YearPhotoChoice {
    /// The Photos card has six tiles.
    static let slots = 6

    /// Most viewed first; photos with the same count, newer first.
    static func ranked(_ candidates: [YearPhotoCandidate]) -> [UUID] {
        candidates.sorted {
            if $0.viewCount != $1.viewCount { return $0.viewCount > $1.viewCount }
            if $0.start != $1.start { return $0.start > $1.start }
            return $0.id.uuidString < $1.id.uuidString
        }.map(\.id)
    }

    /// The six photos for a year: the ones pinned by swapping (those that still exist) stay, and the rest are filled
    /// from the most viewed (newer first on ties, so a year nobody opened shows its most recent photos).
    static func choose(candidates: [YearPhotoCandidate], pinned: [UUID]) -> [UUID] {
        let known = Set(candidates.map(\.id))
        var result: [UUID] = []
        for id in pinned where known.contains(id) && !result.contains(id) && result.count < slots { result.append(id) }
        for id in ranked(candidates) where result.count < slots && !result.contains(id) { result.append(id) }
        return result
    }
}

/// The photos pinned for each year, kept as one small piece of text in the settings.
enum YearCardPins {
    static func decode(_ raw: String) -> [Int: [UUID]] {
        guard let data = raw.data(using: .utf8),
              let stored = try? JSONDecoder().decode([String: [String]].self, from: data) else { return [:] }
        var result: [Int: [UUID]] = [:]
        for (year, ids) in stored {
            if let y = Int(year) { result[y] = ids.compactMap(UUID.init(uuidString:)) }
        }
        return result
    }

    static func encode(_ pins: [Int: [UUID]]) -> String {
        let stored = Dictionary(uniqueKeysWithValues: pins.map { (String($0.key), $0.value.map(\.uuidString)) })
        guard let data = try? JSONEncoder().encode(stored) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }
}
