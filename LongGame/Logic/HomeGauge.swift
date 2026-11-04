import Foundation
import CoreGraphics

// The sun as a gauge: on Home the sun's height shows how far a value has got, on a vertical scale at the left.
// Everything here is plain numbers, so the mapping can be tested without drawing anything.

enum GaugeGeometry {
    /// The hero is as wide as the screen and this tall; the sea takes the bottom 64 pt.
    static let height: CGFloat = 280
    /// The middle of the navy wave line.
    static let waterY: CGFloat = 228
    /// The 0 tick, and the sun's centre at 0: just above the waterline, so the lower half is under the sea.
    static let zeroY: CGFloat = 220
    /// The top tick, and the sun's centre at 100%.
    static let topY: CGFloat = 84
    static let sunSize: CGFloat = 170
    /// The sun sits right of centre to leave room for the scale.
    static let sunOffsetX: CGFloat = 20
    /// The scale line, the pill's left edge and where the dashed line starts.
    static let scaleX: CGFloat = 48
    static let pillX: CGFloat = 58
    static let dashStartX: CGFloat = 52
    /// The line reaches a little above the top tick.
    static let scaleOvershoot: CGFloat = 6

    static func clamped(_ fraction: Double) -> Double { min(1, max(0, fraction)) }

    /// The sun's centre, linear from the horizon (0) to the top tick (1). Above 1 it stays at the top.
    static func centreY(fraction: Double) -> CGFloat {
        zeroY - CGFloat(clamped(fraction)) * (zeroY - topY)
    }
}

/// The same gauge at another size: the phone's, the short window's and the wide pane's. `GaugeGeometry` is the
/// phone's; every other window scales the hero, the sun and the scale from here.
struct GaugeMetrics: Equatable, Sendable {
    var height: CGFloat
    var waterY: CGFloat
    var zeroY: CGFloat
    var topY: CGFloat
    var sunSize: CGFloat
    var sunOffsetX: CGFloat
    var scaleX: CGFloat
    var pillX: CGFloat
    var dashStartX: CGFloat
    var scaleOvershoot: CGFloat = GaugeGeometry.scaleOvershoot

    static let standard = GaugeMetrics(
        height: GaugeGeometry.height, waterY: GaugeGeometry.waterY, zeroY: GaugeGeometry.zeroY, topY: GaugeGeometry.topY,
        sunSize: GaugeGeometry.sunSize, sunOffsetX: GaugeGeometry.sunOffsetX, scaleX: GaugeGeometry.scaleX,
        pillX: GaugeGeometry.pillX, dashStartX: GaugeGeometry.dashStartX)

    /// Windows under 700 pt tall (the Duo closed): a 212 pt hero with a 120 pt sun.
    static let short = GaugeMetrics(
        height: 212, waterY: 160, zeroY: 152, topY: 68, sunSize: 120, sunOffsetX: 20, scaleX: 46, pillX: 56, dashStartX: 50)

    /// The wide window's left pane, `height` tall (clamped to `WideGauge`), with a 150 pt sun. `leadingInset` is the
    /// safe area on the left (the Dynamic Island when the phone is open): the scale and the pill start beyond it.
    static func wide(height: CGFloat, leadingInset: CGFloat = 0) -> GaugeMetrics {
        let h = min(WideGauge.maxHeight, max(WideGauge.minHeight, height))
        let sun: CGFloat = h < 300 ? 120 : 150
        let water = h - 52
        let x = max(48, leadingInset + 20)
        return GaugeMetrics(
            height: h, waterY: water, zeroY: water - 8, topY: sun / 2 + 8, sunSize: sun, sunOffsetX: 34,
            scaleX: x + 42, pillX: x + 52, dashStartX: x + 46)
    }

    func centreY(fraction: Double) -> CGFloat {
        zeroY - CGFloat(GaugeGeometry.clamped(fraction)) * (zeroY - topY)
    }
}

struct GaugeTick: Equatable, Sendable {
    /// 0...1 up the scale.
    var fraction: Double
    var label: String
}

/// What the hero shows on one Home tab: the value, where it sits on the scale and how it is labelled.
struct HomeGauge: Equatable, Sendable {
    var tab: HomeTab
    var value: Double
    var maximum: Double
    var ticks: [GaugeTick]
    /// The navy pill beside the sun: "6.5 h", "3,294 h".
    var pill: String
    /// Read out by VoiceOver for the whole hero.
    var description: String

