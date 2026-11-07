import SwiftUI

/// How the big number and its caption sit: stacked and centred on a phone, on one line in a short window, stacked
/// and left-aligned in the wide window's right pane.
enum NumberLayout {
    case stacked, inline, leading
    /// iPad: 72 pt centred (portrait), and 64 pt left-aligned under the sidebar layout's sun.
    case tall, sidebar

    var isLeading: Bool { self == .leading || self == .sidebar }

    var numberStyle: LGTextStyle {
        switch self {
        case .inline: .gaugeNumberShort
        case .tall: .gaugeNumberTall
        case .sidebar: .gaugeNumberSidebar
        default: .gaugeNumber
        }
    }

    @ViewBuilder
    func container<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        switch self {
        case .stacked, .tall: VStack(spacing: 4, content: content)
        case .leading, .sidebar: VStack(alignment: .leading, spacing: 4, content: content)
        case .inline: HStack(alignment: .firstTextBaseline, spacing: 8, content: content)
        }
    }
}

/// The big total and its percentage under the sun on The long game tab; interpolates smoothly when animated.
struct CountingTotal: View, Animatable {
    var value: Double
    var style: NumberLayout = .stacked
    nonisolated var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        style.container {
            Text(DurationFormat.grouped(Totals.wholeHours(total: value))).lgNumber(style.numberStyle)
            Text(style == .inline ? "of 10,000 h · \(Totals.percent(total: value))%"
                                  : "of 10,000 hours · \(Totals.percent(total: value))%")
                .lgText(.row, color: LGColor.inkMuted)
        }
    }
}

/// The big number of hours this week and how far that is towards the target, on the This week tab.
/// Interpolates smoothly when the count-up after a saved session animates it.
struct CountingWeek: View, Animatable {
    var hours: Double
    let target: Double
    var style: NumberLayout = .stacked
    nonisolated var animatableData: Double {
        get { hours }
        set { hours = newValue }
    }

    var body: some View {
        let percent = WeekTarget(hoursThisWeek: hours, target: target, daysLeft: 0).percent
        style.container {
            Text(DurationFormat.hours(hours)).lgNumber(style.numberStyle)
            Text(style == .inline ? "of \(DurationFormat.hours(target)) · \(percent)%"
                                  : "of \(DurationFormat.hours(target)) this week · \(percent)%")
                .lgText(.row, color: LGColor.inkMuted)
        }
    }
}
