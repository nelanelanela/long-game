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

    private enum Step { case ask, adding }
    @State private var step: Step = .ask
    @State private var detent: PresentationDetent = .height(520)
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
        .background(step == .ask ? Color.white : LGColor.background)
        .presentationDetents([.height(520), .large], selection: $detent)
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(32)
        .onDisappear { finish(0) }
    }

    private func finish(_ added: Double) {
        guard !finished else { return }
        finished = true
        onFinish(added)
    }

    // MARK: Ask

    private var ask: some View {
        VStack(spacing: 20) {
            SunView(face: .happy).frame(width: 112, height: 112)
            VStack(spacing: 10) {
                Text("Welcome back!").lgText(.sheetTitle).accessibilityAddTraits(.isHeader)
                Text(question)
                    .lgText(LGTextStyle(size: 16, weight: .regular, relativeTo: .body), color: LGColor.inkMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(spacing: 4) {
                Button("Yes, let me add it") {
                    withAnimation { step = .adding; detent = .large }
                }
                .buttonStyle(.lg(.primary))
                Button("No, I took a break") { dismiss() }.buttonStyle(.lg(.text))
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .padding(.bottom, 12)
    }

    private var question: String {
        let day = RelativeDay.full(gap.anchor, calendar: calendar)
        let weeks = Labels.weeksAgo(gap.weeks)
        return gap.hasSessions
            ? String(localized: "Your last session was on \(day) — that's \(weeks). Did you keep playing since then?")
            : String(localized: "You started on \(day) — that's \(weeks). Did you keep playing since then?")
    }

    // MARK: Weeks (7–27 days)

    private var weeksStep: some View {
        let blocks = blocks
        return VStack(spacing: 18) {
            stepHeader(title: Labels.weeksHavePassed(gap.weeks),
                       subtitle: "Roughly how many hours did you play each week?")
            VStack(spacing: 0) {
                ForEach(Array(blocks.enumerated()), id: \.offset) { index, block in
                    let hours = blockHours[index]
                    VStack(spacing: 10) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(CatchUp.rangeLabel(first: block.first, last: block.last, calendar: calendar))
                                .lgText(.rowStrong)
                            Spacer()
                            Text(Labels.shortHours(hours)).lgText(.rowStrong).monospacedDigit().fixedSize()
                        }
                        Slider(value: Binding(get: { Double(hours) }, set: { blockHours[index] = Int($0) }),
                               in: 0...Double(CatchUp.maxWeeklyHours), step: 1)
                            .tint(LGColor.ink)
                            .accessibilityLabel(CatchUp.rangeLabel(first: block.first, last: block.last, calendar: calendar))
                            .accessibilityValue(Labels.hours(hours))
                        Text(Labels.days(block.days) + " · " + Labels.aboutPerDay(
                            minutes: CatchUp.minutesPerDay(totalHours: Double(hours), days: block.days)))
                            .lgText(.tiny, color: LGColor.inkMuted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, 16)
                    if index < blocks.count - 1 { Divider().overlay(LGColor.divider) }
                }
            }
            .padding(.horizontal, 18)
            .lgCard()
            addingRow
            Text("Each week's hours are spread evenly across its days in your calendar.")
                .lgText(.caption, color: LGColor.inkMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
            Spacer(minLength: 0)
            addButton
        }
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .padding(.bottom, 16)
    }

    // MARK: Average (28+ days)

    private var averageStep: some View {
        let perDay = CatchUp.minutesPerDay(totalHours: totalHours, days: gap.days)
        return VStack(spacing: 18) {
            stepHeader(title: Labels.weeksHavePassed(gap.weeks),
                       subtitle: String(localized: "Since \(CatchUp.longDay(gap.anchor, calendar: calendar)). On average, how many hours a week did you play?"))
            VStack(spacing: 8) {
                Text("\(average)").lgNumber(.yearNumber)
                Text("hours per week").lgText(.caption, color: LGColor.inkMuted)
                Slider(value: Binding(get: { Double(average) }, set: { average = Int($0) }),
                       in: 0...Double(CatchUp.maxWeeklyHours), step: 1)
                    .tint(LGColor.ink)
                    .accessibilityLabel("Average hours per week")
                    .accessibilityValue(Labels.hours(average))
                HStack {
                    Text("0"); Spacer(); Text("20"); Spacer(); Text("40")
                }
                .lgText(.tiny, color: LGColor.inkMuted)
                .accessibilityHidden(true)
            }
            .padding(.horizontal, 18).padding(.vertical, 20)
            .lgCard()
            VStack(spacing: 0) {
                summaryRow("Period", CatchUp.rangeLabel(first: gap.first, last: gap.last, calendar: calendar) + " · " + Labels.days(gap.days))
                Divider().overlay(LGColor.divider)
                summaryRow("Per day in calendar", DurationFormat.short(seconds: Double(perDay) * 60))
                Divider().overlay(LGColor.divider)
                summaryRow("Adding", DurationFormat.hours(totalHours))
            }
            .padding(.horizontal, 18)
            .lgCard()
            Spacer(minLength: 0)
            addButton
        }
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .padding(.bottom, 16)
    }

    // MARK: Shared pieces

    private func stepHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).lgText(.sheetTitle).accessibilityAddTraits(.isHeader)
            Text(subtitle).lgText(.body, color: LGColor.inkMuted).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func summaryRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).lgText(.row, color: LGColor.inkMuted)
            Spacer()
            Text(value).lgText(.rowStrong)
        }
        .frame(minHeight: 50)
        .accessibilityElement(children: .combine)
    }

    private var addingRow: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Adding").lgText(.row, color: LGColor.inkMuted)
            Spacer()
            Text(DurationFormat.hours(totalHours)).lgText(LGTextStyle(size: 26, weight: .bold, relativeTo: .title2, tracking: -0.5)).monospacedDigit()
        }
        .padding(.horizontal, 4)
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
