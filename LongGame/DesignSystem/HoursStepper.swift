import SwiftUI

// Every place that picks a number of hours uses these: a row (− value +) and a big stepper with quick picks.
// Tap steps once, hold repeats (see HoldRepeater), tapping the number opens a small entry sheet, and each stepper is
// one adjustable element for VoiceOver. The maths is in Logic/HoursStepping.swift.

// MARK: The round − and + button

/// Reports the finger going down and up, so a hold can be driven from the press state.
private struct PressReportingStyle: ButtonStyle {
    let onChange: (Bool) -> Void
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, pressed in onChange(pressed) }
    }
}

private struct StepButton: View {
    let direction: Int
    let diameter: CGFloat
    let atLimit: Bool
    /// Takes one step; false when the value is already at the limit.
    let perform: () -> Bool

    @State private var holdTask: Task<Void, Never>?
    @State private var repeated = false
    @State private var stepTick = 0
    @State private var limitTick = 0

    private var symbol: String { direction < 0 ? "minus" : "plus" }

    var body: some View {
        Button {
            // A hold already did its steps; the lift is not one more tap.
            if repeated { repeated = false; return }
            step()
        } label: {
            circle
                .frame(width: max(diameter, 44), height: max(diameter, 44))
                .contentShape(Rectangle())
        }
        .buttonStyle(PressReportingStyle { pressed in pressed ? beginHold() : endHold() })
        .accessibilityHidden(true)
        .accessibilityInputLabels([direction < 0 ? "Minus" : "Plus"])
        .sensoryFeedback(.selection, trigger: stepTick)
        .sensoryFeedback(.impact(flexibility: .rigid), trigger: limitTick)
        .onDisappear { endHold() }
    }

    private var circle: some View { LGStepCircle(systemName: symbol, diameter: diameter, dimmed: atLimit) }

    @discardableResult private func step() -> Bool {
        if perform() { stepTick += 1; return true }
        limitTick += 1
        return false
    }

    private func beginHold() {
        endHold()
        repeated = false
        holdTask = Task { @MainActor in
            var repeater = HoldRepeater(clock: { ProcessInfo.processInfo.systemUptime })
            repeater.begin()
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(20))
                guard !Task.isCancelled else { break }
                for _ in 0..<repeater.stepsDue() {
                    repeated = true
                    if !step() { return }   // the rigid tap says "that's the limit", then the hold stops
                }
            }
        }
    }

    private func endHold() {
        holdTask?.cancel()
        holdTask = nil
    }
}

// MARK: Entry sheet

/// "Tap the number": the label, the value with a caret, "0 to 168", Done and a number pad.
struct HoursEntrySheet: View {
    let label: String
    let value: Double
    let spec: HoursStepSpec
    let onCommit: (Double) -> Void

    @State private var text = ""
    @FocusState private var focused: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 14) {
            Text(label).lgText(.rowStrong, color: LGColor.inkMuted)
                .multilineTextAlignment(.center)
            TextField("", text: $text)
                .keyboardType(spec.needsDecimals ? .decimalPad : .numberPad)
                .focused($focused)
                .multilineTextAlignment(.center)
                .lgNumber(.yearNumber)
                .tint(LGColor.ink)
                .accessibilityLabel(label)
            Text("\(HoursStepping.text(spec.range.lowerBound)) to \(HoursStepping.text(spec.range.upperBound))")
                .lgText(.caption, color: LGColor.inkMuted)
            Button("Done") {
                // Empty (or not a number) means unchanged; out of range snaps to the nearest limit.
                if let typed = HoursStepping.parse(text, spec) { onCommit(typed) }
                dismiss()
            }
            .buttonStyle(.lg(.primary))
        }
        .padding(.horizontal, 24).padding(.top, 28).padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(LGColor.background)
        .presentationDetents([.height(340)])
        .presentationDragIndicator(.visible)
        .onAppear {
            text = HoursStepping.text(value)
            focused = true
        }
    }
}

// MARK: Shared behaviour

/// What both steppers do with a value; keeps the row and the big stepper identical.
private struct StepperBehaviour: ViewModifier {
    @Binding var value: Double
    let spec: HoursStepSpec
    let label: String
    let spoken: String
    @Binding var typing: Bool

    func body(content: Content) -> some View {
        let atMin = HoursStepping.atLimit(value, direction: -1, spec)
        let atMax = HoursStepping.atLimit(value, direction: 1, spec)
        content
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityValue(atMax ? "\(spoken), \(String(localized: "Maximum"))"
                                : atMin ? "\(spoken), \(String(localized: "Minimum"))" : spoken)
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: value = HoursStepping.stepped(value, direction: 1, spec)
                case .decrement: value = HoursStepping.stepped(value, direction: -1, spec)
                @unknown default: break
                }
            }
            .accessibilityAction(named: Text("Type a number")) { typing = true }
    }
}

private func stepAction(_ value: Binding<Double>, _ direction: Int, _ spec: HoursStepSpec) -> () -> Bool {
    {
        guard !HoursStepping.atLimit(value.wrappedValue, direction: direction, spec) else { return false }
        value.wrappedValue = HoursStepping.stepped(value.wrappedValue, direction: direction, spec)
        return true
    }
}

extension Binding where Value == Int {
    /// A whole-hour number as the Double the steppers work in.
    var asHours: Binding<Double> {
        Binding<Double>(get: { Double(wrappedValue) }, set: { wrappedValue = Int($0.rounded()) })
    }
}

// MARK: Row stepper

