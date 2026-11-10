import SwiftUI
import SwiftData

/// "Welcome back": asks whether the user kept playing during a break, then spreads
/// the hours they say they played across the days of the gap.
struct CatchUpSheet: View {
    let craft: Craft
    let gap: CatchUp.Gap
    let pace: Double
    /// Called when the sheet closes; the number of hours added (0 if none).
    let onFinish: (Double) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Step { case ask, adding }
    @State private var step: Step = .ask
    @State private var detent: PresentationDetent = .height(560)
    @State private var blockHours: [Int]
    @State private var average: Int
    @State private var finished = false

    init(craft: Craft, gap: CatchUp.Gap, pace: Double, onFinish: @escaping (Double) -> Void) {
        self.craft = craft
        self.gap = gap
        self.pace = pace
        self.onFinish = onFinish
        let start = CatchUp.defaultHours(pace: pace)
        _blockHours = State(initialValue: Array(repeating: start, count: max(1, gap.days / 7)))
        _average = State(initialValue: start)
    }

    private var calendar: Calendar { .current }
    private var blocks: [CatchUp.Block] { CatchUp.blocks(for: gap, calendar: calendar) }

    /// Hours to add for each block (a single block spanning the gap in average mode).
    private var totalHours: Double {
        gap.usesAverage
            ? CatchUp.averageTotal(hoursPerWeek: Double(average), days: gap.days)
            : blockHours.reduce(0, +).asDouble
    }

