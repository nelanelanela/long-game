import AppIntents
import Foundation

// Beginning and pausing a session without opening the app: the Control (Control Centre, the Lock Screen), the Action
// Button, Siri, Spotlight and the Live Activity's pause button. On the iPhone these are Live Activity intents, so iOS
// runs them in the app's own process (even from the background) where every change goes through `TimerStore`, and
// they can start the Live Activity. The widget extension has a copy only so the Control can name them.
//
// Finishing isn't offered here: it stays on the Live Activity and in the app, where the note and photo are.

/// A Live Activity intent on the iPhone; a plain intent on the Mac (it has no Live Activities).
#if os(iOS)
typealias SessionIntent = LiveActivityIntent
#else
typealias SessionIntent = AppIntent
#endif

/// Why a session could not be started, in words Siri can say.
enum SessionIntentError: Error, CustomLocalizedStringResourceConvertible {
    case noCraft

    var localizedStringResource: LocalizedStringResource {
        "Open Long Game to choose your craft, then try again."
    }
}

/// The craft the app last shared with its widgets (nil until the app has been set up).
enum CurrentCraft {
    static func load() -> (id: UUID, name: String)? {
        guard let snapshot = WidgetSnapshot.load(), let id = snapshot.craftId else { return nil }
        return (id, snapshot.craftName)
    }
}

/// Runs a timer command where the timer lives. In the app that is `TimerStore`; the widget extension (which iOS
/// doesn't normally run these in) changes the stored timestamps the same way and the app picks them up.
@MainActor
enum SessionCommands {
    static func begin(now: Date = Date()) -> TimerCommands.Begin {
        let craft = CurrentCraft.load()
        #if WIDGET_EXTENSION
        let result = TimerCommands.begin(TimerPersistence.load(), craftId: craft?.id, craftName: craft?.name ?? "", now: now)
        switch result {
        case .started(let s), .resumed(let s): store(s, now: now)
        case .alreadyRunning, .noCraft: break
        }
        return result
        #else
        return TimerStore.shared.begin(craftId: craft?.id, craftName: craft?.name ?? "", now: now)
        #endif
    }

    /// Nil when nothing is running.
    @discardableResult
    static func pauseOrResume(now: Date = Date()) -> TimerState? {
        #if WIDGET_EXTENSION
        let next = TimerCommands.pauseOrResume(TimerPersistence.load(), now: now)
        if let next { store(next, now: now) }
        return next
        #else
        return TimerStore.shared.pauseOrResume(now: now)
        #endif
    }

    static func setPlaying(_ playing: Bool, now: Date = Date()) -> TimerCommands.Toggle {
        let craft = CurrentCraft.load()
        #if WIDGET_EXTENSION
        let result = TimerCommands.setPlaying(playing, TimerPersistence.load(), craftId: craft?.id, craftName: craft?.name ?? "", now: now)
        switch result {
        case .begin(.started(let s)), .begin(.resumed(let s)), .paused(let s): store(s, now: now)
        default: break
        }
        return result
        #else
        return TimerStore.shared.setPlaying(playing, craftId: craft?.id, craftName: craft?.name ?? "", now: now)
        #endif
    }

    #if WIDGET_EXTENSION
    private static func store(_ state: TimerState, now: Date) {
        TimerPersistence.save(state)
        LiveActivityManager.sync(state, now: now)
    }
    #endif
}

/// "Begin a session": no choices, so it can sit on the Action Button.
struct BeginSessionIntent: SessionIntent {
    static let title: LocalizedStringResource = "Begin a session"
    static let description = IntentDescription("Starts the timer for your craft.")

    @available(iOS 26.0, macOS 26.0, *)
    static var supportedModes: IntentModes { [.background, .foreground(.dynamic)] }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        switch SessionCommands.begin() {
        case .started(let s): return .result(dialog: "Started \(s.craftName). Enjoy it.")
        case .resumed(let s): return .result(dialog: "Back to \(s.craftName).")
        case .alreadyRunning: return .result(dialog: "Your session is already running.")
        case .noCraft: throw openAppInstead()
        }
    }
}

/// "Pause session": pauses the running session, or carries on with a paused one. The Live Activity's button too.
struct PauseResumeSessionIntent: SessionIntent {
    static let title: LocalizedStringResource = "Pause session"
    static let description = IntentDescription("Pauses the running session, or resumes it if it's paused.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let s = SessionCommands.pauseOrResume() else { return .result(dialog: "No session is running.") }
        return .result(dialog: s.pausedAt != nil ? "Paused." : "Back to \(s.craftName).")
    }
}

extension AppIntent {
    /// With no craft set up yet, the app opens instead (iOS 26 and later; earlier, Siri says to open it).
    func openAppInstead() -> Error {
        if #available(iOS 26.0, macOS 26.0, *) {
            return needsToContinueInForegroundError("Open Long Game to choose your craft.")
        }
        return SessionIntentError.noCraft
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
        CurrentCraft.load().map { CraftEntity(id: $0.id, name: $0.name) }
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

/// The same as Begin with the craft named, for "Hey Siri, start playing piano". There is only one active craft, so
/// the name is only there so the phrase sounds natural.
struct StartPlayingCraftIntent: SessionIntent {
    static let title: LocalizedStringResource = "Start playing a craft"
    static let description = IntentDescription("Starts a session for your craft by name.")

    @Parameter(title: "Craft")
    var craft: CraftEntity

    @available(iOS 26.0, macOS 26.0, *)
    static var supportedModes: IntentModes { [.background, .foreground(.dynamic)] }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        switch SessionCommands.begin() {
        case .started(let s): return .result(dialog: "Started \(s.craftName). Enjoy it.")
        case .resumed(let s): return .result(dialog: "Back to \(s.craftName).")
        case .alreadyRunning: return .result(dialog: "Your session is already running.")
        case .noCraft: throw openAppInstead()
        }
    }
}
