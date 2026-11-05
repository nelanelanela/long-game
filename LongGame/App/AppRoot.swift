import SwiftUI
import SwiftData

/// No active craft (first launch, or after "Switch to a new game") → Welcome + onboarding; the intro pages only
/// the first time. Otherwise Home (it opens on This week).
///
/// On the very first launch it also looks quietly in the person's iCloud for a game (for at most 3 s). If there is
/// one, Welcome back is shown instead of Welcome.
struct AppRoot: View {
    @Query private var crafts: [Craft]
    @Query private var settingsRows: [AppSettings]
    @Environment(\.modelContext) private var context
    @Environment(StoreHost.self) private var store
    @Environment(ICloudMonitor.self) private var monitor

    private enum Phase: Equatable {
        case undecided
        /// Looking in iCloud; Home waits, so a game that arrives is offered rather than opened.
        case looking
        case welcomeBack(FoundGame)
        case done
    }

    @State private var phase = Phase.undecided
    /// After "Start a new game" the intro pages are shown, as on a first launch.
    @State private var playIntro = false

    private var active: Craft? { crafts.first(where: \.isActive) }

    var body: some View {
        Group {
            if case .welcomeBack(let game) = phase {
                WelcomeBackView(game: game, onContinue: { phase = .done }, onStartNew: startNewGame)
            } else if let active, phase != .looking {
                NavigationStack { HomeView(craft: active) }
            } else {
                OnboardingFlow(showIntro: crafts.isEmpty || playIntro)
            }
        }
        .syncsWidgets()
        .environment(\.giggleSoundOn, settingsRows.first?.giggleSound ?? true)
        .task { await lookInICloud() }
    }

    private func lookInICloud() async {
        guard phase == .undecided else { return }
        let availability = await monitor.availabilityNow()
        guard ICloudLaunch.shouldLookForGame(isFreshInstall: store.isFreshInstall, hasActiveCraft: active != nil,
                                             availability: availability), store.iCloudOn else {
            phase = .done
            return
        }
        phase = .looking
        let container = store.container
        let outcome = await WelcomeBack.probe { Self.foundGame(in: container.mainContext) }
        phase = switch WelcomeBack.decide(outcome) {
        case .welcomeBack(let game): .welcomeBack(game)
        case .normalOnboarding: .done
        }
    }

    /// The active game that has arrived from iCloud, with its total hours, once there is one.
    @MainActor
    private static func foundGame(in context: ModelContext) -> FoundGame? {
        let crafts = (try? context.fetch(FetchDescriptor<Craft>())) ?? []
        guard let craft = crafts.first(where: \.isActive) else { return nil }
        let id = craft.id
        let estimates = (try? context.fetch(FetchDescriptor<YearEstimate>(predicate: #Predicate { $0.craftId == id }))) ?? []
        let sessions = (try? context.fetch(FetchDescriptor<Session>(predicate: #Predicate { $0.craftId == id }))) ?? []
        let summary = ProgressSummary.make(estimates: estimates.map(\.rate), sessions: sessions.map(\.record),
                                           onboardingDate: craft.createdAt, weekStart: .localeDefault, now: Date())
        return FoundGame(craftName: craft.name, hours: summary.wholeHours)
    }

    /// The game in iCloud is archived, not deleted; the normal onboarding follows.
    private func startNewGame() {
        let now = Date()
        for craft in crafts where craft.isActive { craft.archivedAt = now }
        try? context.save()
        playIntro = true
        phase = .done
    }
}
