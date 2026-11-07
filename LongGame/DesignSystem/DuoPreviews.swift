import SwiftUI
import SwiftData

// Previews for the four window shapes the layouts care about: a phone, the Duo closed (short), the Duo open (wide)
// and half of the open Duo in Split View. Sizes are approximate until Apple publishes the real ones.

#if DEBUG
@MainActor
private enum DuoPreviewData {
    /// An in-memory Piano craft with the design's numbers, and a running timer for the Timer previews.
    static func make(runningTimer: Bool = false) -> (container: ModelContainer, craft: Craft, timer: TimerStore) {
        let schema = Schema([Craft.self, YearEstimate.self, Session.self, AppSettings.self, TargetPeriod.self, ActiveSession.self])
        let container = try! ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let now = Date()
        let calendar = Calendar.current
        let craft = Craft(name: "Piano", category: "Music", startYear: 2019,
                          createdAt: calendar.date(byAdding: .day, value: -120, to: now) ?? now)
        context.insert(craft)
        for (i, h) in [3, 5, 6, 8, 10, 8, 12, 12].enumerated() {
            context.insert(YearEstimate(craftId: craft.id, year: 2019 + i, hoursPerWeek: h))
        }
        let settings = AppSettings()
        context.insert(settings)
        settings.futureSelfShown = true
        TargetSaving.apply(hours: 12, now: now, settings: settings, context: context)
        for offset in 0..<60 where offset % 4 != 3 {
            let day = calendar.date(byAdding: .day, value: -offset, to: now) ?? now
            let hours = 0.5 + Double(offset % 5) * 0.5
            context.insert(Session(craftId: craft.id, start: SessionRules.manualStart(on: day),
                                   durationSec: hours * 3600, source: .manual))
        }
        try? context.save()
        let timer = TimerStore()
        if runningTimer && !timer.isActive { timer.start(craft: craft, now: now.addingTimeInterval(-42 * 60 - 18)) }
        return (container, craft, timer)
    }
}

private struct DuoPreviewHome: View {
    var tab: HomeTab
    var body: some View {
        let data = DuoPreviewData.make()
        NavigationStack { HomeView(craft: data.craft, initialTab: tab) }
            .modelContainer(data.container)
            .environment(data.timer)
    }
}

private struct DuoPreviewTimer: View {
    var body: some View {
        let data = DuoPreviewData.make(runningTimer: true)
        TimerView(craft: data.craft, baseTotal: 3_294)
            .modelContainer(data.container)
            .environment(data.timer)
    }
}

private struct DuoPreviewHistory: View {
    var body: some View {
        let data = DuoPreviewData.make()
        NavigationStack { HistoryView(craft: data.craft) }
            .modelContainer(data.container)
            .environment(data.timer)
    }
}

#Preview("Home · This week · compact 393×852", traits: .fixedLayout(width: 393, height: 852)) { DuoPreviewHome(tab: .week) }
#Preview("Home · This week · short 405×567", traits: .fixedLayout(width: 405, height: 567)) { DuoPreviewHome(tab: .week) }
#Preview("Home · This week · wide 802×573", traits: .fixedLayout(width: 802, height: 573)) { DuoPreviewHome(tab: .week) }
#Preview("Home · This week · split 401×573", traits: .fixedLayout(width: 401, height: 573)) { DuoPreviewHome(tab: .week) }

#Preview("Home · Long game · compact 393×852", traits: .fixedLayout(width: 393, height: 852)) { DuoPreviewHome(tab: .longGame) }
#Preview("Home · Long game · short 405×567", traits: .fixedLayout(width: 405, height: 567)) { DuoPreviewHome(tab: .longGame) }
#Preview("Home · Long game · wide 802×573", traits: .fixedLayout(width: 802, height: 573)) { DuoPreviewHome(tab: .longGame) }
#Preview("Home · Long game · split 401×573", traits: .fixedLayout(width: 401, height: 573)) { DuoPreviewHome(tab: .longGame) }

#Preview("Timer · compact 393×852", traits: .fixedLayout(width: 393, height: 852)) { DuoPreviewTimer() }
#Preview("Timer · short 405×567", traits: .fixedLayout(width: 405, height: 567)) { DuoPreviewTimer() }
#Preview("Timer · wide 802×573", traits: .fixedLayout(width: 802, height: 573)) { DuoPreviewTimer() }
#Preview("Timer · split 401×573", traits: .fixedLayout(width: 401, height: 573)) { DuoPreviewTimer() }

#Preview("History · compact 393×852", traits: .fixedLayout(width: 393, height: 852)) { DuoPreviewHistory() }
#Preview("History · short 405×567", traits: .fixedLayout(width: 405, height: 567)) { DuoPreviewHistory() }
#Preview("History · wide 802×573", traits: .fixedLayout(width: 802, height: 573)) { DuoPreviewHistory() }
#Preview("History · split 401×573", traits: .fixedLayout(width: 401, height: 573)) { DuoPreviewHistory() }
#endif