    /// 0...1: how high the sun is.
    var fraction: Double { maximum > 0 ? GaugeGeometry.clamped(value / maximum) : 0 }
    /// At or above the top the sun stays up there and opens its eyes (celebrate face, no peeking).
    var reachedTop: Bool { maximum > 0 && value >= maximum }

    /// This week: 0 → the weekly target, ticks at 0, half and the target.
    static func week(hours: Double, target: Double) -> HomeGauge {
        let target = max(0.5, target)
        let gauge = HomeGauge(
            tab: .week, value: max(0, hours), maximum: target,
            ticks: [GaugeTick(fraction: 0, label: DurationFormat.hours(0)),
                    GaugeTick(fraction: 0.5, label: DurationFormat.hours(target / 2)),
                    GaugeTick(fraction: 1, label: DurationFormat.hours(target))],
            pill: DurationFormat.hours(max(0, hours)), description: "")
        return gauge.describing("This week", value: WeeklyTarget.number(max(0, hours)), of: WeeklyTarget.number(target))
    }

    /// The long game: 0 → 10,000 h, ticks every 2,500.
    static func longGame(total: Double) -> HomeGauge {
        let whole = Totals.wholeHours(total: total)
        let gauge = HomeGauge(
            tab: .longGame, value: max(0, total), maximum: Totals.goalHours,
            ticks: [0, 2_500, 5_000, 7_500, 10_000].map { GaugeTick(fraction: $0 / Totals.goalHours, label: thousands($0)) },
            pill: "\(DurationFormat.grouped(whole)) h", description: "")
        return gauge.describing("The long game", value: DurationFormat.grouped(whole), of: DurationFormat.grouped(Int(Totals.goalHours)))
    }

    /// Today: the sun on an arc, no scale. `value`/`maximum` are seconds-free shares so `fraction` is the arc position.
    static func today(_ state: StretchState) -> HomeGauge {
        HomeGauge(tab: .today, value: state.fraction, maximum: 1, ticks: [], pill: "",
                  description: StretchText.description(state))
    }

    /// "0", "2.5k", "5k", "10k"
    static func thousands(_ hours: Double) -> String {
        guard hours > 0 else { return "0" }
        let k = hours / 1_000
        return (k == k.rounded() ? String(Int(k)) : String(format: "%.1f", k)) + "k"
    }

    private func describing(_ name: String, value shown: String, of max: String) -> HomeGauge {
        var copy = self
        copy.description = reachedTop
            ? "\(name): the sun has reached the top, \(shown) of \(max) hours"
            : "\(name): the sun is \(Int((fraction * 100).rounded()))% of the way up, \(shown) of \(max) hours"
        return copy
    }
}

/// One of the seven small bars on the This week tab.
struct DayBar: Equatable, Sendable {
    var day: Date
    var hours: Double
    var level: CalendarLevel
    var isToday: Bool
    var isFuture: Bool
    /// "M", "T", "W"…
    var letter: String

    static let minHeight: CGFloat = 4
    static let maxHeight: CGFloat = 39

    /// Taller with more hours: 4 pt for a rest day, 39 pt from four hours up.
    var height: CGFloat {
        guard !isFuture, hours > 0 else { return Self.minHeight }
        return Self.minHeight + (Self.maxHeight - Self.minHeight) * CGFloat(min(hours, 4) / 4)
    }
}

enum WeekBars {
    /// The days of the current week (Mon–Sun or Sun–Sat), coloured like the calendar levels. Days before today
    /// with nothing logged are rest days; days after today are future days.
    static func make(sessions: [SessionRecord], now: Date, weekStart: WeekStart, calendar: Calendar = .current) -> [DayBar] {
        let cal = WeekMath.calendar(calendar, weekStart: weekStart)
        let start = WeekMath.startOfWeek(now, weekStart: weekStart, calendar: calendar)
        let today = cal.startOfDay(for: now)
        let daily = Practice.dailySeconds(sessions, calendar: cal)
        let letters = DateFormatter()
        letters.locale = Locale(identifier: "en_GB")
        letters.calendar = cal
        letters.timeZone = cal.timeZone
        letters.dateFormat = "EEEEE"
        return (0..<7).compactMap { offset in
            guard let day = cal.date(byAdding: .day, value: offset, to: start) else { return nil }
            let hours = (daily[day] ?? 0) / 3600
            return DayBar(day: day, hours: hours, level: CalendarLevel.level(hours: hours),
                          isToday: day == today, isFuture: day > today, letter: letters.string(from: day))
        }
    }
}
