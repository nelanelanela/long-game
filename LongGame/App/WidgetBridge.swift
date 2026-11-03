import SwiftUI
import SwiftData
import WidgetKit

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
            estimates: estimates.filter { $0.craftId == id }.map { .init(year: $0.year, hoursPerWeek: Double($0.hoursPerWeek)) },
            sessions: sessions.filter { $0.craftId == id }.map { .init(start: $0.start, seconds: $0.durationSec, id: $0.id) },
            weekStart: (settings?.weekStart ?? .localeDefault).rawValue,
            target: settings?.currentTarget.map { .init(hoursPerWeek: $0.hoursPerWeek, start: $0.start, end: $0.end) },
            craftId: id)
    }

    /// Writes the data and reloads every widget, but only when something actually changed.
    @MainActor
    static func publish(_ snapshot: WidgetSnapshot?) {
        if WidgetSnapshot.store(snapshot) {
            WidgetCenter.shared.reloadAllTimelines()
        }
        // The watch gets the same stored data.
        WatchBridge.shared.snapshotChanged(snapshot)
    }
}

/// Publishes the widgets' data whenever a session, an estimate, the target, the week start or the craft changes
/// (that includes edits that arrive from iCloud), and again when the app comes to the front.
private struct WidgetSync: ViewModifier {
    @Query private var crafts: [Craft]
    @Query private var sessions: [Session]
    @Query private var estimates: [YearEstimate]
    @Query private var settingsRows: [AppSettings]
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        let snapshot = WidgetBridge.snapshot(crafts: crafts, sessions: sessions, estimates: estimates, settings: settingsRows.first)
        content
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
