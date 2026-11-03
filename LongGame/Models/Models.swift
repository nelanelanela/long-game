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
    case timer, manual, catchUp
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

    var record: SessionRecord { SessionRecord(start: start, durationSec: durationSec, isCatchUp: source == .catchUp) }
}

/// The spec's "Settings" entity. Named AppSettings to avoid clashing with SwiftUI.
@Model
final class AppSettings {
    var weekStartRaw: String = WeekStart.localeDefault.rawValue
    var reminderTime: Date?
    var reminderDays: [Int] = [1, 2, 3, 4, 5, 6, 7]
    var syncEnabled: Bool = false
    /// A gentle 7 pm nudge on days the user usually practises (was the streak reminder).
    @Attribute(originalName: "streakReminder") var rhythmNudge: Bool = false
    var milestonesSeen: [Int] = []
    /// When Welcome back was last offered; it is asked at most once every 7 days.
    var lastCatchUpPromptAt: Date?
    /// "Meet your future self" opens once on its own, the first time Home appears after onboarding.
    var futureSelfShown: Bool = false
    /// Tips unlock nothing; these only decide whether to say thank you and when to stop asking.
    var lastTipAt: Date?
    var tipCount: Int = 0
    /// When the gentle "Support Long Game" button last appeared after a celebration.
    var lastTipOfferAt: Date?
    /// Your pace for the year: hours a week for the 12 months from `targetSetAt`. 0 means none chosen yet
    /// (a game started before this existed); the earlier ones live on as `TargetPeriod` rows.
    var weeklyTargetHours: Double = 0
    var targetSetAt: Date?
    var targetEndsAt: Date?
    /// When the target screen last opened on its own as a sheet (a new year of pace, or the first one for an
    /// older game), so it asks once and then only leaves the reminder in the target row.
    var targetPromptShownAt: Date?
    /// The tab Home opens on next: This week, except right after onboarding (The long game, once).
    var lastHomeTabRaw: String = HomeTab.week.rawValue

    init() {}

    var weekStart: WeekStart {
        get { WeekStart(rawValue: weekStartRaw) ?? .monday }
        set { weekStartRaw = newValue.rawValue }
    }

    var lastHomeTab: HomeTab {
        get { HomeTab(rawValue: lastHomeTabRaw) ?? .week }
        set { lastHomeTabRaw = newValue.rawValue }
    }

    /// The current target as plain values for the Logic code; nil until one has been chosen.
    var currentTarget: TargetRecord? {
        guard weeklyTargetHours > 0, let start = targetSetAt, let end = targetEndsAt else { return nil }
        return TargetRecord(hoursPerWeek: weeklyTargetHours, start: start, end: end)
    }
}

/// A finished year of pace. The current one is kept on `AppSettings`; when a new one replaces it, it moves here,
/// so past weeks are judged against the target that applied then.
@Model
final class TargetPeriod {
    var hoursPerWeek: Double = 0
    var start: Date = Date()
    var end: Date = Date()

    init(hoursPerWeek: Double, start: Date, end: Date) {
        self.hoursPerWeek = hoursPerWeek
        self.start = start
        self.end = end
    }

    var record: TargetRecord { TargetRecord(hoursPerWeek: hoursPerWeek, start: start, end: end) }
}
