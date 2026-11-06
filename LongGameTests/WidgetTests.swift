import Testing
import Foundation
import SwiftUI
import SwiftData
@testable import LongGame

private func snapshot(sessions: [WidgetSnapshot.Entry] = [], target: WidgetSnapshot.Target? = nil,
                      weekStart: WeekStart = .monday, onboarding: Date = day(2026, 10, 1)) -> WidgetSnapshot {
    WidgetSnapshot(craftName: "Piano", onboardingDate: onboarding,
                   estimates: [.init(year: 2025, hoursPerWeek: 10), .init(year: 2026, hoursPerWeek: 12)],
                   sessions: sessions, weekStart: weekStart.rawValue, target: target)
}

private func entry(_ date: Date, hours: Double) -> WidgetSnapshot.Entry { .init(start: date, seconds: hours * 3600) }

struct WidgetModelTests {
    // Thursday 5 Nov 2026, weeks start on Monday.
    let thursday = day(2026, 11, 5, hour: 18)

    @Test func thisWeekTodayAndTotalComeFromTheSavedData() {
        let snap = snapshot(sessions: [entry(day(2026, 11, 2), hours: 2.5), entry(day(2026, 11, 5, hour: 9), hours: 1.5),
                                       entry(day(2026, 10, 28), hours: 4)],
                            target: .init(hoursPerWeek: 12, start: day(2026, 10, 1, hour: 0), end: day(2027, 10, 1, hour: 0)))
        let state = WidgetModel.make(snap, at: thursday, calendar: utc)
        #expect(state.weekHours == 4)                 // 2.5 + 1.5; last week's 4 h is not counted
        #expect(state.todaySeconds == 1.5 * 3600)
        #expect(state.weekTarget == 12)
        let baseline = Baseline.hours(estimates: [YearRate(year: 2025, hoursPerWeek: 10), YearRate(year: 2026, hoursPerWeek: 12)],
                                      onboardingDate: day(2026, 10, 1), calendar: utc)
        #expect(abs(state.total - (baseline + 8)) < 0.0001)
        #expect(state.craftName == "Piano")
    }

    @Test func theGaugesMatchHome() {
        let snap = snapshot(sessions: [entry(day(2026, 11, 3), hours: 6.5)],
                            target: .init(hoursPerWeek: 12, start: day(2026, 10, 1, hour: 0), end: day(2027, 10, 1, hour: 0)))
        let state = WidgetModel.make(snap, at: thursday, calendar: utc)
        #expect(state.week == HomeGauge.week(hours: 6.5, target: 12))
        #expect(state.longGame == HomeGauge.longGame(total: state.total))
        #expect(state.gauge(for: .week) == state.week)
        #expect(state.gauge(for: .longGame) == state.longGame)
        #expect(state.weekPercent == 54)
    }

    @Test func withNoTargetTheRecentPaceStandsInLikeOnHome() {
        let state = WidgetModel.make(snapshot(), at: thursday, calendar: utc)
        // 35.75 days (5.11 weeks) in, with nothing logged yet: 43% of no sessions and 57% of the latest estimate
        // (12 h) is 6.89 h, which the target rounds to 7.
        let pace = Pace.hoursPerWeek(sessions: [], latestEstimate: 12, onboardingDate: day(2026, 10, 1), now: thursday, calendar: utc)
        #expect(abs(pace - 6.893) < 0.01)
        #expect(state.weekTarget == WeeklyTarget.suggested(pace: pace))
        #expect(state.weekTarget == 7)
    }

    @Test func aNewDayResetsToday() {
        let snap = snapshot(sessions: [entry(day(2026, 11, 5, hour: 9), hours: 1.5)])
        #expect(WidgetModel.make(snap, at: day(2026, 11, 5, hour: 20), calendar: utc).todaySeconds == 1.5 * 3600)
        #expect(WidgetModel.make(snap, at: day(2026, 11, 6, hour: 8), calendar: utc).todaySeconds == 0)
    }

    @Test func aNewWeekStartsTheSunAtZero() {
        let snap = snapshot(sessions: [entry(day(2026, 11, 5, hour: 9), hours: 5)])
        #expect(WidgetModel.make(snap, at: day(2026, 11, 8, hour: 20), calendar: utc).weekHours == 5)
        #expect(WidgetModel.make(snap, at: day(2026, 11, 9, hour: 8), calendar: utc).weekHours == 0)
    }

