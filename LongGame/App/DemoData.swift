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
        for t in (try? context.fetch(FetchDescriptor<TargetPeriod>())) ?? [] { context.delete(t) }
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
        // The design's year of pace: 12 hours a week from today, with Home opening on This week.
        let settings = (try? context.fetch(FetchDescriptor<AppSettings>()))?.first ?? AppSettings()
        if settings.modelContext == nil { context.insert(settings) }
        settings.weeklyTargetHours = 0
        settings.targetSetAt = nil
        settings.targetEndsAt = nil
        settings.targetPromptShownAt = nil
        settings.lastHomeTab = .today
        TargetSaving.apply(hours: 12, now: now, settings: settings, context: context)

        // A believable pattern: most days, a little more at weekends, a few rest days.
        for offset in 0..<119 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: now) else { continue }
            // UI tests: today's state (`-uitest.today empty|progress|covered`).
            if offset == 0, let today = UITestLaunch.today {
                let hours: Double = today == "covered" ? 2 : today == "progress" ? 0.75 : 0
                if hours > 0 {
                    context.insert(Session(craftId: craft.id, start: SessionRules.manualStart(on: day), durationSec: hours * 3600,
                                           source: .manual, note: "Scales and arpeggios"))
                }
                continue
            }
            let r = abs(sin(Double(offset + 7) * 12.9898) * 43758.5453).truncatingRemainder(dividingBy: 1)
            if r < 0.2 { continue }
            let weekend = calendar.isDateInWeekend(day)
            let h = ((r * 3 + (weekend ? 1 : 0)) * 2).rounded() / 2
            guard h > 0 else { continue }
            let start = SessionRules.manualStart(on: day)
            let note = offset == 3 ? "Slow practice on the hardest passage." : nil
            context.insert(Session(craftId: craft.id, start: start, durationSec: min(h, 5) * 3600, source: .manual, note: note))
        }
        // UI tests (update 48 and 49 screens): two photo sessions 2 years 8 months apart for Then and now.
        if ["thenAndNow", "history.growth", "milestone"].contains(UITestLaunch.screen ?? "") || UITestLaunch.photos {
            let notes = ["First try at the nocturne", "Nocturne, left hand finally even"]
            for (i, date) in [calendar.date(byAdding: DateComponents(year: -2, month: -8), to: now),
                              calendar.date(byAdding: .day, value: -1, to: now)].enumerated() {
                guard let date else { continue }
                let session = Session(craftId: craft.id, start: SessionRules.manualStart(on: date), durationSec: 3600,
                                      source: .manual, note: notes[i])
                context.insert(session)
                if let data = SettingsView.samplePhoto(seed: 40 + i) { session.setPhoto(data) }
            }
        }
        // UI tests: five timer sessions of 45 m, so the Finish sheet has a usual length ("Forgot to stop?").
        if UITestLaunch.screen == "timer.long" {
            for daysAgo in 1...5 {
                guard let day = calendar.date(byAdding: .day, value: -daysAgo, to: now),
                      let start = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: day) else { continue }
                context.insert(Session(craftId: craft.id, start: start, durationSec: 45 * 60, source: .timer))
            }
        }
        try? context.save()
    }
}
#endif
