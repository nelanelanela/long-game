import SwiftUI
import SwiftData

@Observable
final class OnboardingModel {
    /// What is typed in the craft field. A tapped choice doesn't change it (update 54).
    var craftName = "" {
        didSet { if craftName != oldValue { pickedCraft = nil } }
    }
    /// A choice tapped in the list, which wins over the typed text until the text changes or the own chip is tapped.
    var pickedCraft: String?
    /// The list as it stands, and the craft that would be played.
    var craftChoice: CraftSuggestions.Choice { CraftSuggestions.choice(craftName, picked: pickedCraft) }
    var chosenCraft: String? { craftChoice.selected }
    /// The suggestion group of the chosen craft, or "Your own".
    var category: String { chosenCraft.flatMap(CraftSuggestions.group(of:)) ?? CraftSuggestions.customCategory }
    var startYear: Int
    var hours: [Int: Int] = [:]
    /// "Before today" for a game started this year: about how many hours so far, in total (update 53).
    var soFarTotal: Double = OnboardingModel.defaultSoFar
    /// Set once the started-this-year screen has been seen, so going back to an earlier year fills this year's row
    /// from its total.
    var soFarSeen = false
    /// Set once the user has seen the hours step, so the intro and the setup scene can show the real starting score.
    var estimateKnown = false
    /// The weekly pace chosen in step 4, saved with everything else when the last step is done.
    var targetHours: Double = 0
    /// Set once step 4 has been seen, so the scene's pace chip is filled in.
    var paceKnown = false
    /// Step 5's Save to iCloud switch: on unless the person turns it off (or has no iCloud account).
    var saveToICloud = true
    /// Set once step 2 has been seen, so the scene's "Since" chip is filled in.
    var startYearKnown = false

    static let defaultSoFar: Double = 20
    /// The pace "From today on" suggests to someone who started this year.
    static let startedThisYearPace: Double = 5

    let currentYear: Int
    /// The day setup happens: everything entered is "before today".
    let now: Date
    let calendar: Calendar

    init(now: Date = Date(), calendar: Calendar = .current) {
        self.now = now
        self.calendar = calendar
        currentYear = calendar.component(.year, from: now)
        startYear = currentYear - 3
    }

    /// Started this year: "Before today" asks for a total instead of hours a week.
    var startedThisYear: Bool { startYear >= currentYear }

    var years: [Int] { Array(startYear...currentYear) }

    /// Hours a week for a year. This year's row starts from the total given on the started-this-year screen, if any.
    func hoursFor(_ year: Int) -> Int {
        if let h = hours[year] { return h }
        if year == currentYear && soFarSeen { return Int(soFarWeeklyRate.rounded()) }
        return 5
    }

    /// The total as hours a week since 1 January, stored beside it.
    var soFarWeeklyRate: Double { Baseline.weeklyRate(totalHours: soFarTotal, onboardingDate: now, calendar: calendar) }

    var estimates: [YearRate] {
        if startedThisYear {
            return [YearRate(year: currentYear, hoursPerWeek: soFarWeeklyRate, totalHours: soFarTotal)]
        }
        return years.map { YearRate(year: $0, hoursPerWeek: Double(hoursFor($0))) }
    }

    func estimatedSoFar() -> Double {
        Baseline.hours(estimates: estimates, onboardingDate: now, calendar: calendar)
    }

    /// The pace "From today on" starts at: the latest year's hours a week, or 5 h for a game started this year.
    var actualPace: Double { startedThisYear ? Self.startedThisYearPace : Double(hoursFor(currentYear)) }

    /// The link card on "From today on".
    var link: SetupLink { SetupLink.make(estimates: estimates, currentYear: currentYear) }

    /// The setup scene as it stands on a step.
    func scene(editing: SetupSceneState.Chip?, pace: Double? = nil, showsFinish: Bool = false) -> SetupSceneState {
        let name = chosenCraft ?? ""
        return SetupSceneState(craftName: name,
                               startYear: startYearKnown || editing == .startYear ? startYear : nil,
                               score: estimateKnown || editing == .score ? estimatedSoFar() : nil,
                               weeklyPace: pace ?? (paceKnown ? targetHours : nil),
                               showsFinish: showsFinish, editing: editing, now: now)
    }