    var body: some View {
        Group {
            switch step {
            case .ask: ask
            case .adding: gap.usesAverage ? AnyView(averageStep) : AnyView(weeksStep)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            // The question sits on the plain screen colour; the two adding steps get the setup wash.
            if step == .ask { LGColor.background.ignoresSafeArea() }
            else {
                LinearGradient(stops: [.init(color: LGColor.peachWashSetup, location: 0), .init(color: LGColor.background, location: 0.3)],
                               startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            }
        }
        .presentationDetents([.height(560), .large], selection: $detent)
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(30)
        .onDisappear { finish(0) }
    }

    private func finish(_ added: Double) {
        guard !finished else { return }
        finished = true
        onFinish(added)
    }

    // MARK: Ask

    private var ask: some View {
        VStack(spacing: 0) {
            // The day scene with the sun open-eyed, edge to edge under the grabber.
            SceneHero(tone: .day, height: 211, skyHeight: 170, horizon: 0.8, landTop: 91, sunSize: 120, sunTop: 14,
                      eyesOpen: 1, hidden: true)
                .padding(.top, 6)
            VStack(spacing: 10) {
                Text("Welcome back!")
                    .lgText(LGTextStyle(size: 28, weight: .bold, relativeTo: .title, tracking: -0.56))
                    .accessibilityAddTraits(.isHeader)
                Text(question)
                    .lgText(.body, color: LGColor.inkMuted)
                    .lineSpacing(4)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)
            .padding(.top, 10)
            Spacer(minLength: 16)
            VStack(spacing: 2) {
                Button("Yes, let me add it") {
                    withAnimation(reduceMotion ? nil : .default) { step = .adding; detent = .large }
                }
                .buttonStyle(.lg(.primary))
                Button("No, I took a break") { dismiss() }.buttonStyle(.lg(.text))
                Text("Rest is part of the craft.").lgText(.caption, color: LGColor.inkMuted)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
    }

    private var question: String {
        let day = RelativeDay.full(gap.anchor, calendar: calendar)
        let weeks = Labels.weeksAgo(gap.weeks)
        return gap.hasSessions
            ? String(localized: "Your last session was on \(day) — that's \(weeks). Did you practise since then?")
            : String(localized: "You started on \(day) — that's \(weeks). Did you practise since then?")
    }

    // MARK: Weeks (7–27 days)

    private var weeksStep: some View {
        let blocks = blocks
        return VStack(spacing: 0) {
            addingBar
            stepHeader(title: String(localized: "How much did you play each week?"),
                       subtitle: String(localized: "A rough guess is fine. The hours are spread across the days."))
            VStack(spacing: 0) {
                ForEach(Array(blocks.enumerated()), id: \.offset) { index, block in
                    let hours = blockHours[index]
                    HoursStepperRow(label: CatchUp.rangeLabel(first: block.first, last: block.last, calendar: calendar),
                                    subLabel: Labels.days(block.days) + " · " + Labels.aboutPerDay(
                                        minutes: CatchUp.minutesPerDay(totalHours: Double(hours), days: block.days)),
                                    value: Binding(get: { Double(hours) }, set: { blockHours[index] = Int($0.rounded()) }))
                        .padding(.vertical, 12)
                    if index < blocks.count - 1 { Divider().overlay(LGColor.divider) }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 2)
            .lgCard(radius: 22)
            .padding(.top, 18)
            addingRow.padding(.top, 16)
            Spacer(minLength: 16)
            addButton
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 16)
    }

    // MARK: Average (28+ days)

    private var averageStep: some View {
        let perDay = CatchUp.minutesPerDay(totalHours: totalHours, days: gap.days)
        return VStack(spacing: 0) {
            addingBar
            stepHeader(title: Labels.weeksHavePassed(gap.weeks) + ".",
                       subtitle: String(localized: "Since \(CatchUp.longDay(gap.anchor, calendar: calendar)). On average, how many hours a week did you practise?"))
            // No card: the big number sits straight on the wash, the quick picks under it.
            HoursBigStepper(label: String(localized: "Average hours per week"),
                            value: Binding(get: { Double(average) }, set: { average = Int($0.rounded()) }),
                            unit: String(localized: "hours a week"),
                            quickPicks: averagePicks)
                .padding(.top, 30)
            VStack(spacing: 0) {
                summaryRow("Period", CatchUp.rangeLabel(first: gap.first, last: gap.last, calendar: calendar) + " · " + Labels.days(gap.days))
                Divider().overlay(LGColor.divider)
                summaryRow("Per day in calendar", DurationFormat.short(seconds: Double(perDay) * 60))
                Divider().overlay(LGColor.divider)
                summaryRow("Adding", DurationFormat.hours(totalHours), strong: true)
            }
            .padding(.horizontal, 16).padding(.vertical, 2)
            .lgCard(radius: 22)
            .padding(.top, 24)
            Spacer(minLength: 16)
            addButton
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 16)
    }

    /// "Your usual · N", 0, 5 and 10.
    private var averagePicks: [HoursQuickPick] {
        let usual = Double(CatchUp.defaultHours(pace: pace))
        return [HoursQuickPick(title: String(localized: "Your usual · \(Int(usual))"), value: usual)]
            + [0.0, 5, 10].map { HoursQuickPick(title: "\(Int($0))", value: $0) }
    }

    // MARK: Shared pieces

    /// Back to the question on the left, "Catch up" in the middle.
    private var addingBar: some View {
        ZStack {
            Text("Catch up").lgText(.navTitle)
            HStack {
                LGIconButton(systemName: "chevron.left", label: "Back") {
                    withAnimation(reduceMotion ? nil : .default) { step = .ask }
                }
                .padding(.leading, -10)
                Spacer()
            }
        }
        .frame(height: 44)
    }

    private func stepHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .lgText(LGTextStyle(size: 28, weight: .bold, relativeTo: .title, tracking: -0.56))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(subtitle).lgText(.row, color: LGColor.inkMuted).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 12)
    }

    private func summaryRow(_ title: String, _ value: String, strong: Bool = false) -> some View {
        HStack {
            Text(title).lgText(.row, color: LGColor.inkMuted)
            Spacer()
            Text(value).lgText(strong ? LGTextStyle.statFigure : .rowStrong)
        }
        .frame(minHeight: 48)
        .accessibilityElement(children: .combine)
    }

    private var addingRow: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Adding").lgText(.row, color: LGColor.inkMuted)
            Spacer()
            Text(DurationFormat.hours(totalHours)).lgText(LGTextStyle(size: 28, weight: .bold, relativeTo: .title2, tracking: -0.56)).monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }

    private var addButton: some View {
        let whole = Int(totalHours.rounded())
        return Button(Labels.addHours(whole)) { save() }
            .buttonStyle(.lg(.primary))
            .disabled(totalHours <= 0)
    }

    // MARK: Saving

    private func save() {
        let plan: [(day: Date, minutes: Int)]
        if gap.usesAverage {
            plan = CatchUp.plan(days: CatchUp.days(from: gap.first, count: gap.days, calendar: calendar), totalHours: totalHours)
        } else {
            plan = zip(blocks, blockHours).flatMap { block, hours in
                CatchUp.plan(days: CatchUp.days(from: block.first, count: block.days, calendar: calendar), totalHours: Double(hours))
            }
        }
        var addedSeconds = 0.0
        for entry in plan where entry.minutes > 0 {
            let seconds = Double(entry.minutes) * 60
            context.insert(Session(craftId: craft.id, start: CatchUp.noon(of: entry.day, calendar: calendar),
                                   durationSec: seconds, source: .catchUp))
            addedSeconds += seconds
        }
        try? context.save()
        finish(addedSeconds / 3600)
        dismiss()
    }
}

private extension Int {
    var asDouble: Double { Double(self) }
}
