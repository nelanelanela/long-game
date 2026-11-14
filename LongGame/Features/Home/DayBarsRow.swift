import SwiftUI

/// The seven small bars of the This week tab between two hairlines: taller with more hours, coloured like the
/// calendar levels (rest days light blue, days to come light grey), today's letter in bold. Tapping a day that has
/// begun opens it in History.
struct DayBarsRow: View {
    let bars: [DayBar]
    /// Last week's hours for the same weekdays (`WeekBars.lastWeek`), drawn faintly behind; nil hides them and the key.
    var lastWeek: [Double]? = nil
    let onSelect: (Date) -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ForEach(Array(bars.enumerated()), id: \.element.day) { i, bar in
                    column(bar, last: lastWeek.flatMap { $0.indices.contains(i) ? $0[i] : nil })
                }
            }
            .padding(.horizontal, 6)
            .padding(.top, 12).padding(.bottom, 8)
            .overlay(alignment: .top) { Rectangle().fill(LGColor.hairline).frame(height: 1) }
            .overlay(alignment: .bottom) { Rectangle().fill(LGColor.hairline).frame(height: 1) }

            if lastWeek != nil { key }
        }
    }

    /// "▭ Last week  ▭ This week".
    private var key: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 3, style: .continuous).fill(LGColor.lastWeekBar.opacity(1.25)).frame(width: 14, height: 10)
            Text("Last week")
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(LinearGradient(colors: [LGColor.dayBarTop, LGColor.amber], startPoint: .top, endPoint: .bottom))
                .frame(width: 14, height: 10)
                .padding(.leading, 8)
            Text("This week")
        }
        .lgText(LGTextStyle(size: 12, weight: .regular, relativeTo: .caption), color: LGColor.inkMuted)
        .accessibilityHidden(true)
    }

    /// Played days are a gold bar that grows with the hours (2.5 h fills the 64 pt box); a rest day is a small blue
    /// dot; a day that hasn't been played yet is a short grey dash. Each sits in a dashed outline, the day's plan.
    @ViewBuilder
    private func mark(_ bar: DayBar) -> some View {
        if bar.hours > 0 && !bar.isFuture {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(LinearGradient(colors: [LGColor.dayBarTop, LGColor.amber], startPoint: .top, endPoint: .bottom))
                .frame(width: 22, height: max(6, CGFloat(WeekBars.barHeight(hours: bar.hours))))
                .shadow(color: LGColor.amber.opacity(0.35), radius: 5, y: 4)
        } else if bar.isFuture || bar.isToday {
            RoundedRectangle(cornerRadius: 3, style: .continuous).fill(LGColor.chipBorder).frame(width: 14, height: 4)
        } else {
            RoundedRectangle(cornerRadius: 3, style: .continuous).fill(LGColor.rest).frame(width: 6, height: 6)
        }
    }

    @ViewBuilder
    private func column(_ bar: DayBar, last: Double?) -> some View {
        let content = VStack(spacing: 6) {
            ZStack(alignment: .bottom) {
                Color.clear.frame(width: 30, height: 64)
                // The same weekday last week, faint, on the same scale.
                if let last, last > 0 {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(LGColor.lastWeekBar)
                        .frame(width: 30, height: CGFloat(WeekBars.barHeight(hours: last)))
                }
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Color(hex: 0xCFC6B6), style: StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
                    .frame(width: 22, height: 44)
                mark(bar)
            }
            Text(verbatim: bar.letter)
                .lgText(LGTextStyle(size: 12, weight: bar.isToday ? .bold : .medium, relativeTo: .caption),
                        color: bar.isToday ? LGColor.ink : LGColor.inkMuted)
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .contentShape(Rectangle())

        if bar.isFuture, last != nil {
            // A day to come still has last week's bar to read.
            content.accessibilityElement(children: .ignore).accessibilityLabel(spoken(bar, last: last))
        } else if bar.isFuture {
            // Days to come have nothing to open; the calendar hides them from VoiceOver too.
            content.accessibilityHidden(true)
        } else {
            Button { onSelect(bar.day) } label: { content }
                .buttonStyle(.plain)
                .accessibilityLabel(spoken(bar, last: last))
                .accessibilityHint("Opens this day in History")
        }
    }

    /// "Thursday, 1 hour 30. Last Thursday, 2 hours." (without the second part when last week isn't shown).
    private func spoken(_ bar: DayBar, last: Double?) -> String {
        let name = CachedFormatter.pattern("EEEE", calendar: .current).string(from: bar.day)
        let this = bar.isFuture ? String(localized: "not yet") : (bar.hours > 0 ? StretchText.spoken(seconds: (bar.hours * 3600).rounded()) : String(localized: "rest day"))
        guard let last else { return CalendarTab.spoken(bar.day, seconds: bar.hours * 3600, calendar: .current) }
        let lastText = last > 0 ? StretchText.spoken(seconds: (last * 3600).rounded()) : String(localized: "rest day")
        return String(localized: "\(name), \(this). Last \(name), \(lastText).")
    }
}
