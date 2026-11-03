import Testing
import Foundation
import SwiftUI
import SwiftData
@testable import LongGame

private let craftId = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!

private func snapshot(sessions: [WidgetSnapshot.Entry] = [], target: Double? = 12) -> WidgetSnapshot {
    WidgetSnapshot(craftName: "Piano", onboardingDate: day(2026, 10, 1),
                   estimates: [.init(year: 2025, hoursPerWeek: 10), .init(year: 2026, hoursPerWeek: 12)],
                   sessions: sessions, weekStart: WeekStart.monday.rawValue,
                   target: target.map { .init(hoursPerWeek: $0, start: day(2026, 10, 1, hour: 0), end: day(2027, 10, 1, hour: 0)) },
                   craftId: craftId)
}

private func finished(_ start: Date, minutes: Double, id: UUID = UUID()) -> FinishedSession {
    FinishedSession(id: id, craftId: craftId, start: start, durationSec: minutes * 60)
}

struct TimerSyncTests {
    let started = day(2026, 11, 5, hour: 9)

    @Test func theTimerSurvivesTheTripBetweenPhoneAndWatch() throws {
        var state = TimerState(craftId: craftId, craftName: "Piano", startedAt: started)
        state.pause(at: started.addingTimeInterval(600))
        let update = TimerUpdate(state: state, changedAt: started.addingTimeInterval(601))
        let copy = try #require(WatchMessage.timerUpdate(from: WatchMessage.timerPayload(update)))
        #expect(copy == update)
        #expect(copy.state?.elapsed(at: started.addingTimeInterval(9_999)) == 600)
    }

    @Test func noTimerIsAnUpdateToo() throws {
        let cleared = TimerUpdate(state: nil, changedAt: started)
        let copy = try #require(WatchMessage.timerUpdate(from: WatchMessage.timerPayload(cleared)))
        #expect(copy.state == nil)
    }

    @Test func onlyANewerChangeIsTaken() {
        let update = TimerUpdate(state: nil, changedAt: started)
        #expect(update.supersedes(started.addingTimeInterval(-1)))
        #expect(!update.supersedes(started))
        #expect(!update.supersedes(started.addingTimeInterval(5)))
        // a device that has never had a change takes the first one
        #expect(update.supersedes(Date(timeIntervalSince1970: 0)))
    }

    @Test func unrelatedMessagesAreIgnored() {
        #expect(WatchMessage.timerUpdate(from: [:]) == nil)
        #expect(WatchMessage.timerUpdate(from: ["timer": "nonsense"]) == nil)
        #expect(WatchMessage.finishedSession(from: ["timer": Data()]) == nil)
    }

    @Test func aFinishedSessionSurvivesTheTrip() throws {
        let session = finished(started, minutes: 42)
        let copy = try #require(WatchMessage.finishedSession(from: WatchMessage.sessionPayload(session)))
        #expect(copy == session)
        #expect(copy.entry == WidgetSnapshot.Entry(start: started, seconds: 42 * 60, id: session.id))
    }
}

struct WatchPendingTests {
    let now = day(2026, 11, 5, hour: 18)

    @Test func aSessionTheWatchFinishedCountsUntilThePhoneHasIt() {
        let mine = finished(day(2026, 11, 5, hour: 9), minutes: 30)
        let empty = snapshot()
        #expect(PendingSessions.outstanding([mine], snapshot: empty, now: now) == [mine])
        let confirmed = snapshot(sessions: [mine.entry])
        #expect(PendingSessions.outstanding([mine], snapshot: confirmed, now: now).isEmpty)
        #expect(PendingSessions.outstanding([mine], snapshot: nil, now: now) == [mine])
    }

    @Test func aSessionThePhoneNeverConfirmedIsDroppedAfterAMonth() {
        let old = finished(day(2026, 9, 1, hour: 9), minutes: 30)
        #expect(PendingSessions.outstanding([old], snapshot: snapshot(), now: now).isEmpty)
    }

    @Test func mergingNeverCountsASessionTwice() {
        let mine = finished(day(2026, 11, 5, hour: 9), minutes: 30)
        let alone = WatchModel.merged(snapshot(), pending: [mine])
        #expect(alone.sessions == [mine.entry])
        let both = WatchModel.merged(snapshot(sessions: [mine.entry]), pending: [mine])
        #expect(both.sessions.count == 1)
    }

