import Foundation

/// The saved data the widgets need, mirrored by the app into the shared App Group so the widget extension can read
/// it. It holds only what is stored (the craft, the yearly estimates, every session's start and length, the week
/// start and the weekly target), never totals: the widgets work those out with the same Logic code as the app.
struct WidgetSnapshot: Codable, Equatable, Sendable {
    struct Estimate: Codable, Equatable, Sendable {
        var year: Int
        var hoursPerWeek: Double
    }

    struct Entry: Codable, Equatable, Sendable {
        var start: Date
        var seconds: Double
    }

    struct Target: Codable, Equatable, Sendable {
        var hoursPerWeek: Double
        var start: Date
        var end: Date
    }

    var craftName: String
    /// The onboarding date: estimates cover everything before this day.
    var onboardingDate: Date
    var estimates: [Estimate]
    var sessions: [Entry]
    /// `WeekStart` raw value.
    var weekStart: String
    var target: Target?

    /// Shared by the app and the widget extension (both list it in their entitlements).
    static let groupID = "group.com.wehavesun.LongGame"
    private static let fileName = "widget-data.json"

    static var fileURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)?.appendingPathComponent(fileName)
    }

    /// Nil when the app has not been set up yet, or the group is not available.
    static func load() -> WidgetSnapshot? {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try? decoder.decode(WidgetSnapshot.self, from: data)
    }

    /// Writes the snapshot, or removes it when there is none (no craft yet). Returns false when nothing changed.
    @discardableResult
    static func store(_ snapshot: WidgetSnapshot?) -> Bool {
        guard let url = fileURL else { return false }
        guard let snapshot else {
            let existed = FileManager.default.fileExists(atPath: url.path)
            try? FileManager.default.removeItem(at: url)
            return existed
        }
        if load() == snapshot { return false }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        guard let data = try? encoder.encode(snapshot) else { return false }
        return (try? data.write(to: url, options: .atomic)) != nil
    }
}
