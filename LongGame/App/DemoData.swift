import Foundation
import SwiftData
import CoreGraphics

#if DEBUG
/// Launch with the argument `-demoData` (Xcode: Product ▸ Scheme ▸ Edit Scheme ▸
/// Run ▸ Arguments) to replace everything with a sample Piano craft, the same
/// numbers as the design mock-ups. Debug builds only.
///
/// `-demoData.heavy` is the profiling game (docs/PERFORMANCE_PLAN.md): see `seedHeavy`.
enum DemoData {
    @MainActor
    static func seedIfRequested(_ context: ModelContext) {
        if ProcessInfo.processInfo.arguments.contains("-demoData.heavy") { seedHeavy(context); return }
        guard ProcessInfo.processInfo.arguments.contains("-demoData") else { return }
        removeEverything(context)
        seedDesignGame(context)
    }

    @MainActor
    private static func removeEverything(_ context: ModelContext) {
        for craft in (try? context.fetch(FetchDescriptor<Craft>())) ?? [] { context.delete(craft) }
        for e in (try? context.fetch(FetchDescriptor<YearEstimate>())) ?? [] { context.delete(e) }
        for s in (try? context.fetch(FetchDescriptor<Session>())) ?? [] { context.delete(s) }
        for t in (try? context.fetch(FetchDescriptor<TargetPeriod>())) ?? [] { context.delete(t) }
        for l in (try? context.fetch(FetchDescriptor<Letter>())) ?? [] { context.delete(l) }
        TimerPersistence.save(nil)
    }

