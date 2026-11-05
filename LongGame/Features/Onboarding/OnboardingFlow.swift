import SwiftUI
import SwiftData

@Observable
final class OnboardingModel {
    var craftName = ""
    var category = CraftCatalog.customCategory
    var startYear: Int
    var hours: [Int: Int] = [:]
    /// Set once the user has seen the hours step, so the intro can show the real starting score.
    var estimateKnown = false
    /// The weekly pace chosen in step 4, saved with everything else when the last step is done.
    var targetHours: Double = 0
    /// Step 5's Save to iCloud switch: on unless the person turns it off (or has no iCloud account).
    var saveToICloud = true

    let currentYear: Int

    init(now: Date = Date(), calendar: Calendar = .current) {
        currentYear = calendar.component(.year, from: now)
        startYear = currentYear - 3
    }

    var years: [Int] { Array(startYear...currentYear) }

    func hoursFor(_ year: Int) -> Int { hours[year] ?? 5 }

    var estimates: [YearRate] {
        years.map { YearRate(year: $0, hoursPerWeek: Double(hoursFor($0))) }
    }

    func estimatedSoFar(now: Date = Date(), calendar: Calendar = .current) -> Double {
        Baseline.hours(estimates: estimates, onboardingDate: now, calendar: calendar)
    }

    /// This year's estimate is the pace on offer in step 4: there are no sessions to measure yet.
    var recentPace: Double { Double(hoursFor(currentYear)) }

    /// Saves the craft, the estimates, the weekly target and the iCloud choice; Home then opens on The long game, once.
    func save(in context: ModelContext, now: Date = Date()) {
        let craft = Craft(name: craftName.trimmingCharacters(in: .whitespacesAndNewlines),
                          category: category, startYear: startYear, createdAt: now)
        context.insert(craft)
        for year in years {
            context.insert(YearEstimate(craftId: craft.id, year: year, hoursPerWeek: hoursFor(year)))
        }
        // Hours estimated at onboarding never trigger milestone celebrations.
        let seen = Milestones.newlyCrossed(total: estimatedSoFar(now: now), seen: [])
        let settings: AppSettings
        if let existing = (try? context.fetch(FetchDescriptor<AppSettings>()))?.first {
            settings = existing
        } else {
            settings = AppSettings()
            context.insert(settings)
        }
        settings.milestonesSeen = seen
        settings.syncEnabled = saveToICloud
        // The first Home after onboarding opens on The long game; every launch after that opens on This week.
        settings.lastHomeTab = .longGame
        TargetSaving.apply(hours: targetHours, now: now, settings: settings, context: context)
    }
}

enum OnboardingStep: Hashable {
    case start, hours, pace, keepSafe
}

/// Welcome (first launch, and again after "Switch to a new game"), the three "How the game works" pages (first
/// onboarding only), then the five setup steps.
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
                    CraftStepView(model: model) { path.append(.start) }
                }
            }
            .navigationDestination(for: OnboardingStep.self) { step in
                switch step {
                case .start:
                    StartYearView(model: model) { path.append(.hours) }
                case .hours:
                    YearlyHoursView(model: model) { path.append(.pace) }
                case .pace:
                    WeeklyTargetView(mode: .onboarding, recentPace: model.recentPace) { hours in
                        model.targetHours = hours
                        path.append(.keepSafe)
                    }
                case .keepSafe:
                    ICloudStepView(model: model, onStart: startPlaying)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

/// Back chevron + step dots shared by onboarding screens.
struct OnboardingHeader: View {
    let step: Int
    var showsBack: Bool = true
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        HStack {
            if showsBack {
                LGIconButton(systemName: "chevron.left", label: "Back") { dismiss() }
                    .padding(.leading, -10)
            } else {
                Color.clear.frame(width: 34, height: 44)
            }
            Spacer()
            LGStepBar(step: step, of: 5)
            Spacer()
            Color.clear.frame(width: 34, height: 44)
        }
        .frame(height: 44)
    }
}