    @Test func theWeekFollowsTheWeekStartSetting() {
        let snap = snapshot(sessions: [entry(day(2026, 11, 1), hours: 3)], weekStart: .sunday)
        // Sunday 1 Nov begins a Sunday-start week, so it counts for the week of Thursday 5 Nov.
        var sundayCalendar = utc
        sundayCalendar.firstWeekday = 1
        #expect(WidgetModel.make(snap, at: thursday, calendar: sundayCalendar).weekHours == 3)
        #expect(WidgetModel.make(snapshot(sessions: [entry(day(2026, 11, 1), hours: 3)]), at: thursday, calendar: utc).weekHours == 0)
    }

    @Test func theTimelineHasAnEntryNowThenEveryMidnightUntilTheWeekTurns() {
        let dates = WidgetModel.timelineDates(from: thursday, weekStart: .monday, calendar: utc)
        #expect(dates.first == thursday)
        #expect(dates.dropFirst().first == day(2026, 11, 6, hour: 0))
        #expect(dates.last == day(2026, 11, 9, hour: 0))             // Monday: a new week
        #expect(dates == dates.sorted())
        #expect(dates.count == 5)                                    // Thu now, Fri, Sat, Sun, Mon midnights
    }

    @Test func theTimelineNeverRunsPastTheNextWeekStart() {
        let monday = day(2026, 11, 2, hour: 7)
        let dates = WidgetModel.timelineDates(from: monday, weekStart: .monday, calendar: utc)
        #expect(dates.last == day(2026, 11, 9, hour: 0))
        #expect(dates.count == 8)
        let sunday = WidgetModel.timelineDates(from: day(2026, 11, 8, hour: 22), weekStart: .sunday, calendar: utc)
        #expect(sunday.last == day(2026, 11, 15, hour: 0))
    }

    @Test func theSampleIsTheDesignsPianoExample() {
        let s = WidgetState.sample
        #expect(s.craftName == "Piano")
        #expect(s.week.pill == "6.5 h" && s.longGame.pill == "3,294 h")
        #expect(s.weekPercent == 54 && s.longGamePercent == 33)
        #expect(DurationFormat.short(seconds: s.todaySeconds) == "1 h 30 m")
    }
}

struct WidgetLinkTests {
    @Test func eachTabHasItsOwnAddress() {
        #expect(WidgetLink.url(for: .week).absoluteString == "longgame://home/week")
        #expect(WidgetLink.url(for: .longGame).absoluteString == "longgame://home/longGame")
    }

    @Test func theAddressOpensTheMatchingTab() {
        for tab in HomeTab.allCases {
            #expect(WidgetLink.tab(from: WidgetLink.url(for: tab)) == tab)
        }
    }

    @Test func otherAddressesAreIgnored() throws {
        #expect(WidgetLink.tab(from: try #require(URL(string: "https://example.com/home/week"))) == nil)
        #expect(WidgetLink.tab(from: try #require(URL(string: "longgame://settings/week"))) == nil)
        #expect(WidgetLink.tab(from: try #require(URL(string: "longgame://home/nothing"))) == nil)
    }
}

struct WidgetSnapshotTests {
    @Test func theSnapshotSurvivesTheTripThroughTheSharedFile() throws {
        let original = snapshot(sessions: [entry(day(2026, 11, 2), hours: 2.5)],
                                target: .init(hoursPerWeek: 12, start: day(2026, 10, 1, hour: 0), end: day(2027, 10, 1, hour: 0)))
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let copy = try decoder.decode(WidgetSnapshot.self, from: encoder.encode(original))
        #expect(copy == original)
    }

    @Test func theGroupIsTheOneInTheEntitlements() throws {
        #expect(WidgetSnapshot.groupID == "group.com.wehavesun.LongGame.shared")
    }