    @Test func theTotalGrowsByTheSessionAndOnlyOnce() {
        let mine = finished(day(2026, 11, 5, hour: 9), minutes: 30)
        let before = WatchModel.state(snapshot: snapshot(), now: now, calendar: utc).widget.total
        let withIt = WatchModel.state(snapshot: snapshot(), pending: [mine], now: now, calendar: utc).widget
        #expect(abs(withIt.total - (before + 0.5)) < 0.0001)
        #expect(withIt.weekHours == 0.5)
        let phoneHasIt = WatchModel.state(snapshot: snapshot(sessions: [mine.entry]), pending: [mine], now: now, calendar: utc).widget
        #expect(abs(phoneHasIt.total - (before + 0.5)) < 0.0001)
    }
}

struct WatchModelTests {
    // Thursday 5 Nov 2026, weeks start on Monday.
    let thursday = day(2026, 11, 5, hour: 18)

    @Test func theWeekPageSaysWhatIsLeft() {
        let state = WatchModel.state(snapshot: snapshot(sessions: [.init(start: day(2026, 11, 3), seconds: 6.5 * 3600)]),
                                     now: thursday, calendar: utc)
        #expect(state.widget.week.pill == "6.5 h")
        #expect(state.weekCaption == "of 12 h · 3 days left")
        #expect(state.craftId == craftId)
    }

    @Test func theLongGamePageGivesPercentAndFinish() {
        let state = WatchModel.state(snapshot: snapshot(), now: thursday, calendar: utc)
        #expect(state.longGameCaption.hasPrefix("\(state.widget.longGamePercent)% · finish "))
        #expect(state.finish.hasPrefix("~") || state.finish.hasPrefix("after"))
    }

    @Test func theTimerLineMatchesTheDesign() {
        // 42:18 into a session on top of 3,294 h: "3,294.7 h · next ray 2:42"
        #expect(WatchModel.timerLine(baseTotal: 3_294, elapsed: 42 * 60 + 18) == "3,294.7 h · next ray 2:42")
    }

    @Test func theFinishedScreenSaysHowMuchWasAdded() {
        #expect(WatchModel.addedText(finished(thursday, minutes: 42)) == "+42 m")
        #expect(WatchModel.addedText(finished(thursday, minutes: 65)) == "+1 h 5 m")
        let state = WatchModel.state(snapshot: snapshot(sessions: [.init(start: day(2026, 11, 3), seconds: 7.2 * 3600)]),
                                     now: thursday, calendar: utc)
        #expect(WatchModel.finishedCaption(state) == "7.2 of 12 h this week")
    }

    @Test func aSessionUnderAMinuteIsNotSaved() {
        #expect(!FinishRules.canSave(elapsed: 59))
        #expect(FinishRules.canSave(elapsed: 60))
    }
}

