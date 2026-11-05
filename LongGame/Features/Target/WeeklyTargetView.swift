import SwiftUI

/// "Your pace for the year": a weekly target for the next 12 months, counted from today.
/// Step 4 of onboarding, pushed from the target row on Home to change it, and a sheet when a year ends.
struct WeeklyTargetView: View {
    enum Mode {
        /// Setup step 4 of 5: back chevron, five step dots, "Continue" (step 5 is Keep your game safe).
        case onboarding
        /// Pushed from Home: back chevron, "Save".
        case edit
        /// A sheet when the year of pace is over: "A new year of pace", with the old value filled in.
        case newYear
        /// A sheet for a game that has no target yet (started before targets existed).
        case firstTime

        var isSheet: Bool { self == .newYear || self == .firstTime }
    }

    let mode: Mode
    /// Where the stepper starts when there is no target yet.
    let recentPace: Double
    let onSave: (Double) -> Void
    var now: Date = Date()

    @State private var hours: Double
    @Environment(\.dismiss) private var dismiss

    init(mode: Mode, initial: Double? = nil, recentPace: Double, now: Date = Date(),
         onSave: @escaping (Double) -> Void) {
        self.mode = mode
        self.recentPace = recentPace
        self.now = now
        self.onSave = onSave
        _hours = State(initialValue: WeeklyTarget.clamped(initial ?? WeeklyTarget.suggested(pace: recentPace)))
    }

    private var title: LocalizedStringKey {
        switch mode {
        case .onboarding: "Your weekly pace"
        case .newYear: "A new year of pace"
        case .edit, .firstTime: "Your pace for the year"
        }
    }

    private var buttonTitle: LocalizedStringKey { mode == .onboarding ? "Continue" : "Save" }

    private var unit: String { hours == 1 ? String(localized: "hour a week") : String(localized: "hours a week") }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                VStack(alignment: .leading, spacing: 10) {
                    Text(title).lgText(.screenTitle).accessibilityAddTraits(.isHeader)
                    Text("For the next 12 months, the only distance to cover.")
                        .lgText(.body, color: LGColor.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 12)

                picker.padding(.top, 20)
                Text("About \(WeeklyTarget.perDay(hours)) · until \(DateText.monthYear(WeeklyTarget.endDate(from: now)))")
                    .lgText(.body, color: LGColor.inkMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 18)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) { actions }
        .lgScreen()
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: Pieces

    @ViewBuilder
    private var header: some View {
        switch mode {
        case .onboarding:
            OnboardingHeader(step: 4)
        case .edit:
            HStack {
                LGIconButton(systemName: "chevron.left", label: "Back") { dismiss() }
                    .padding(.leading, -10)
                Spacer()
            }
            .frame(height: 44)
        case .newYear, .firstTime:
            Color.clear.frame(height: 24)
        }
    }

    private var picker: some View {
        HoursBigStepper(label: String(localized: "Hours a week"), value: $hours, spec: .pace, unit: unit)
            .padding(.horizontal, 16).padding(.top, 20).padding(.bottom, 18)
            .frame(maxWidth: .infinity)
            .lgCard(radius: 24)
    }

    private var actions: some View {
        VStack(spacing: 2) {
            Button(buttonTitle) {
                onSave(hours)
                if mode != .onboarding { dismiss() }
            }
            .buttonStyle(.lg(.primary))
            if mode.isSheet {
                Button("Not now") { dismiss() }.buttonStyle(.lg(.text))
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(LGColor.background.opacity(0.94))
    }
}

#Preview("Your pace for the year") {
    NavigationStack {
        WeeklyTargetView(mode: .onboarding, recentPace: 12) { _ in }
    }
}
