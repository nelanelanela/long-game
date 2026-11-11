import SwiftUI
import SwiftData

private enum HistoryTab: String, CaseIterable {
    case calendar = "Calendar"
    case growth = "Growth"
}

struct HistoryView: View {
    let craft: Craft
    /// The day the calendar opens on (a tapped day bar on Home); today when nil.
    var day: Date?
    /// Opens on the Growth tab (the Finish line figure on Home) instead of the last tab used.
    var opensOnGrowth = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var sessions: [Session]
    @Query private var estimates: [YearEstimate]
    @Query private var settingsRows: [AppSettings]
    @SceneStorage("history.tab") private var tab: HistoryTab = .calendar
    @State private var showSettings = false

    init(craft: Craft, day: Date? = nil, opensOnGrowth: Bool = false) {
        self.craft = craft
        self.day = day
        self.opensOnGrowth = opensOnGrowth
        let id = craft.id
        _sessions = Query(filter: #Predicate<Session> { $0.craftId == id }, sort: \Session.start, order: .reverse)
        _estimates = Query(filter: #Predicate<YearEstimate> { $0.craftId == id })
    }

    private var weekStart: WeekStart { settingsRows.first?.weekStart ?? .localeDefault }

    var body: some View {
        AdaptiveLayout { window in
            let wide = window.shape.isWide
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Back, the small title in the middle, Settings: one 44 pt row as on the board.
                    ZStack {
                        Text("History").lgText(.navTitle)
                            .accessibilityAddTraits(.isHeader)
                        HStack {
                            LGIconButton(systemName: "chevron.left", label: "Back") { dismiss() }
                                .padding(.leading, -10)
                            Spacer()
                            LGIconButton(systemName: "gearshape", label: "Settings") { showSettings = true }
                                .padding(.trailing, -10)
                        }
                    }
                    .frame(height: 44)
                    .padding(.bottom, -10)

                    if wide {
                        // Calendar and Growth side by side instead of tabs.
                        HStack(alignment: .top, spacing: 28) {
                            column("Calendar") { calendar }
                            column("Growth") { growth }
                        }
                    } else {
                        picker
                        switch tab {
                        case .calendar: calendar
                        case .growth: growth
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
                .lgReadableColumn(wide ? .infinity : 560)
            }
            .lgAnimation(.easeInOut(duration: 0.3), value: wide)
        }
        .lgScreen()
        .lgHidesNavigationBar()
        .onAppear { if opensOnGrowth { tab = .growth } }
        // Settings has its own stack: a screen that hides the navigation bar and is pushed on top of another
        // pushed screen (Settings → Your estimates) sent SwiftUI into an endless layout loop.
        .fullScreenCover(isPresented: $showSettings) {
            NavigationStack {
                SettingsView(craft: craft, closeAll: { showSettings = false; dismiss() })
            }
        }
    }

    private var calendar: some View {
        CalendarTab(craft: craft, sessions: sessions, weekStart: weekStart, initialDay: day)
    }

    private var growth: some View {
        GrowthTab(craft: craft, sessions: sessions, estimates: estimates, weekStart: weekStart,
                  target: settingsRows.first?.currentTarget)
    }

    private func column<Content: View>(_ title: LocalizedStringKey, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).lgText(.rowStrong, color: LGColor.inkMuted)
                .accessibilityAddTraits(.isHeader)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var picker: some View {
        HStack(spacing: 0) {
            ForEach(HistoryTab.allCases, id: \.self) { item in
                Button { withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.15)) { tab = item } } label: {
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