    /// Saves the craft, the estimates, the weekly target, and the iCloud choice (never the daily reminder, which
    /// only Settings turns on); Home then opens on The long game, once.
    func save(in context: ModelContext) {
        let craft = Craft(name: chosenCraft ?? craftName.trimmingCharacters(in: .whitespacesAndNewlines),
                          category: category, startYear: startYear, createdAt: now)
        context.insert(craft)
        for e in estimates {
            context.insert(YearEstimate(craftId: craft.id, year: e.year, hoursPerWeek: Int(e.hoursPerWeek.rounded()),
                                        totalHours: e.totalHours))
        }
        // Hours estimated at onboarding never trigger milestone celebrations.
        let seen = Milestones.newlyCrossed(total: estimatedSoFar(), seen: [])
        let settings: AppSettings
        if let existing = (try? context.fetch(FetchDescriptor<AppSettings>()))?.first {
            settings = existing
        } else {
            settings = AppSettings()
            context.insert(settings)
        }
        settings.milestonesSeen = seen
        settings.thousandsAdopted = true
        settings.syncEnabled = saveToICloud
        // The first Home after onboarding opens on The long game; every launch after that opens on This week.
        settings.lastHomeTab = .longGame
        TargetSaving.apply(hours: targetHours, now: now, settings: settings, context: context)
    }
}

/// Welcome (first launch, and again after "Switch to a new game"), the three "How the game works" pages (first
/// onboarding only), then the five setup steps. Nothing here asks for a permission (update 53).
struct OnboardingFlow: View {
    /// False after "Switch to a new game": the user has played before, so the intro pages are skipped.
    let showIntro: Bool

    private enum Stage { case welcome, intro, craft }

    @Environment(\.modelContext) private var context
    @Environment(StoreHost.self) private var store
    @Environment(ICloudMonitor.self) private var monitor
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var model = OnboardingModel()
    @State private var path: [OnboardingStep] = []
    @State private var stage = Stage.welcome

    private func push(after step: OnboardingStep) {
        if let next = OnboardingSteps.next(after: step) { path.append(next) } else { startPlaying() }
    }

    /// Saves the game, then applies the iCloud choice (which reopens the same database with or without mirroring).
    private func startPlaying() {
        let wantsICloud = model.saveToICloud && monitor.availability != .signedOut && monitor.availability != .restricted
        model.saveToICloud = wantsICloud
        model.save(in: context)
        try? context.save()
        try? store.setICloud(wantsICloud)
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                switch stage {
                case .welcome:
                    WelcomeView { withAnimation(reduceMotion ? nil : .default) { stage = showIntro ? .intro : .craft } }
                case .intro:
                    IntroView(startingScore: model.estimateKnown ? Int(model.estimatedSoFar().rounded(.down)) : nil,
                              onBack: { withAnimation(reduceMotion ? nil : .default) { stage = .welcome } },
                              onFinish: { withAnimation(reduceMotion ? nil : .default) { stage = .craft } })
                case .craft:
                    CraftStepView(model: model,
                                  onBack: { withAnimation(reduceMotion ? nil : .default) { stage = showIntro ? .intro : .welcome } },
                                  onContinue: { path.append(.start) })
                }
            }
            .navigationDestination(for: OnboardingStep.self) { step in
                switch step {
                case .start:
                    StartYearView(model: model) { push(after: .start) }
                case .hours:
                    if model.startedThisYear {
                        SoFarThisYearView(model: model) { push(after: .hours) }
                    } else {
                        YearlyHoursView(model: model) { push(after: .hours) }
                    }
                case .pace:
                    WeeklyTargetView(mode: .onboarding, initial: model.paceKnown ? model.targetHours : nil,
                                     actualPace: model.actualPace, now: model.now, total: model.estimatedSoFar(),
                                     link: model.link, onboarding: model,
                                     onBackToHours: { path.removeLast() }) { hours in
                        model.targetHours = hours
                        model.paceKnown = true
                        push(after: .pace)
                    }
                case .keepSafe:
                    ICloudStepView(model: model, letterTotal: model.estimatedSoFar()) {
                        push(after: .keepSafe)
                    }
                }
            }
            .lgHidesNavigationBar()
        }
        .environment(\.onboardingStepCount, OnboardingSteps.count)
    }
}

private struct OnboardingStepCountKey: EnvironmentKey { static let defaultValue = OnboardingSteps.count }
extension EnvironmentValues {
    /// How many step dots onboarding shows: five.
    var onboardingStepCount: Int {
        get { self[OnboardingStepCountKey.self] }
        set { self[OnboardingStepCountKey.self] = newValue }
    }
}

/// Back chevron + step dots shared by onboarding screens.
struct OnboardingHeader: View {
    let step: Int
    var showsBack: Bool = true
    /// Where Back goes when the screen is not a pushed one (step 1 goes back to the intro pages).
    var onBack: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.onboardingStepCount) private var stepCount

    var body: some View {
        ZStack {
            // The step bar is centred on the screen, whatever sits beside it.
            LGStepBar(step: step, of: stepCount)
            HStack {
                if showsBack {
                    LGIconButton(systemName: "chevron.left", label: "Back") { if let onBack { onBack() } else { dismiss() } }
                        .padding(.leading, -10)
                }
                Spacer()
            }
        }
        .frame(height: 44)
    }
}
