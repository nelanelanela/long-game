import Foundation

// The maths behind the − and + hour steppers: stepping, typed values and hold-to-repeat.
// Pure functions only; the buttons themselves are in DesignSystem/HoursStepper.swift.

/// A range and a step size: 0 to 168 in whole hours, or 1 to 168 in halves for the weekly target.
struct HoursStepSpec: Equatable, Sendable {
    var range: ClosedRange<Double>
    var step: Double

    /// Yearly rows and both Catch-up screens.
    static let wholeHours = HoursStepSpec(range: 0...WeeklyTarget.maxHours, step: 1)
    /// Your pace for the year.
    static let pace = HoursStepSpec(range: WeeklyTarget.range, step: WeeklyTarget.step)

    /// Half-hour steps need a decimal pad.
    var needsDecimals: Bool { step.truncatingRemainder(dividingBy: 1) != 0 }
}

enum HoursStepping {
    /// Into the range, on the step grid.
    static func clamped(_ value: Double, _ spec: HoursStepSpec) -> Double {
        let snapped = (value / spec.step).rounded() * spec.step
        return min(spec.range.upperBound, max(spec.range.lowerBound, snapped))
    }

    /// One step up (+1) or down (-1), stopping at the limits.
    static func stepped(_ value: Double, direction: Int, _ spec: HoursStepSpec) -> Double {
        clamped(clamped(value, spec) + Double(direction) * spec.step, spec)
    }

    /// True when a step in that direction would do nothing: the button turns pale.
    static func atLimit(_ value: Double, direction: Int, _ spec: HoursStepSpec) -> Bool {
        let now = clamped(value, spec)
        return direction < 0 ? now <= spec.range.lowerBound : now >= spec.range.upperBound
    }

    /// What was typed in the entry sheet. Nil means "leave the value as it is" (empty or not a number);
    /// anything out of range snaps to the nearest limit. The decimal mark follows the locale.
    static func parse(_ text: String, _ spec: HoursStepSpec, locale: Locale = .current) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        guard let number = formatter.number(from: trimmed)?.doubleValue, number.isFinite else { return nil }
        return clamped(number, spec)
    }

    /// "7" or "7.5" (the locale's mark) for the entry field.
    static func text(_ value: Double, locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }
}

/// Hold-to-repeat: nothing for 0.4 s, then 6 steps a second, and from 1.5 s 12 a second.
/// The clock is injected so tests can move time without waiting.
struct HoldRepeater {
    static let delay: TimeInterval = 0.4
    static let fasterAfter: TimeInterval = 1.5
    static let slowRate = 6.0
    static let fastRate = 12.0

    private let clock: () -> TimeInterval
    private var startedAt: TimeInterval?
    private var emitted = 0

    init(clock: @escaping () -> TimeInterval) { self.clock = clock }

    /// Call when the finger goes down.
    mutating func begin() {
        startedAt = clock()
        emitted = 0
    }

    /// Call when it lifts.
    mutating func end() { startedAt = nil }

    var isHolding: Bool { startedAt != nil }

    /// The repeat steps owed in total after holding this long.
    static func totalSteps(heldFor held: TimeInterval) -> Int {
        guard held >= delay else { return 0 }
        let slowSpan = min(held, fasterAfter) - delay
        var total = 1 + Int((slowSpan * slowRate + 1e-9).rounded(.down))
        if held > fasterAfter { total += Int(((held - fasterAfter) * fastRate + 1e-9).rounded(.down)) }
        return total
    }

    /// How many new steps to take now (0 when not holding).
    mutating func stepsDue() -> Int {
        guard let startedAt else { return 0 }
        let total = Self.totalSteps(heldFor: clock() - startedAt)
        defer { emitted = max(emitted, total) }
        return max(0, total - emitted)
    }
}

/// "Use 8 h for the years after 2021": copies one year's hours to every later year, and only those.
enum YearHoursFill {
    static func applying(_ hours: Int, after year: Int, to values: [Int: Int], years: [Int]) -> [Int: Int] {
        var result = values
        for later in years where later > year { result[later] = hours }
        return result
    }

    /// The button shows only when a later year exists.
    static func hasLaterYears(after year: Int, years: [Int]) -> Bool { years.contains { $0 > year } }
}
