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
        self.hoursPerWeek = Self.clamped(hoursPerWeek)
    }

    /// 0 to 168: every hour of a week.
    static func clamped(_ hours: Int) -> Int { min(Int(WeeklyTarget.maxHours), max(0, hours)) }

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
    /// One optional photo of what was made: JPEG, longest side 2048 px, no metadata (see `PhotoProcessing`). Kept in
    /// its own file by SwiftData so the database stays small, and deleted with the session. Adding it needs no
    /// migration: an optional attribute is added to existing stores automatically.
    @Attribute(.externalStorage) var photo: Data?
    /// Whether there is a photo, so lists and the calendar can tell without loading the image.
    /// Always set through `setPhoto(_:)`.
    var hasPhoto: Bool = false
    var createdAt: Date = Date()
    var editedAt: Date?
    /// Where today's sunrise stood when this session ended (0 = on the horizon, 1 = fully up): the one number the
    /// session picture needs besides the session itself. Optional so existing stores migrate on their own; sessions
    /// without it are filled in from the day's order of sessions (`SessionPictures.fillMissing`).
    var sunriseProgressAtEnd: Double?

    init(craftId: UUID, start: Date, durationSec: Double, source: SessionSource, note: String? = nil, photo: Data? = nil) {
        self.craftId = craftId
        self.start = start
        self.end = start.addingTimeInterval(durationSec)
        self.durationSec = durationSec
        self.sourceRaw = source.rawValue
        self.note = note
        self.photo = photo
        self.hasPhoto = photo != nil
    }

    /// Sets or removes the photo (the data should come from `PhotoProcessing.prepare`).
    func setPhoto(_ data: Data?) {
        photo = data
        hasPhoto = data != nil
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
    /// The full-screen Growth chart's hint "Drag along the line" goes away for good after the first scrub.
    var scrubHintSeen: Bool = false
    /// Settings → Sounds → Giggle sound: the sun's laugh when it is tapped. On unless turned off.
    var giggleSound: Bool = true
    /// Your pace for the year: hours a week for the 12 months from `targetSetAt`. 0 means none chosen yet
    /// (a game started before this existed); the earlier ones live on as `TargetPeriod` rows.
    var weeklyTargetHours: Double = 0
    var targetSetAt: Date?
    var targetEndsAt: Date?
    /// When the target screen last opened on its own as a sheet (a new year of pace, or the first one for an
    /// older game), so it asks once and then only leaves the reminder in the target row.
    var targetPromptShownAt: Date?
    /// The tab Home opens on next: Today, except right after onboarding (The long game, once).
    var lastHomeTabRaw: String = HomeTab.today.rawValue
    /// Settings → App icon grows with you. On unless turned off.
    var iconGrows: Bool = true
    /// The `IconStage` the home-screen icon was last set to.
    var appliedIconStageRaw: String = IconStage.start.stored

    init() {}

    /// Nil when the stored value is unknown (for example from before the icon grew every 1,000 hours).
    var appliedIconStage: IconStage? {
        get { IconStage(stored: appliedIconStageRaw) }
        set { appliedIconStageRaw = (newValue ?? .start).stored }
    }

    var weekStart: WeekStart {
        get { WeekStart(rawValue: weekStartRaw) ?? .monday }
        set { weekStartRaw = newValue.rawValue }
    }

    var lastHomeTab: HomeTab {
        get { HomeTab(rawValue: lastHomeTabRaw) ?? .today }
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


/// The running session, shared through iCloud so any device can show, pause or finish it. The timer itself is still
/// timestamps on each device; this record is how they agree. All values have defaults so CloudKit can hold it.
@Model
final class ActiveSession {
    var id: UUID = UUID()
    var craftId: UUID = UUID()
    var craftName: String = ""
    var startedAt: Date = Date()
    var pausedAt: Date?
    var accumulatedPause: Double = 0
    var deviceName: String = ""
    var changedAt: Date = Date()
    var endedAt: Date?

    init(_ record: ActiveSessionRecord) {
        id = record.id
        apply(record)
    }

    func apply(_ record: ActiveSessionRecord) {
        craftId = record.craftId
        craftName = record.craftName
        startedAt = record.startedAt
        pausedAt = record.pausedAt
        accumulatedPause = record.accumulatedPause
        deviceName = record.deviceName
        changedAt = record.changedAt
        endedAt = record.endedAt
    }

    var record: ActiveSessionRecord {
        var r = ActiveSessionRecord(id: id, state: TimerState(craftId: craftId, craftName: craftName, startedAt: startedAt,
                                                              pausedAt: pausedAt, accumulatedPause: accumulatedPause),
                                    deviceName: deviceName, changedAt: changedAt)
        r.endedAt = endedAt
        return r
    }
}
