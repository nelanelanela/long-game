import SwiftUI
import SwiftData
import WidgetKit
import AppIntents

/// Keeps the widgets' copy of the saved data in the shared App Group in step with the app, and tells WidgetKit to
/// redraw when it changes.
enum WidgetBridge {
    /// The active craft's stored data as the widgets need it (nothing derived); nil with no active craft yet.
    static func snapshot(crafts: [Craft], sessions: [Session], estimates: [YearEstimate], settings: AppSettings?) -> WidgetSnapshot? {
        guard let craft = crafts.first(where: \.isActive) else { return nil }
        let id = craft.id
        return WidgetSnapshot(
            craftName: craft.name,
            onboardingDate: craft.createdAt,
            estimates: estimates.filter { $0.craftId == id }.map { .init(year: $0.year, hoursPerWeek: Double($0.hoursPerWeek), totalHours: $0.totalHours) },
            sessions: sessions.filter { $0.craftId == id }.map { .init(start: $0.start, seconds: $0.durationSec, id: $0.id) },
            weekStart: (settings?.weekStart ?? .localeDefault).rawValue,
            target: settings?.currentTarget.map { .init(hoursPerWeek: $0.hoursPerWeek, start: $0.start, end: $0.end) },
            craftId: id)
    }

    /// Writes the data and reloads every widget, but only when something actually changed.
    @MainActor
    static func publish(_ snapshot: WidgetSnapshot?) {
        Signposts.event("Widget publish")
        if WidgetSnapshot.store(snapshot) {
            WidgetCenter.shared.reloadAllTimelines()
            // Siri learns the craft's name for "Start playing piano".
            LongGameShortcuts.updateAppShortcutParameters()
        }
        // The watch gets the same stored data.
        #if os(iOS)
        WatchBridge.shared.snapshotChanged(snapshot)
        #endif
    }
}

/// Publishes the widgets' data whenever a session, an estimate, the target, the week start or the craft changes
/// (that includes edits that arrive from iCloud), and again when the app comes to the front.
///
/// Only the active craft's sessions and estimates are read, in a small view of their own: redraws of the app around
/// it, and changes to other crafts, never make it read them again.
private struct WidgetSync: ViewModifier {
    @Query private var crafts: [Craft]

    func body(content: Content) -> some View {
        let active = crafts.first(where: \.isActive)
        content.background {
            WidgetPublisher(craft: active).id(active?.id)
        }
    }
}

private struct WidgetPublisher: View {
    let craft: Craft?
    @Query private var sessions: [Session]
    @Query private var estimates: [YearEstimate]
    @Query private var settingsRows: [AppSettings]
    @Environment(\.scenePhase) private var scenePhase

    init(craft: Craft?) {
        self.craft = craft
        let id = craft?.id ?? UUID()
        _sessions = Query(filter: #Predicate<Session> { $0.craftId == id }, sort: \Session.start)
        _estimates = Query(filter: #Predicate<YearEstimate> { $0.craftId == id }, sort: \YearEstimate.year)
    }

    var body: some View {
        let snapshot = Signposts.measure("Widget snapshot") {
            craft.flatMap { WidgetBridge.snapshot(crafts: [$0], sessions: sessions, estimates: estimates, settings: settingsRows.first) }
        }
        Color.clear
            .accessibilityHidden(true)
            .allowsHitTesting(false)
            .onAppear { WidgetBridge.publish(snapshot) }
            .onChange(of: snapshot) { _, new in WidgetBridge.publish(new) }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { WidgetBridge.publish(snapshot) }
            }
    }
}

extension View {
    func syncsWidgets() -> some View { modifier(WidgetSync()) }
}
