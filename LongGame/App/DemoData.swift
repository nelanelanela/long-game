import Foundation
import SwiftData

#if DEBUG
/// Launch with the argument `-demoData` (Xcode: Product ▸ Scheme ▸ Edit Scheme ▸
/// Run ▸ Arguments) to replace everything with a sample Piano craft, the same
/// numbers as the design mock-ups. Debug builds only.
enum DemoData {
    @MainActor
    static func seedIfRequested(_ context: ModelContext) {
        guard ProcessInfo.processInfo.arguments.contains("-demoData") else { return }
        for craft in (try? context.fetch(FetchDescriptor<Craft>())) ?? [] { context.delete(craft) }
        for e in (try? context.fetch(FetchDescriptor<YearEstimate>())) ?? [] { context.delete(e) }
        for s in (try? context.fetch(FetchDescriptor<Session>())) ?? [] { context.delete(s) }
        TimerPersistence.save(nil)

        let calendar = Calendar.current
        let now = Date()
        let onboarding = calendar.date(byAdding: .day, value: -120, to: now) ?? now
        let craft = Craft(name: "Piano", category: "Music", startYear: 2019, createdAt: onboarding)
        context.insert(craft)
        let hours = [3, 5, 6, 8, 10, 8, 12, 12]
        for (i, h) in hours.enumerated() {
            context.insert(YearEstimate(craftId: craft.id, year: 2019 + i, hoursPerWeek: h))
        }
        if (try? context.fetchCount(FetchDescriptor<AppSettings>())) == 0 { context.insert(AppSettings()) }

        // A believable pattern: most days, a little more at weekends, a few rest days.
        for offset in 0..<119 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: now) else { continue }
            let r = abs(sin(Double(offset + 7) * 12.9898) * 43758.5453).truncatingRemainder(dividingBy: 1)
            if r < 0.2 { continue }
            let weekend = calendar.isDateInWeekend(day)
            let h = ((r * 3 + (weekend ? 1 : 0)) * 2).rounded() / 2
            guard h > 0 else { continue }
            let start = SessionRules.manualStart(on: day)
            let note = offset == 3 ? "Slow practice on the hardest passage." : nil
            context.insert(Session(craftId: craft.id, start: start, durationSec: min(h, 5) * 3600, source: .manual, note: note))
        }
        try? context.save()
    }
}
#endif
