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
        /// The session's id, so a session saved on the watch is not counted twice once the phone has it too.
        var id: UUID?
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
    /// The active craft's id, so the watch can start a session for it.
    var craftId: UUID?

    /// Shared by the app and the widget extension (both list it in their entitlements).
    static let groupID = "group.com.wehavesun.LongGame"
    static let defaultFileName = "widget-data.json"

    static func fileURL(_ fileName: String = defaultFileName) -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)?.appendingPathComponent(fileName)
    }

    func jsonData() -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return try? encoder.encode(self)
    }

    static func from(jsonData data: Data) -> WidgetSnapshot? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try? decoder.decode(WidgetSnapshot.self, from: data)
    }

    /// Nil when the app has not been set up yet, or the group is not available.
    static func load(_ fileName: String = defaultFileName) -> WidgetSnapshot? {
        guard let url = fileURL(fileName), let data = try? Data(contentsOf: url) else { return nil }
        return from(jsonData: data)
    }

    /// Writes the snapshot, or removes it when there is none (no craft yet). Returns false when nothing changed.
    @discardableResult
    static func store(_ snapshot: WidgetSnapshot?, fileName: String = defaultFileName) -> Bool {
        guard let url = fileURL(fileName) else { return false }
        guard let snapshot else {
            let existed = FileManager.default.fileExists(atPath: url.path)
            try? FileManager.default.removeItem(at: url)
            return existed
        }
        if load(fileName) == snapshot { return false }
        guard let data = snapshot.jsonData() else { return false }
        return (try? data.write(to: url, options: .atomic)) != nil
    }
}