    private func makeContext() throws -> ModelContext {
        let schema = Schema([Craft.self, YearEstimate.self, Session.self, AppSettings.self, TargetPeriod.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        return ModelContext(container)
    }

    @Test func theAppSharesOnlyTheActiveCraftsSavedData() throws {
        let context = try makeContext()
        let active = Craft(name: "Piano", startYear: 2025, createdAt: day(2026, 10, 1))
        let old = Craft(name: "Sculpture", startYear: 2020, createdAt: day(2024, 1, 1))
        old.archivedAt = day(2026, 9, 1)
        [active, old].forEach(context.insert)
        let estimates = [YearEstimate(craftId: active.id, year: 2025, hoursPerWeek: 10),
                         YearEstimate(craftId: old.id, year: 2020, hoursPerWeek: 3)]
        estimates.forEach(context.insert)
        let sessions = [Session(craftId: active.id, start: day(2026, 11, 2), durationSec: 5_400, source: .timer),
                        Session(craftId: old.id, start: day(2024, 2, 1), durationSec: 3_600, source: .manual)]
        sessions.forEach(context.insert)
        let settings = AppSettings()
        settings.weekStart = .sunday
        context.insert(settings)
        TargetSaving.apply(hours: 9.5, now: day(2026, 11, 2), settings: settings, context: context, calendar: utc)

        let snap = try #require(WidgetBridge.snapshot(crafts: [active, old], sessions: sessions, estimates: estimates, settings: settings))
        #expect(snap.craftName == "Piano")
        #expect(snap.onboardingDate == day(2026, 10, 1))
        #expect(snap.estimates == [.init(year: 2025, hoursPerWeek: 10)])
        #expect(snap.sessions == [.init(start: day(2026, 11, 2), seconds: 5_400, id: sessions[0].id)])
        #expect(snap.craftId == active.id)
        #expect(snap.weekStart == "sunday")
        #expect(snap.target?.hoursPerWeek == 9.5)
    }

    @Test func withNoActiveCraftThereIsNothingToShare() {
        let archived = Craft(name: "Old", startYear: 2020)
        archived.archivedAt = Date()
        #expect(WidgetBridge.snapshot(crafts: [archived], sessions: [], estimates: [], settings: nil) == nil)
        #expect(WidgetBridge.snapshot(crafts: [], sessions: [], estimates: [], settings: nil) == nil)
    }
}

/// The sea must cover the sun in the widgets too, at every height. These draw the real widget scene and look at pixels.
@MainActor
struct WidgetPictureTests {
    private func pixels<V: View>(_ view: V, width: CGFloat, height: CGFloat) -> (data: [UInt8], w: Int, h: Int)? {
        let renderer = ImageRenderer(content: view.frame(width: width, height: height).background(Color.white))
        renderer.scale = 2
        guard let cg = renderer.platformImage?.cgImage else { return nil }
        let w = cg.width, h = cg.height
        var data = [UInt8](repeating: 0, count: w * h * 4)
        let ctx = CGContext(data: &data, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        ctx?.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        return (data, w, h)
    }

    private func isSun(_ r: Int, _ g: Int, _ b: Int) -> Bool {
        let yellow = r > 235 && g > 150 && g < 220 && b < 140
        let pink = r > 225 && g > 140 && g < 190 && b > 160 && b < 205
        let navy = r < 60 && g < 70 && b < 110
        return yellow || pink || navy
    }

    private func sunPixels(_ shot: (data: [UInt8], w: Int, h: Int), fromY: CGFloat, toY: CGFloat) -> Int {
        var count = 0
        let y0 = max(0, Int(fromY * 2)), y1 = min(shot.h, Int(toY * 2))
        guard y0 < y1 else { return 0 }
        for y in y0..<y1 {
            for x in 0..<shot.w {
                let i = (y * shot.w + x) * 4
                if isSun(Int(shot.data[i]), Int(shot.data[i + 1]), Int(shot.data[i + 2])) { count += 1 }
            }
        }
        return count
    }

    private let fractions: [Double] = [0, 0.01, 0.1, 0.3294, 6.5 / 12, 0.8, 1, 1.4]

    @Test func inTheSmallWidgetNothingOfTheSunShowsBelowTheWaterline() {
        for size in [CGFloat(141), 158, 170] {
            let s = size / 170
            for f in fractions {
                let scene = WidgetScene(fraction: f, celebrate: f >= 1, spec: .small, scale: s)
                guard let shot = pixels(scene, width: size, height: 112 * s) else { Issue.record("no image"); return }
                // The wave bows 3.5 pt and its line is 2 pt thick: 8 pt below the middle is water.
                let leaked = sunPixels(shot, fromY: (82 + 8) * s, toY: 112 * s)
                #expect(leaked == 0, "small at \(size) pt, fraction \(f): \(leaked) sun pixels below the water")
            }
        }
    }

    @Test func inTheMediumWidgetNothingOfTheSunShowsBelowTheWaterline() {
        for f in fractions {
            let scene = WidgetScene(fraction: f, celebrate: f >= 1, spec: .medium, scale: 158 / 170)
            guard let shot = pixels(scene, width: 150 * 158 / 170, height: 158) else { Issue.record("no image"); return }
            let leaked = sunPixels(shot, fromY: (140 + 8) * 158 / 170, toY: 158)
            #expect(leaked == 0, "medium, fraction \(f): \(leaked) sun pixels below the water")
        }
    }

    @Test func theSunIsReallyDrawnAboveTheWater() {
        // Guards the tests above against passing because nothing was drawn.
        let scene = WidgetScene(fraction: 1, celebrate: true, spec: .small, scale: 1)
        let shot = pixels(scene, width: 170, height: 112)
        #expect(shot.map { sunPixels($0, fromY: 0, toY: 76) } ?? 0 > 800)
    }

    @Test func atZeroTheUpperPartOfTheSunPeeksOutOfTheSea() {
        let scene = WidgetScene(fraction: 0, celebrate: false, spec: .small, scale: 1)
        let shot = pixels(scene, width: 170, height: 112)
        #expect(shot.map { sunPixels($0, fromY: 0, toY: 76) } ?? 0 > 100)
    }

    @Test func everyFamilyDrawsSomething() throws {
        let state = WidgetState.sample
        func drawn<V: View>(_ view: V, _ w: CGFloat, _ h: CGFloat) -> Bool {
            guard let shot = pixels(view, width: w, height: h) else { return false }
            return stride(from: 0, to: shot.data.count, by: 4).contains { shot.data[$0] < 250 || shot.data[$0 + 1] < 250 }
        }
        #expect(drawn(SmallSunWidgetView(state: state, tab: .week), 158, 158))
        #expect(drawn(SmallSunWidgetView(state: state, tab: .longGame), 158, 158))
        #expect(drawn(MediumSunWidgetView(state: state), 338, 158))
        #expect(drawn(SetupWidgetView(), 158, 158))
        #expect(drawn(RectangularSunWidgetView(state: state).foregroundStyle(.black), 170, 78))
        #expect(drawn(InlineSunWidgetView(state: state).foregroundStyle(.black), 250, 24))
        // Optional: with WIDGET_SHOTS set to a folder, the pictures are saved there to look at.
        if let folder = ProcessInfo.processInfo.environment["WIDGET_SHOTS"] {
            func save<V: View>(_ name: String, _ view: V, _ w: CGFloat, _ h: CGFloat) {
                let r = ImageRenderer(content: view.frame(width: w, height: h).background(Color.white))
                r.scale = 3
                try? r.platformImage?.pngData()?.write(to: URL(fileURLWithPath: folder).appendingPathComponent("\(name).png"))
            }
            save("small-week", SmallSunWidgetView(state: state, tab: .week), 158, 158)
            save("small-longgame", SmallSunWidgetView(state: state, tab: .longGame), 158, 158)
            save("medium", MediumSunWidgetView(state: state), 338, 158)
            save("setup", SetupWidgetView(), 158, 158)
            var top = state
            top.week = .week(hours: 13.5, target: 12)
            top.weekHours = 13.5
            save("small-top", SmallSunWidgetView(state: top, tab: .week), 158, 158)
            save("small-zero", SmallSunWidgetView(state: {
                var z = state; z.week = .week(hours: 0, target: 12); z.weekHours = 0; return z }(), tab: .week), 158, 158)
            save("rectangular", RectangularSunWidgetView(state: state).foregroundStyle(.black), 170, 78)
            save("inline", InlineSunWidgetView(state: state).foregroundStyle(.black), 250, 24)
            save("circular", CircularSunWidgetView(state: state).foregroundStyle(.black), 76, 76)
        }
    }
}
