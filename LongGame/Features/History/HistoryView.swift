import SwiftUI
import SwiftData

private enum HistoryTab: String, CaseIterable {
    case calendar = "Calendar"
    case growth = "Growth"
}

struct HistoryView: View {
    let craft: Craft

    @Environment(\.dismiss) private var dismiss
    @Query private var sessions: [Session]
    @Query private var estimates: [YearEstimate]
    @Query private var settingsRows: [AppSettings]
    @State private var tab: HistoryTab = .calendar

    init(craft: Craft) {
        self.craft = craft
        let id = craft.id
        _sessions = Query(filter: #Predicate<Session> { $0.craftId == id }, sort: \Session.start, order: .reverse)
        _estimates = Query(filter: #Predicate<YearEstimate> { $0.craftId == id })
    }

    private var weekStart: WeekStart { settingsRows.first?.weekStart ?? .localeDefault }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    LGIconButton(systemName: "chevron.left", label: "Back") { dismiss() }
                        .padding(.leading, -10)
                    Spacer()
                }
                .frame(height: 44)

                Text("History").lgText(.screenTitle)
                    .padding(.top, -6)
                    .accessibilityAddTraits(.isHeader)

                picker

                switch tab {
                case .calendar:
                    CalendarTab(craft: craft, sessions: sessions, weekStart: weekStart)
                case .growth:
                    GrowthTab(craft: craft, sessions: sessions, estimates: estimates, weekStart: weekStart)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .lgScreen()
        .toolbar(.hidden, for: .navigationBar)
    }

    private var picker: some View {
        HStack(spacing: 0) {
            ForEach(HistoryTab.allCases, id: \.self) { item in
                Button { withAnimation(.easeInOut(duration: 0.15)) { tab = item } } label: {
                    Text(item.rawValue)
                        .lgText(LGTextStyle(size: 14, weight: tab == item ? .semibold : .medium, relativeTo: .subheadline))
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background {
                            if tab == item {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(.white)
                                    .shadow(color: LGColor.ink.opacity(0.1), radius: 1.5, y: 1)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(tab == item ? [.isSelected] : [])
            }
        }
        .padding(3)
        .background(LGColor.segmentTrack, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("History view")
    }
}
