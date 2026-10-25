import Foundation
import SwiftData

// All properties have defaults and nothing is marked unique, so the store can
// be mirrored by CloudKit later without a migration.

@Model
final class Craft {
    var id: UUID = UUID()
    var name: String = ""
    var category: String = ""
    var startYear: Int = 2020
    /// The onboarding date: estimates cover everything before this day.
    var createdAt: Date = Date()
    var archivedAt: Date?

    init(name: String, category: String = "", startYear: Int, createdAt: Date = Date()) {
        self.name = name
        self.category = category
        self.startYear = startYear
        self.createdAt = createdAt
    }

    var isActive: Bool { archivedAt == nil }
}

@Model
final class YearEstimate {
    var craftId: UUID = UUID()
    var year: Int = 2020
    var hoursPerWeek: Int = 5

    init(craftId: UUID, year: Int, hoursPerWeek: Int) {
        self.craftId = craftId
        self.year = year
        self.hoursPerWeek = hoursPerWeek
    }

    var rate: YearRate { YearRate(year: year, hoursPerWeek: Double(hoursPerWeek)) }
}

enum SessionSource: String, Codable, Sendable {
    case timer, manual
}

@Model
final class Session {
    var id: UUID = UUID()
    var craftId: UUID = UUID()
    var start: Date = Date()
    var end: Date = Date()
    var durationSec: Double = 0
    var sourceRaw: String = SessionSource.manual.rawValue
    var note: String?
    var createdAt: Date = Date()
    var editedAt: Date?

    init(craftId: UUID, start: Date, durationSec: Double, source: SessionSource, note: String? = nil) {
        self.craftId = craftId
        self.start = start
        self.end = start.addingTimeInterval(durationSec)
        self.durationSec = durationSec
        self.sourceRaw = source.rawValue
        self.note = note
    }

    var source: SessionSource {
        get { SessionSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    var record: SessionRecord { SessionRecord(start: start, durationSec: durationSec) }
}

/// The spec's "Settings" entity. Named AppSettings to avoid clashing with SwiftUI.
@Model
final class AppSettings {
    var weekStartRaw: String = WeekStart.localeDefault.rawValue
    var reminderTime: Date?
    var reminderDays: [Int] = [1, 2, 3, 4, 5, 6, 7]
    var syncEnabled: Bool = false
    var streakReminder: Bool = false
    var milestonesSeen: [Int] = []

    init() {}

    var weekStart: WeekStart {
        get { WeekStart(rawValue: weekStartRaw) ?? .monday }
        set { weekStartRaw = newValue.rawValue }
    }
}
