import SwiftUI

/// "Your pace for the year": a weekly target for the next 12 months, counted from today.
/// Step 4 of onboarding, pushed from the target row on Home to change it, and a sheet when a year ends.
struct WeeklyTargetView: View {
    enum Mode {
        /// Setup step 4 of 5, "From today on": the setup scene, the time strip, "Continue" (step 5 is Keep your game safe).
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
    let actualPace: Double
    let onSave: (Double) -> Void
    var now: Date = Date()
    /// The total so far, for the finish line under the stepper (update 53). Nil leaves it out.
    var total: Double?
    /// The small card that links back to "Before today". Nil leaves it out.
    var link: SetupLink?
    /// Onboarding's answers, for the setup scene (step 4 only).
    var onboarding: OnboardingModel?
    /// Tapping the link card in onboarding goes back to step 3.
    var onBackToHours: (() -> Void)?

    @State private var hours: Double
    @Environment(\.dismiss) private var dismiss

    init(mode: Mode, initial: Double? = nil, actualPace: Double, now: Date = Date(), total: Double? = nil,
         link: SetupLink? = nil, onboarding: OnboardingModel? = nil, onBackToHours: (() -> Void)? = nil,
         onSave: @escaping (Double) -> Void) {
        self.mode = mode
        self.actualPace = actualPace
        self.now = now
        self.total = total
        self.link = link
        self.onboarding = onboarding
        self.onBackToHours = onBackToHours
        self.onSave = onSave
        _hours = State(initialValue: WeeklyTarget.clamped(initial ?? WeeklyTarget.suggested(pace: actualPace)))
    }

    private var title: LocalizedStringKey {
        switch mode {
        case .onboarding: "From today on"
        case .newYear: "A new year of pace"
        case .edit, .firstTime: "Your pace for the year"
        }
    }

    private var subtitle: LocalizedStringKey {
        mode == .onboarding ? "How many hours a week do you want to play for the next 12 months?"
                            : "For the next 12 months, the only distance to cover."
    }

    private var buttonTitle: LocalizedStringKey { mode == .onboarding ? "Continue" : "Save" }

    private var unit: String { hours == 1 ? String(localized: "hour a week") : String(localized: "hours a week") }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                if mode == .onboarding, let onboarding {
                    SetupSceneView(state: onboarding.scene(editing: .pace, pace: hours, showsFinish: true))
                        .padding(.horizontal, -24)
                        .padding(.top, 6)
                    SetupTimeStripView(lit: .nextYear)
                        .padding(.top, 14)
                }
                Text(title).lgText(.setupTitle).accessibilityAddTraits(.isHeader)
                    .padding(.top, mode.isSheet ? 12 : (mode == .onboarding ? 14 : 18))
                Text(subtitle)
                    .lgText(mode == .onboarding ? .setupLine : .body, color: LGColor.inkMuted)
                    .lineSpacing(mode == .onboarding ? 3 : 4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, mode == .onboarding ? 6 : 8)

                if let link { linkCard(link).padding(.top, 14) }

                picker.padding(.top, link == nil ? 34 : 30)
                VStack(spacing: 4) {
                    Text("About \(WeeklyTarget.perDay(hours)) · until \(DateText.monthYear(WeeklyTarget.endDate(from: now)))")
                        .lgText(.note, color: LGColor.inkMuted)
                    if let total {
                        Text(verbatim: FinishLineText.sentence(total: total, weeklyRate: hours, now: now))
                            .lgText(LGTextStyle(size: 14, weight: .semibold, relativeTo: .footnote), color: LGColor.ember)
                    }
                }
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(.top, 22)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .scrollBounceBehavior(.basedOnSize)
        // In setup the pace is kept as it changes, so going back to "Before today" and returning doesn't lose it.
        .onChange(of: hours) { _, new in
            onboarding?.targetHours = new
            onboarding?.paceKnown = true
        }
        .safeAreaInset(edge: .bottom) { actions }
        .lgSetupScreen()
        .navigationBarBackButtonHidden()
        .lgHidesNavigationBar()
    }

    /// One gold dot, a bold first part and a muted second: "Last year: 12 h a week. Keep that pace, or change it."
    /// In onboarding a tap goes back to "Before today".
    @ViewBuilder
    private func linkCard(_ link: SetupLink) -> some View {
        let content = HStack(alignment: .firstTextBaseline, spacing: 10) {
            Circle()
                .fill(LinearGradient(colors: [LGColor.setupLitStart, LGColor.setupLitEnd], startPoint: .leading, endPoint: .trailing))
                .frame(width: 8, height: 8)
                .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 1 }
            (Text(verbatim: link.bold).fontWeight(.semibold) + Text(verbatim: " ")
             + Text(verbatim: link.muted).foregroundColor(LGColor.inkMuted))
                .lgText(LGTextStyle(size: 14, weight: .regular, relativeTo: .subheadline))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .lgCard(radius: 14)
        if let onBackToHours {
            Button(action: onBackToHours) { content }
                .buttonStyle(.plain)
                .accessibilityHint("Goes back to Before today")
        } else {
            content.accessibilityElement(children: .combine)
        }
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
            .frame(maxWidth: .infinity)
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
            if mode == .onboarding { LGBrandLine().padding(.top, 10) }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, mode == .onboarding ? 10 : 8)
        .background(LGColor.background.opacity(0.94))
    }
}

#Preview("From today on") {
    let m = OnboardingModel(); m.craftName = "Calligraphy"; m.startYear = 2019; m.startYearKnown = true; m.estimateKnown = true
    return NavigationStack {
        WeeklyTargetView(mode: .onboarding, actualPace: m.actualPace, total: m.estimatedSoFar(), link: m.link,
                         onboarding: m, onBackToHours: {}) { _ in }
    }
}

#Preview("From today on · dark, AX5") {
    let m = OnboardingModel(); m.craftName = "Calligraphy"; m.startYear = m.currentYear; m.startYearKnown = true; m.estimateKnown = true
    return NavigationStack {
        WeeklyTargetView(mode: .onboarding, actualPace: m.actualPace, total: m.estimatedSoFar(), link: m.link,
                         onboarding: m, onBackToHours: {}) { _ in }
    }
    .preferredColorScheme(.dark).dynamicTypeSize(.accessibility5)
}

#Preview("Your pace for the year") {
    NavigationStack {
        WeeklyTargetView(mode: .edit, actualPace: 12, total: 3_100, link: .lastYear(hoursPerWeek: 12)) { _ in }
    }
}
