import AppIntents
import Foundation

/// A Live Activity button on the iPhone; a plain intent on the Mac (it has no Live Activities).
#if os(iOS)
typealias SessionIntent = LiveActivityIntent
#else
typealias SessionIntent = AppIntent
#endif

/// Starting a session from anywhere (Control Center, the Action button, Siri, Shortcuts) without opening the app.
/// The craft comes from the snapshot the app keeps in the shared App Group, and the timer is stored as timestamps
/// like always, so the app picks it up the next time it opens.

/// Why a session could not be started, in words Siri can say.
enum StartPlayingError: Error, CustomLocalizedStringResourceConvertible {
    case noCraft

    var localizedStringResource: LocalizedStringResource {
        "Open Long Game once to choose your craft, then try again."
    }
}

enum StartPlaying {
    /// Starts the timer for the active craft, or resumes it if it is paused. Returns what to tell the person.
    @MainActor
    static func run(now: Date = Date()) throws -> LocalizedStringResource {
        if var running = TimerPersistence.load() {
            if running.isPaused(at: now) {
                running.resume(at: now)
                save(running, now: now)
                return "Back to \(running.craftName)."
            }
            return "You are already playing \(running.craftName)."
        }
        guard let snapshot = WidgetSnapshot.load(), let craftId = snapshot.craftId else { throw StartPlayingError.noCraft }
        let state = TimerState(craftId: craftId, craftName: snapshot.craftName, startedAt: now)
        save(state, now: now)
        return "Started playing \(snapshot.craftName)."
    }

    @MainActor
    private static func save(_ state: TimerState, now: Date) {
        TimerPersistence.save(state)
        UserDefaults.standard.set(now.timeIntervalSince1970, forKey: "timer.changedAt.v1")
        LiveActivityManager.sync(state, now: now)
        // If the app is already open it re-reads the stored timer.
        NotificationCenter.default.post(name: .timerChangedExternally, object: nil)
    }
}

/// "Start playing": no choices, so it can sit on a Control Center button or the Action button.
struct StartPlayingIntent: SessionIntent {
    static let title: LocalizedStringResource = "Start playing"
    static let description = IntentDescription("Starts a session for your craft.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: IntentDialog(try StartPlaying.run()))
    }
}

/// Lets Siri hear the craft's name: "Start playing piano".
struct CraftEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Craft"
    static let defaultQuery = CraftQuery()

    var id: UUID
    var name: String

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }

    /// The one active craft, if the app has been set up.
    static func current() -> CraftEntity? {
        guard let snapshot = WidgetSnapshot.load(), let id = snapshot.craftId else { return nil }
        return CraftEntity(id: id, name: snapshot.craftName)
    }
}

struct CraftQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [CraftEntity] {
        guard let craft = CraftEntity.current(), identifiers.contains(craft.id) else { return [] }
        return [craft]
    }

    func suggestedEntities() async throws -> [CraftEntity] {
        CraftEntity.current().map { [$0] } ?? []
    }
}

/// The same thing with the craft named, for "Hey Siri, start playing piano". There is only one active craft, so the
/// name is only there so the phrase sounds natural.
struct StartPlayingCraftIntent: SessionIntent {
    static let title: LocalizedStringResource = "Start playing a craft"
    static let description = IntentDescription("Starts a session for your craft by name.")

    @Parameter(title: "Craft")
    var craft: CraftEntity

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: IntentDialog(try StartPlaying.run()))
    }
}
