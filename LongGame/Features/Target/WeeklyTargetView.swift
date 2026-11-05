import SwiftUI

/// "Your pace for the year": a weekly target for the next 12 months, counted from today.
/// Step 4 of onboarding, pushed from the target row on Home to change it, and a sheet when a year ends.
struct WeeklyTargetView: View {
    enum Mode {
        /// Last setup step: back chevron, four step dots, "Start playing".
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
    /// Where the stepper starts, and the "Your recent pace" line.
    let recentPace: Double
    /// Total, pace and trend for the "In a year" line.
    let summary: ProgressSummary
    let onSave: (Double) -> Void
    var now: Date = Date()

    @State private var hours: Double
    @Environment(\.dismiss) private var dismiss

    init(mode: Mode, initial: Double? = nil, recentPace: Double, summary: ProgressSummary, now: Date = Date(),
         onSave: @escaping (Double) -> Void) {
        self.mode = mode
        self.recentPace = recentPace
        self.summary = summary
        self.now = now
        self.onSave = onSave
        _hours = State(initialValue: WeeklyTarget.clamped(initial ?? WeeklyTarget.suggested(pace: recentPace)))
    }

    private var title: LocalizedStringKey { mode == .newYear ? "A new year of pace" : "Your pace for the year" }

    private var buttonTitle: LocalizedStringKey { mode == .onboarding ? "Start playing" : "Save" }

    private var unit: String { hours == 1 ? String(localized: "hour a week") : String(localized: "hours a week") }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                VStack(alignment: .leading, spacing: 10) {
                    Text(title).lgText(.screenTitle).accessibilityAddTraits(.isHeader)
                    Text("A thousand-mile walk is made one day’s stretch at a time. Set the 10,000 hours aside for a moment and choose how many hours a week you’ll play for the next 12 months. Each week, that’s the only distance to cover.")
                        .lgText(.body, color: LGColor.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 12)

                picker.padding(.top, 20)
                summaryRows.padding(.top, 14)
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
        VStack(spacing: 14) {
            HoursBigStepper(label: String(localized: "Hours a week"), value: $hours, spec: .pace, unit: unit,
                            quickPicks: quickPicks)
            Text("Tap the number to type it · hold − or + to go faster")
                .lgText(LGTextStyle(size: 12, weight: .regular, relativeTo: .caption), color: LGColor.inkMuted)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 16).padding(.top, 20).padding(.bottom, 18)
        .frame(maxWidth: .infinity)
        .lgCard(radius: 24)
    }

    /// "Recent pace · N" plus 5, 8, 15 and 20.
    private var quickPicks: [HoursQuickPick] {
        let recent = WeeklyTarget.clamped(recentPace)
        return [HoursQuickPick(title: String(localized: "Recent pace · \(WeeklyTarget.number(recent))"), value: recent)]
            + [5.0, 8, 15, 20].map { HoursQuickPick(title: WeeklyTarget.number($0), value: $0) }
    }

    private var summaryRows: some View {
        let finish = ForecastText.homeMastery(summary.finish(ifTarget: hours), now: now)
        let end = WeeklyTarget.endDate(from: now)
        return VStack(spacing: 0) {
            row("Until", DateText.dayMonthYear(end))
            Divider().overlay(LGColor.divider)
            row("About", WeeklyTarget.perDay(hours))
            Divider().overlay(LGColor.divider)
            row("In a year", "+\(DurationFormat.grouped(Int(WeeklyTarget.addedHours(hours)))) h · finish \(finish)", strong: true)
        }
        .padding(.horizontal, 18)
        .lgCard()
    }

    private func row(_ label: LocalizedStringKey, _ value: String, strong: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label).lgText(strong ? .rowStrong : .row)
            Spacer(minLength: 8)
            Text(value).lgText(strong ? .rowStrong : .row, color: strong ? LGColor.ink : LGColor.inkMuted)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(minHeight: 48)
        .accessibilityElement(children: .combine)
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
        WeeklyTargetView(mode: .onboarding, recentPace: 12,
                         summary: ProgressSummary.make(estimates: [YearRate(year: 2019, hoursPerWeek: 3), YearRate(year: 2020, hoursPerWeek: 12)],
                                                       sessions: [], onboardingDate: Date(), weekStart: .monday, now: Date())) { _ in }
    }
}
