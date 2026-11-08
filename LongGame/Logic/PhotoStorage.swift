import Foundation

// What the photos take up, for Settings › iCloud & storage › Your photos (update prompt 32, part 11). Pure numbers, so
// the grouping and the wording can be tested. The sizes come from the stored photo data and are worked out off the
// main thread.

/// One photo's size, with the session it belongs to.
struct PhotoStat: Equatable, Sendable {
    var id: UUID
    var start: Date
    var bytes: Int
}

struct PhotoYearGroup: Equatable, Identifiable, Sendable {
    var year: Int
    var count: Int
    var bytes: Int
    /// The newest photos first, as many as the card shows thumbnails for.
    var newest: [UUID]
    var id: Int { year }
}

enum PhotoStorage {
    /// How many thumbnails a year card shows (the last one carries the "+N").
    static let thumbnails = 5

    /// One group per year, newest year first.
    static func groups(_ photos: [PhotoStat], calendar: Calendar = .current) -> [PhotoYearGroup] {
        let byYear = Dictionary(grouping: photos) { calendar.component(.year, from: $0.start) }
        return byYear.map { year, items in
            let newest = items.sorted { $0.start > $1.start }.prefix(thumbnails).map(\.id)
            return PhotoYearGroup(year: year, count: items.count, bytes: items.reduce(0) { $0 + $1.bytes }, newest: Array(newest))
        }
        .sorted { $0.year > $1.year }
    }

    static func totalBytes(_ photos: [PhotoStat]) -> Int { photos.reduce(0) { $0 + $1.bytes } }

    /// The "+N" on the last thumbnail: the photos the card does not show. Nil when every photo has a tile.
    static func moreCount(_ group: PhotoYearGroup) -> Int? {
        group.count > thumbnails ? group.count - (thumbnails - 1) : nil
    }
}

enum ByteText {
    /// "486 MB", "3.1 MB", "254 KB". Decimal units, as the system shows them.
    static func size(_ bytes: Int) -> String {
        guard bytes > 0 else { return "0 KB" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.includesUnit = true
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

extension YearCardPins {
    /// The pins with one year taken out, as text (used when that year's photos are deleted).
    static func removing(year: Int, from raw: String) -> String {
        var pins = decode(raw)
        pins[year] = nil
        return encode(pins)
    }
}