    @MainActor
    private static func seedDesignGame(_ context: ModelContext) {
        let calendar = Calendar.current
        let now = Date()
        // `-uitest.newGame`: set up three days ago, with a session on each of those days (History's first week).
        let newGame = UITestLaunch.newGame
        let onboarding = calendar.date(byAdding: .day, value: newGame ? -3 : -120, to: now) ?? now
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
        for offset in 0..<(newGame ? 3 : 119) {
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
            if r < 0.2 && !newGame { continue }
            let weekend = calendar.isDateInWeekend(day)
            let h = ((r * 3 + (weekend ? 1 : 0)) * 2).rounded() / 2
            guard h > 0 else { continue }
            let start = SessionRules.manualStart(on: day)
            let note = offset == 3 ? "Slow practice on the hardest passage." : nil
            context.insert(Session(craftId: craft.id, start: start, durationSec: min(h, 5) * 3600, source: .manual, note: note))
        }
        // UI tests (update 48 and 49 screens): two photo sessions 2 years 8 months apart for Then and now.
        if (["thenAndNow", "history.growth", "milestone"].contains(UITestLaunch.screen ?? "") && !newGame) || UITestLaunch.photos {
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

    /// Years of near-daily practice for profiling: a Piano game from January 2019 to today (about 2,900 sessions,
    /// some days two), 300 of them with full-size photos (2048 px, roughly a real photo's file size), every
    /// milestone up to today passed, a year of pace and a few letters.
    ///
    /// Seeded once: a later launch with the switch finds the heavy game already there and leaves it alone, so the
    /// launch you measure isn't spent writing sessions. To profile a Release build (Product › Profile), run once
    /// from Xcode with `-demoData.heavy` first: the data stays on the phone. `-demoData` replaces it again.
    @MainActor
    private static func seedHeavy(_ context: ModelContext) {
        let existing = (try? context.fetchCount(FetchDescriptor<Session>())) ?? 0
        if existing >= 2_500 { return }
        removeEverything(context)

        let calendar = Calendar.current
        let now = Date()
        let first = calendar.date(from: DateComponents(year: 2019, month: 1, day: 1)) ?? now
        let craft = Craft(name: "Piano", category: "Music", startYear: 2019, createdAt: first)
        context.insert(craft)
        for (i, h) in [3, 5, 6, 8, 10, 8, 12, 12].enumerated() {
            context.insert(YearEstimate(craftId: craft.id, year: 2019 + i, hoursPerWeek: h))
        }
        let settings = (try? context.fetch(FetchDescriptor<AppSettings>()))?.first ?? AppSettings()
        if settings.modelContext == nil { context.insert(settings) }
        settings.weeklyTargetHours = 0
        settings.targetSetAt = nil
        settings.targetEndsAt = nil
        settings.targetPromptShownAt = nil
        settings.lastHomeTab = .today
        TargetSaving.apply(hours: 12, now: now, settings: settings, context: context)

        let photos = (0..<8).compactMap { heavyPhoto(seed: $0) }
        let notes = ["Scales and arpeggios", "Slow practice on the hardest passage.", "Sight-reading, two new pieces",
                     "Nocturne, left hand finally even", "Played it through for the first time"]
        let days = max(1, (calendar.dateComponents([.day], from: first, to: now).day ?? 0))
        let photoEvery = max(1, days / 300)
        var made = 0
        for offset in 0..<days {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: now) else { continue }
            let r = abs(sin(Double(offset + 7) * 12.9898) * 43758.5453).truncatingRemainder(dividingBy: 1)
            if r < 0.08 { continue }
            let weekend = calendar.isDateInWeekend(day)
            let h = max(0.5, ((r * 2.5 + (weekend ? 1 : 0)) * 2).rounded() / 2)
            let start = calendar.date(bySettingHour: weekend ? 10 : 18, minute: 0, second: 0, of: day) ?? day
            let session = Session(craftId: craft.id, start: start, durationSec: min(h, 4) * 3600,
                                  source: r > 0.5 ? .timer : .manual, note: offset % 9 == 0 ? notes[offset % notes.count] : nil)
            context.insert(session)
            if offset % photoEvery == 0, !photos.isEmpty, made < 300 {
                session.setPhoto(photos[made % photos.count])
                made += 1
            }
            // Some days a second, shorter session in the morning.
            if r > 0.85, let morning = calendar.date(bySettingHour: 7, minute: 30, second: 0, of: day) {
                context.insert(Session(craftId: craft.id, start: morning, durationSec: 1800, source: .timer))
            }
            if offset % 200 == 0 { try? context.save() }
        }
        // Every milestone already passed counts as seen, so no celebration plays over what is being measured.
        let records = ((try? context.fetch(FetchDescriptor<Session>())) ?? []).map(\.record)
        let estimates = ((try? context.fetch(FetchDescriptor<YearEstimate>())) ?? []).map(\.rate)
        let total = ProgressSummary.make(estimates: estimates, sessions: records, onboardingDate: craft.createdAt,
                                         weekStart: settings.weekStart, now: now, target: settings.currentTarget).total
        settings.milestonesSeen = Milestones.all.filter { Double($0) <= total }
        settings.thousandsAdopted = true

        // Two letters already opened, one still sealed for a milestone ahead (so none pops up while profiling).
        for milestone in [100, 1000, 9000] {
            let letter = Letter(craftId: craft.id, text: "Dear future me, keep going.", writtenAt: first,
                                totalWhenWritten: 0, milestone: milestone)
            if milestone < 9000 { letter.openedAt = first }
            context.insert(letter)
        }
        try? context.save()
    }

    /// A 2048 × 1536 picture with a soft gradient and fine grain, so its JPEG is about the size of a real photo
    /// (a flat drawing would compress to almost nothing and hide the cost of reading photos).
    private static func heavyPhoto(seed: Int) -> Data? {
        let w = 2048, h = 1536
        let space = CGColorSpaceCreateDeviceRGB()
        // A 128 px tile of grain, drawn across the whole picture (filling every pixel one by one is far too slow
        // in a Debug build).
        let side = 128
        var grain = [UInt8](repeating: 0, count: side * side * 4)
        var rng = UInt64(0x9E37_79B9_7F4A_7C15) &+ UInt64(seed)
        for i in stride(from: 0, to: grain.count, by: 4) {
            rng = rng &* 6364136223846793005 &+ 1442695040888963407
            let v = UInt8(truncatingIfNeeded: rng >> 56)
            grain[i] = v; grain[i + 1] = v; grain[i + 2] = v; grain[i + 3] = 60
        }
        let tile: CGImage? = grain.withUnsafeMutableBytes { buffer in
            CGContext(data: buffer.baseAddress, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
                      space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)?.makeImage()
        }
        guard let tile,
              let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        let hue = CGFloat(seed % 8) / 8
        let colours = [CGColor(red: 0.9, green: 0.6 + hue * 0.3, blue: 0.4, alpha: 1),
                       CGColor(red: 0.3, green: 0.4, blue: 0.7 + hue * 0.3, alpha: 1)] as CFArray
        if let gradient = CGGradient(colorsSpace: space, colors: colours, locations: [0, 1]) {
            ctx.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: w, y: h), options: [])
        }
        ctx.draw(tile, in: CGRect(x: 0, y: 0, width: side, height: side), byTiling: true)
        return ctx.makeImage().flatMap(PhotoProcessing.jpeg)
    }
}
#endif
