import SwiftUI

/// The seven small bars of the This week tab between two hairlines: taller with more hours, coloured like the
/// calendar levels (rest days light blue, days to come light grey), today's letter in bold. Tapping a day that has
/// begun opens it in History.
struct DayBarsRow: View {
    let bars: [DayBar]
    let onSelect: (Date) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(bars, id: \.day) { bar in
                column(bar)
            }
        }
        .padding(.vertical, 12)
        .overlay(alignment: .top) { Rectangle().fill(LGColor.hairline).frame(height: 1) }
        .overlay(alignment: .bottom) { Rectangle().fill(LGColor.hairline).frame(height: 1) }
    }

    private func color(_ bar: DayBar) -> Color {
        bar.isFuture ? LGColor.track : LGColor.calendar(bar.level)
    }

    @ViewBuilder
    private func column(_ bar: DayBar) -> some View {
        let content = VStack(spacing: 6) {
            ZStack(alignment: .bottom) {
                Color.clear.frame(height: 40)
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(color(bar))
                    .frame(width: 22, height: bar.height)
            }
            Text(verbatim: bar.letter)
                .lgText(LGTextStyle(size: 12, weight: bar.isToday ? .bold : .medium, relativeTo: .caption),
                        color: bar.isToday ? LGColor.ink : LGColor.gaugeLabel)
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
