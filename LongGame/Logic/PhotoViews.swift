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

    /// A stable "random" order for photos nobody opened: it looks shuffled, but it is worked out from the year and each
    /// photo's id, so the card shows the same photos every time it is drawn until something changes.
    static func shuffled(_ candidates: [YearPhotoCandidate], year: Int) -> [UUID] {
        func key(_ id: UUID) -> UInt32 {
            var h: UInt32 = 2_166_136_261
            func mix(_ byte: UInt8) { h = (h ^ UInt32(byte)) &* 16_777_619 }
            withUnsafeBytes(of: id.uuid) { $0.forEach(mix) }
            withUnsafeBytes(of: Int32(truncatingIfNeeded: year).littleEndian) { $0.forEach(mix) }
            // One more round so neighbouring ids do not end up next to each other.
            h ^= h >> 16; h = h &* 0x45D9F3B; h ^= h >> 16
            return h
        }
        return candidates.sorted { (key($0.id), $0.id.uuidString) < (key($1.id), $1.id.uuidString) }.map(\.id)
    }

    /// The six photos for a year: the ones pinned by swapping (those that still exist) stay, then the photos that
    /// were opened (most viewed first, newer on ties), and a year nobody opened gets a random selection (see
    /// `shuffled`) for whatever is left.
    static func choose(candidates: [YearPhotoCandidate], pinned: [UUID], year: Int = 0) -> [UUID] {
        let known = Set(candidates.map(\.id))
        var result: [UUID] = []
        for id in pinned where known.contains(id) && !result.contains(id) && result.count < slots { result.append(id) }
        for id in ranked(candidates.filter { $0.viewCount > 0 }) where result.count < slots && !result.contains(id) { result.append(id) }
        for id in shuffled(candidates.filter { $0.viewCount == 0 }, year: year) where result.count < slots && !result.contains(id) {
            result.append(id)
        }
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
