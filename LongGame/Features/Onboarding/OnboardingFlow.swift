import SwiftUI
import SwiftData

@Observable
final class OnboardingModel {
    var craftName = ""
    var category = CraftCatalog.customCategory
    var startYear: Int
    var hours: [Int: Int] = [:]

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

    func save(in context: ModelContext, now: Date = Date()) {
        let craft = Craft(name: craftName.trimmingCharacters(in: .whitespacesAndNewlines),
                          category: category, startYear: startYear, createdAt: now)
        context.insert(craft)
        for year in years {
            context.insert(YearEstimate(craftId: craft.id, year: year, hoursPerWeek: hoursFor(year)))
        }
        // Hours estimated at onboarding never trigger milestone celebrations.
        let seen = Milestones.newlyCrossed(total: estimatedSoFar(now: now), seen: [])
        if let existing = (try? context.fetch(FetchDescriptor<AppSettings>()))?.first {
            existing.milestonesSeen = seen
        } else {
            let settings = AppSettings()
            settings.milestonesSeen = seen
            context.insert(settings)
        }
        try? context.save()
    }
}

enum OnboardingStep: Hashable {
    case start, hours
}

/// Welcome (first launch only) followed by the three setup steps.
struct OnboardingFlow: View {
    /// After "Replace my craft" the welcome screen is skipped.
    let showWelcome: Bool

    @State private var model = OnboardingModel()
    @State private var path: [OnboardingStep] = []
    @State private var started = false

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if showWelcome && !started {
                    WelcomeView { withAnimation { started = true } }
                } else {
                    CraftStepView(model: model) { path.append(.start) }
                }
            }
            .navigationDestination(for: OnboardingStep.self) { step in
                switch step {
                case .start:
                    StartYearView(model: model) { path.append(.hours) }
                case .hours:
                    YearlyHoursView(model: model)
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
            LGStepBar(step: step, of: 3)
            Spacer()
            Color.clear.frame(width: 34, height: 44)
        }
        .frame(height: 44)
    }
}
