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
    let actualPace: Double
    let onSave: (Double) -> Void
    var now: Date = Date()

    @State private var hours: Double
    @Environment(\.dismiss) private var dismiss

    init(mode: Mode, initial: Double? = nil, actualPace: Double, now: Date = Date(),
         onSave: @escaping (Double) -> Void) {
        self.mode = mode
        self.actualPace = actualPace
        self.now = now
        self.onSave = onSave
        _hours = State(initialValue: WeeklyTarget.clamped(initial ?? WeeklyTarget.suggested(pace: actualPace)))
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
                Text(title).lgText(.setupTitle).accessibilityAddTraits(.isHeader)
                    .padding(.top, mode.isSheet ? 12 : 18)
                Text("For the next 12 months, the only distance to cover.")
                    .lgText(.body, color: LGColor.inkMuted)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)

                picker.padding(.top, 34)
                Text("About \(WeeklyTarget.perDay(hours)) · until \(DateText.monthYear(WeeklyTarget.endDate(from: now)))")
                    .lgText(.note, color: LGColor.inkMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)

                // The day's stretch in small: the sun on the sea at the left, a dotted road over to the moon.
                PaceScene()
                    .padding(.horizontal, -24)
                    .padding(.top, 28)
                Text("Each day, a stretch from the sea to the moon.")
                    .lgText(.caption, color: LGColor.inkMuted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 2)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) { actions }
        .lgSetupScreen()
        .navigationBarBackButtonHidden()
        .lgHidesNavigationBar()
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

/// The small picture on "Your weekly pace" (WeeklyPace.dc.html, a 390 × 180 box): a day sky glowing on the left,
/// the dotted road to the moon, and a small sun half in the sea.
private struct PaceScene: View {
    var body: some View {
        GeometryReader { geo in
            let k = geo.size.width / 390
            ZStack(alignment: .topLeading) {
                SkyView(tone: .day, horizon: 0.62, glowX: 0.2)
                    .frame(width: geo.size.width, height: 170)
                Path { p in
                    p.move(to: CGPoint(x: 60 * k, y: 52))
                    p.addCurve(to: CGPoint(x: 336 * k, y: 72), control1: CGPoint(x: 120 * k, y: 2), control2: CGPoint(x: 280 * k, y: 8))
                }
                .stroke(LGColor.arcDots, style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [2, 8]))
                MoonShape().fill(LGColor.moon)
                    .frame(width: 40, height: 40)
                    .offset(x: 336 * k - 21, y: 42)
                SunView(idle: false, face: .happy)
                    .frame(width: 60, height: 60)
                    // Higher than on the board (74), where the left dune would hide it: here it rests on the ridge.
                    .offset(x: 30 * k, y: 22)
                LandView(tone: .day)
                    .frame(width: geo.size.width, height: 120)
                    .offset(y: 60)
            }
        }
        .frame(height: 180)
        .clipped()
        .accessibilityHidden(true)
    }
}

#Preview("Your pace for the year") {
    NavigationStack {
        WeeklyTargetView(mode: .onboarding, actualPace: 12) { _ in }
    }
}
