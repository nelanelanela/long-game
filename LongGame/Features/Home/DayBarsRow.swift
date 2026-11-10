import SwiftUI

/// The seven small bars of the This week tab between two hairlines: taller with more hours, coloured like the
/// calendar levels (rest days light blue, days to come light grey), today's letter in bold. Tapping a day that has
/// begun opens it in History.
struct DayBarsRow: View {
    let bars: [DayBar]
    let onSelect: (Date) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(bars, id: \.day) { bar in
                column(bar)
            }
        }
        .padding(.horizontal, 6)
        .padding(.top, 12).padding(.bottom, 8)
        .overlay(alignment: .top) { Rectangle().fill(LGColor.hairline).frame(height: 1) }
        .overlay(alignment: .bottom) { Rectangle().fill(LGColor.hairline).frame(height: 1) }
    }

    /// Played days are a gold bar that grows with the hours (2.5 h fills the 64 pt box); a rest day is a small blue
    /// dot; a day that hasn't been played yet is a short grey dash. Each sits in a dashed outline, the day's plan.
    @ViewBuilder
    private func mark(_ bar: DayBar) -> some View {
        if bar.hours > 0 && !bar.isFuture {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0xFFD45A), LGColor.amber], startPoint: .top, endPoint: .bottom))
                .frame(width: 22, height: max(6, min(64, CGFloat(bar.hours / 2.5) * 64)))
                .shadow(color: LGColor.amber.opacity(0.35), radius: 5, y: 4)
        } else if bar.isFuture || bar.isToday {
            RoundedRectangle(cornerRadius: 3, style: .continuous).fill(LGColor.chipBorder).frame(width: 14, height: 4)
        } else {
            RoundedRectangle(cornerRadius: 3, style: .continuous).fill(LGColor.rest).frame(width: 6, height: 6)
        }
    }

    @ViewBuilder
    private func column(_ bar: DayBar) -> some View {
        let content = VStack(spacing: 6) {
            ZStack(alignment: .bottom) {
                Color.clear.frame(width: 22, height: 64)
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

        if bar.isFuture {
            // Days to come have nothing to open; the calendar hides them from VoiceOver too.
            content.accessibilityHidden(true)
        } else {
            Button { onSelect(bar.day) } label: { content }
                .buttonStyle(.plain)
                .accessibilityLabel(CalendarTab.spoken(bar.day, seconds: bar.hours * 3600, calendar: .current))
                .accessibilityHint("Opens this day in History")
        }
    }
}
