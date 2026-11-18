import Foundation

// How long a saved session reads in whole minutes, the same on every screen: seconds are cut off, never rounded
// up ("4 m" for 4 min 40 s in the Today list, and 0 h 4 in Edit session). Pure functions, nothing stored.

enum SessionLength {
    /// Most hours the Edit session form can hold.
    static let maxHours = 12

    /// Whole minutes, seconds cut off.
    static func wholeMinutes(_ seconds: Double) -> Int { Int(max(0, seconds) / 60) }

    /// What the Hours and Minutes steppers start at when a saved session is opened: its exact whole minutes,
    /// not snapped to the 5-minute grid, so opening a session never shows a different length from the list.
    static func fields(seconds: Double) -> (hours: Int, minutes: Int) {
        let total = wholeMinutes(seconds)
        let hours = min(maxHours, total / 60)
        return (hours, hours == maxHours ? 0 : total % 60)
    }

    /// One press of − or + in the form: onto the step grid (minutes 4 → 5 going up, 4 → 0 going down), within range.
    /// A value already past the top (a 57-minute session) stays put going up.
    static func stepped(_ value: Int, up: Bool, step: Int, range: ClosedRange<Int>) -> Int {
        if up && value >= range.upperBound { return value }
        let next = up ? (value / step + 1) * step : (value % step == 0 ? value - step : value / step * step)
        return min(range.upperBound, max(range.lowerBound, next))
    }

    /// Minutes in 5-minute steps, 0…55.
    static func steppedMinutes(_ minutes: Int, up: Bool) -> Int { stepped(minutes, up: up, step: 5, range: 0...55) }

    /// The length to save. When the fields still show what the session opened with, its exact seconds are kept,
    /// so saving a note or photo never shaves off (or adds) a few seconds of practice.
    static func savedSeconds(original: Double, hours: Int, minutes: Int) -> Double {
        let (h, m) = fields(seconds: original)
        return (h, m) == (hours, minutes) ? original : Double(hours * 3600 + minutes * 60)
    }
}