/// Label (and optional sub-line) on the left, then − value +. At accessibility sizes the label sits above the group.
struct HoursStepperRow: View {
    let label: String
    var subLabel: String?
    @Binding var value: Double
    var spec: HoursStepSpec = .wholeHours
    /// The year being changed gets #FFF3D6 behind its value.
    var isHighlighted = false
    /// What VoiceOver says for the value, e.g. "10 hours a week".
    var spoken: ((Double) -> String)?

    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var typing = false

    private var spokenValue: String { spoken?(value) ?? Self.defaultSpoken(value) }

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) { labels; control }
            } else {
                HStack(spacing: 4) { labels; Spacer(minLength: 8); control }
            }
        }
        .modifier(StepperBehaviour(value: $value, spec: spec, label: label, spoken: spokenValue, typing: $typing))
        .sheet(isPresented: $typing) {
            HoursEntrySheet(label: label, value: value, spec: spec) { value = $0 }
        }
    }

    private var labels: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).lgText(.rowStrong).monospacedDigit()
            if let subLabel { Text(subLabel).lgText(.caption, color: LGColor.inkMuted) }
        }
    }

    private var control: some View {
        HStack(spacing: 0) {
            StepButton(direction: -1, diameter: 36, atLimit: HoursStepping.atLimit(value, direction: -1, spec),
                       perform: stepAction($value, -1, spec))
            Button { typing = true } label: {
                Text("\(WeeklyTarget.number(value)) h")
                    .lgText(LGTextStyle(size: 17, weight: .semibold, relativeTo: .body))
                    .monospacedDigit()
                    .frame(minWidth: 58, minHeight: 36)
                    .background(isHighlighted ? LGColor.stepperHighlight : .clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHidden(true)
            StepButton(direction: 1, diameter: 36, atLimit: HoursStepping.atLimit(value, direction: 1, spec),
                       perform: stepAction($value, 1, spec))
        }
    }

    static func defaultSpoken(_ value: Double) -> String {
        "\(WeeklyTarget.number(value)) " + (value == 1 ? String(localized: "hour a week") : String(localized: "hours a week"))
    }
}

// MARK: Big stepper

struct HoursQuickPick: Identifiable {
    let title: String
    let value: Double
    var id: String { title }
}

/// 56 pt − and + either side of the big number, the unit under it, and optional quick-pick chips under that (only Catch-up passes them).
struct HoursBigStepper: View {
    let label: String
    @Binding var value: Double
    var spec: HoursStepSpec = .wholeHours
    let unit: String
    var quickPicks: [HoursQuickPick] = []
    var spoken: ((Double) -> String)?

    @State private var typing = false

    private var spokenValue: String { spoken?(value) ?? HoursStepperRow.defaultSpoken(value) }

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    StepButton(direction: -1, diameter: 56, atLimit: HoursStepping.atLimit(value, direction: -1, spec),
                               perform: stepAction($value, -1, spec))
                    Button { typing = true } label: {
                        VStack(spacing: 2) {
                            Text(WeeklyTarget.number(value)).lgNumber(.yearNumber)
                            Text(unit).lgText(.row, color: LGColor.inkMuted)
                        }
                        .frame(maxWidth: .infinity, minHeight: 88)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHidden(true)
                    StepButton(direction: 1, diameter: 56, atLimit: HoursStepping.atLimit(value, direction: 1, spec),
                               perform: stepAction($value, 1, spec))
                }
                // The chips are real buttons, so only the − number + group is the single adjustable element.
                .modifier(StepperBehaviour(value: $value, spec: spec, label: label, spoken: spokenValue, typing: $typing))
                if !quickPicks.isEmpty { chips }
            }
        }
        .sheet(isPresented: $typing) {
            HoursEntrySheet(label: label, value: value, spec: spec) { value = $0 }
        }
    }

    private var chips: some View {
        FlowLayout(spacing: 8, centred: true) {
            ForEach(quickPicks) { pick in
                let selected = HoursStepping.clamped(value, spec) == HoursStepping.clamped(pick.value, spec)
                Button { value = HoursStepping.clamped(pick.value, spec) } label: {
                    Text(pick.title)
                        .lgText(LGTextStyle(size: 14, weight: selected ? .semibold : .medium, relativeTo: .subheadline),
                                color: selected ? .white : LGColor.ink)
                        .padding(.horizontal, 16).frame(minHeight: 40)
                        .background {
                            Capsule().fill(selected ? LGColor.ink : LGColor.surface)
                                .shadow(color: LGColor.ink.opacity(selected ? 0 : 0.06), radius: 5, y: 3)
                        }
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

// MARK: Previews

private struct StepperPreviewBench: View {
    @State var low = 0.0
    @State var high = 168.0
    @State var middle = 10.0
    @State var pace = 8.0
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 0) {
                    HoursStepperRow(label: "2021", value: $low)
                    HoursStepperRow(label: "2022", value: $middle, isHighlighted: true)
                    HoursStepperRow(label: "2023", subLabel: "Sub-line", value: $high)
                }
                .padding(.horizontal, 18).lgCard()
                HoursBigStepper(label: "Hours a week", value: $pace, spec: .pace, unit: "hours a week")
                HoursBigStepper(label: "Hours a week", value: $low, unit: "hours a week")
                HoursBigStepper(label: "Hours a week", value: $high, unit: "hours a week")
            }
            .padding(24)
        }
        .lgScreen()
    }
}

#Preview("Steppers · default size") { StepperPreviewBench() }
#Preview("Steppers · AX5") { StepperPreviewBench().dynamicTypeSize(.accessibility5) }
#Preview("Steppers · flat look") { StepperPreviewBench().environment(\.lgFlat, true) }
#Preview("Steppers · over a night sky") {
    ZStack {
        LinearGradient(colors: [LGColor.ink, Color(hex: 0x2B2A5C)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
        StepperPreviewBench().scrollContentBackground(.hidden).background(.clear)
    }
}
