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
    @Environment(TimerStore.self) private var timer
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
    /// The opening sunrise (spec section 21). On a cold start the very first frame is the night frame; the decision
    /// about which version plays is made right after, and never waits for the database or iCloud.
    @State private var opening = OpeningCenter()
    @State private var openingUndecided = OpeningCenter.consumeColdStart()

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
        .environment(opening)
        .overlay { openingOverlay }
        .onAppear(perform: decideOpening)
        .onOpenURL { _ in opening.finish() }
        .onReceive(NotificationCenter.default.publisher(for: .openingShouldSkip)) { _ in opening.finish() }
        .onChange(of: opening.finishedCount) { _, _ in OpeningAccessibility.moveFocusToContent() }
        .environment(\.giggleSoundOn, settingsRows.first?.giggleSound ?? true)
        .task { await lookInICloud() }
    }

    // MARK: Opening sunrise

    @ViewBuilder
    private var openingOverlay: some View {
        if openingUndecided {
            // The first frame: exactly the launch screen's night.
            OpeningSunriseView(plan: OpeningPlan(style: .full, landing: .home), start: .now, target: nil, frozenAt: 0)
        } else if let run = opening.running {
            RunningOpening(opening: opening, plan: run.plan, start: run.start)
                .task(id: run.start) {
                    try? await Task.sleep(for: .seconds(run.plan.style.duration + OpeningCenter.lead))
                    if !Task.isCancelled { opening.finish() }
                }
        }
    }

    private func decideOpening() {
        guard openingUndecided else { return }
        openingUndecided = false
        let plan = openingStyle(coldStart: true, openedFrom: .icon, sessionRunning: timer.state != nil,
                                reduceMotion: reduceMotion, voiceOver: OpeningAccessibility.voiceOverRunning,
                                onboarded: active != nil)
        opening.begin(plan)
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

/// The opening while it plays. It reads Home's sun position (`sunTarget`) itself, so only this overlay redraws when
/// Home reports it. If `AppRoot` read it, every report would rebuild Home, which measures and reports again: on some
/// launches that never settled and the app froze on the night frame.
private struct RunningOpening: View {
    let opening: OpeningCenter
    let plan: OpeningPlan
    let start: Date

    var body: some View {
        OpeningSunriseView(plan: plan, start: start,
                           target: plan.landing == .home ? opening.sunTarget : nil,
                           onTap: { opening.finish() })
    }
}
