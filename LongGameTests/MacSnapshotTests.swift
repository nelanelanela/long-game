import Testing
import SwiftUI
import SwiftData
@testable import LongGame

#if os(macOS)
/// Optional: create the folder /tmp/mac-shots and the Mac window is drawn at 1180 x 740 and saved there to look at.
@MainActor
struct MacSnapshotTests {
    @Test func windowPictures() throws {
        let folder = "/tmp/mac-shots"
        guard FileManager.default.fileExists(atPath: folder) else { return }
        let container = try ModelContainer(for: Schema([Craft.self, YearEstimate.self, Session.self, AppSettings.self, TargetPeriod.self]),
                                            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let calendar = Calendar.current
        let now = Date()
        let craft = Craft(name: "Piano", category: "Music", startYear: 2019, createdAt: calendar.date(byAdding: .day, value: -120, to: now)!)
        context.insert(craft)
        for (i, h) in [3, 5, 6, 8, 10, 8, 12, 12].enumerated() { context.insert(YearEstimate(craftId: craft.id, year: 2019 + i, hoursPerWeek: h)) }
        let settings = AppSettings()
        context.insert(settings)
        TargetSaving.apply(hours: 12, now: now, settings: settings, context: context)
        for offset in 0..<100 where offset % 6 != 0 {
            let day = calendar.date(byAdding: .day, value: -offset, to: now)!
            context.insert(Session(craftId: craft.id, start: day, durationSec: Double(900 + (offset * 37) % 4000), source: .timer))
        }
        try context.save()
        let host = try StoreHost(isFreshInstall: false, make: { _ in container })

        for (name, section) in [("longgame", SidebarSection.longGame), ("today", .today), ("calendar", .calendar), ("growth", .growth)] {
            UserDefaults.standard.set(section.rawValue, forKey: "sidebar.section")
            let view = AppRoot()
                .modelContainer(container)
                .environment(host)
                .environment(TimerStore()).environment(ICloudMonitor()).environment(TipStore()).environment(CommandCenter())
                .frame(width: 1180, height: 740)
                .background(LGColor.background)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 1
            try renderer.platformImage?.pngData()?.write(to: URL(fileURLWithPath: folder).appendingPathComponent("\(name).png"))
        }
    }
}
#endif