@MainActor
struct WatchSavingTests {
    private func makeContext() throws -> ModelContext {
        let schema = Schema([Craft.self, YearEstimate.self, Session.self, AppSettings.self, TargetPeriod.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        return ModelContext(container)
    }

    @Test func theWatchsSessionIsSavedOnThePhoneWithTheSameIdAndOnlyOnce() throws {
        let context = try makeContext()
        let craft = Craft(name: "Piano", startYear: 2025)
        context.insert(craft)
        let session = FinishedSession(id: UUID(), craftId: craft.id, start: day(2026, 11, 5, hour: 9), durationSec: 2_520)
        #expect(WatchBridge.save(session, in: context))
        #expect(!WatchBridge.save(session, in: context))
        let saved = try context.fetch(FetchDescriptor<Session>())
        #expect(saved.count == 1)
        #expect(saved.first?.id == session.id)
        #expect(saved.first?.craftId == craft.id)
        #expect(saved.first?.durationSec == 2_520)
        #expect(saved.first?.source == .timer)
    }

    @Test func ifTheCraftWasReplacedTheSessionGoesToTheActiveOne() throws {
        let context = try makeContext()
        let old = Craft(name: "Old", startYear: 2020)
        old.archivedAt = Date()
        let active = Craft(name: "Piano", startYear: 2025)
        [old, active].forEach(context.insert)
        let session = FinishedSession(id: UUID(), craftId: UUID(), start: day(2026, 11, 5), durationSec: 600)
        #expect(WatchBridge.save(session, in: context))
        #expect(try context.fetch(FetchDescriptor<Session>()).first?.craftId == active.id)
    }

    @Test func withNoCraftThereIsNowhereToSaveIt() throws {
        let context = try makeContext()
        let session = FinishedSession(id: UUID(), craftId: UUID(), start: day(2026, 11, 5), durationSec: 600)
        #expect(!WatchBridge.save(session, in: context))
        #expect(try context.fetchCount(FetchDescriptor<Session>()) == 0)
    }
}

/// The watch's pictures: the sea must cover the sun at every height, and every screen must draw something.
@MainActor
struct WatchPictureTests {
    private func pixels<V: View>(_ view: V, width: CGFloat, height: CGFloat) -> (data: [UInt8], w: Int, h: Int)? {
        let renderer = ImageRenderer(content: view.frame(width: width, height: height).background(Color.black))
        renderer.scale = 2
        guard let cg = renderer.uiImage?.cgImage else { return nil }
        let w = cg.width, h = cg.height
        var data = [UInt8](repeating: 0, count: w * h * 4)
        let ctx = CGContext(data: &data, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        ctx?.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        return (data, w, h)
    }

    /// The sun's yellows and oranges, or its pink cheeks.
    private func isSun(_ r: Int, _ g: Int, _ b: Int) -> Bool {
        let yellow = r > 235 && g > 150 && g < 220 && b < 140
        let pink = r > 225 && g > 140 && g < 190 && b > 160 && b < 205
        return yellow || pink
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

    @Test func nothingOfTheSunShowsBelowTheWaterOnAnyWatch() {
        for width in [CGFloat(162), 176, 192, 205] {
            let s = width / 192
            for f in [0, 0.01, 0.1, 0.3294, 6.5 / 12, 0.8, 1, 1.4] as [Double] {
                guard let shot = pixels(WatchScene(fraction: f, celebrate: f >= 1), width: width, height: 110 * s) else {
                    Issue.record("no image"); return
                }
                // The wave bows 3.5 pt and its line is 2.4 pt thick: 8 pt below the middle is water.
                let leaked = sunPixels(shot, fromY: (88 + 8) * s, toY: 110 * s)
                #expect(leaked == 0, "watch \(width) pt wide, fraction \(f): \(leaked) sun pixels below the water")
            }
        }
    }

    @Test func theSunIsReallyDrawnAboveTheWater() {
        let shot = pixels(WatchScene(fraction: 1, celebrate: true), width: 192, height: 110)
        #expect(shot.map { sunPixels($0, fromY: 0, toY: 80) } ?? 0 > 800)
    }

    @Test func everyScreenDrawsSomething() throws {
        let state = WatchModel.state(snapshot: snapshot(sessions: [.init(start: day(2026, 11, 3), seconds: 6.5 * 3600)]),
                                     now: day(2026, 11, 5, hour: 18), calendar: utc)
        let widget = state.widget
        let last = finished(day(2026, 11, 5, hour: 17), minutes: 42)
        let screens: [(String, AnyView)] = [
            ("week", AnyView(WatchHomePage(tab: .week, state: state, onStart: {}))),
            ("longgame", AnyView(WatchHomePage(tab: .longGame, state: state))),
            ("timer", AnyView(WatchTimerView(craftName: "Piano", elapsed: 42 * 60 + 18, paused: false, baseTotal: 3_294,
                                             onPauseOrResume: {}, onFinish: {}))),
            ("timer-paused", AnyView(WatchTimerView(craftName: "Piano", elapsed: 42 * 60 + 18, paused: true, baseTotal: 3_294,
                                                    onPauseOrResume: {}, onFinish: {}))),
            ("finished", AnyView(WatchFinishedView(added: WatchModel.addedText(last), caption: WatchModel.finishedCaption(state), onDone: {}))),
            ("setup", AnyView(WatchSetupView())),
        ]
        for (name, screen) in screens {
            guard let shot = pixels(screen.foregroundStyle(.white), width: 192, height: 238) else { Issue.record("no image for \(name)"); return }
            let lit = stride(from: 0, to: shot.data.count, by: 4).filter { shot.data[$0] > 40 || shot.data[$0 + 1] > 40 }.count
            #expect(lit > 500, "\(name) drew almost nothing")
        }
        _ = widget
        // Optional: with WATCH_SHOTS set to a folder, the screens are saved there to look at.
        if let folder = ProcessInfo.processInfo.environment["WATCH_SHOTS"] {
            for (name, screen) in screens {
                let r = ImageRenderer(content: screen.foregroundStyle(.white).frame(width: 192, height: 238).background(Color.black))
                r.scale = 3
                try? r.uiImage?.pngData()?.write(to: URL(fileURLWithPath: folder).appendingPathComponent("watch-\(name).png"))
            }
            var done = state
            done.widget.week = .week(hours: 13.5, target: 12)
            done.widget.weekHours = 13.5
            let top = ImageRenderer(content: WatchHomePage(tab: .week, state: done, onStart: {}).frame(width: 192, height: 238).background(Color.black))
            top.scale = 3
            try? top.uiImage?.pngData()?.write(to: URL(fileURLWithPath: folder).appendingPathComponent("watch-top.png"))
        }
    }
}
