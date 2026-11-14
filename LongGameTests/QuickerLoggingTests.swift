import Testing
import Foundation
@testable import LongGame

// Update 43: Undo after saving, Forgot to stop?, Begin without opening the app, Add time on the Watch.

struct UndoSaveTests {
    struct Row { var id = UUID() }

    @Test func undoRemovesOnlyTheSessionsFromThatSave() throws {
        let old = [Row(), Row(), Row()]
        let saved = Row()
        let all = old + [saved]
        let offered = try #require(UndoSave.offer(before: Set(old.map(\.id)), after: all.map(\.id), celebrates: false))
        #expect(offered == [saved.id])
        let removed = UndoSave.toRemove(all, id: \.id, offered: offered)
        #expect(removed.map(\.id) == [saved.id])
    }

    @Test func catchUpUndoRemovesAllOfItsSessions() throws {
        let old = [Row(), Row()]
        let catchUp = [Row(), Row(), Row(), Row()]
        let all = old + catchUp
        let offered = try #require(UndoSave.offer(before: Set(old.map(\.id)), after: all.map(\.id), celebrates: false))
        #expect(Set(offered) == Set(catchUp.map(\.id)))
        #expect(Set(UndoSave.toRemove(all, id: \.id, offered: offered).map(\.id)) == Set(catchUp.map(\.id)))
    }

    @Test func noUndoAfterAMilestone() {
        let old = [Row()]
        let all = old + [Row()]
        #expect(UndoSave.offer(before: Set(old.map(\.id)), after: all.map(\.id), celebrates: true) == nil)
    }

    @Test func noUndoWhenNothingNewWasSaved() {
        let rows = [Row(), Row()]
        #expect(UndoSave.offer(before: Set(rows.map(\.id)), after: rows.map(\.id), celebrates: false) == nil)
    }

    @Test func timings() {
        #expect(UndoSave.showFor == 6)
        #expect(UndoSave.removedFor == 2)
    }
}

struct UsualSessionTests {
    let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

    func timer(_ minutes: Double, daysAgo: Int) -> UsualSession.Entry {
        .init(start: t0.addingTimeInterval(Double(-daysAgo) * 86_400), seconds: minutes * 60, isTimer: true)
    }

    @Test func noUsualWithFewerThanFive() {
        let four = (0..<4).map { timer(45, daysAgo: $0) }
        #expect(UsualSession.usual(four) == nil)
        #expect(UsualSession.usual(four + [timer(30, daysAgo: 9)]) == TimeInterval(45 * 60))
    }

    @Test func medianOfAnOddCount() {
        let entries = [10, 50, 30, 20, 40].enumerated().map { timer(Double($1), daysAgo: $0) }
        #expect(UsualSession.usual(entries) == TimeInterval(30 * 60))
    }

    @Test func medianOfAnEvenCount() {
        let entries = [10, 20, 30, 40, 50, 60].enumerated().map { timer(Double($1), daysAgo: $0) }
        #expect(UsualSession.usual(entries) == TimeInterval(35 * 60))
    }

    @Test func manualAndCatchUpSessionsAreIgnored() {
        var entries = (0..<5).map { timer(45, daysAgo: $0) }
        entries += (0..<10).map { UsualSession.Entry(start: t0.addingTimeInterval(Double($0) * 60), seconds: 4 * 3600, isTimer: false) }
        #expect(UsualSession.usual(entries) == TimeInterval(45 * 60))
        // Only manual ones: no usual at all.
        #expect(UsualSession.usual(entries.filter { !$0.isTimer }) == nil)
    }

    @Test func onlyTheLastTwentyCount() {
        // 20 recent sessions of 40 m, then 30 older ones of 3 h.
        let recent = (0..<20).map { timer(40, daysAgo: $0) }
        let older = (20..<50).map { timer(180, daysAgo: $0) }
        #expect(UsualSession.usual(older + recent) == TimeInterval(40 * 60))
    }

    @Test func roundedToFiveMinutes() {
        #expect(UsualSession.rounded(43 * 60) == 45 * 60)
        #expect(UsualSession.rounded(42 * 60) == 40 * 60)
        #expect(UsualSession.rounded(60) == 5 * 60)
    }

    @Test func theTwoThresholds() {
        let usual: TimeInterval = 45 * 60
        // Twice the usual (90 m) but not over 90 minutes: no card.
        #expect(!UsualSession.isLong(elapsed: 90 * 60, usual: usual))
        #expect(UsualSession.isLong(elapsed: 91 * 60, usual: usual))
        // Over 90 minutes but under twice the usual: no card.
        #expect(!UsualSession.isLong(elapsed: 3 * 3600, usual: 100 * 60))
        #expect(UsualSession.isLong(elapsed: 200 * 60, usual: 100 * 60))
        // A short usual still needs over 90 minutes.
        #expect(!UsualSession.isLong(elapsed: 80 * 60, usual: 20 * 60))
        // Without a usual, never.
        #expect(!UsualSession.isLong(elapsed: 5 * 3600, usual: nil))
    }

    @Test func useAndKeep() {
        let elapsed: TimeInterval = 3 * 3600 + 12 * 60
        let usual: TimeInterval = 44 * 60
        #expect(UsualSession.duration(for: .useUsual, elapsed: elapsed, usual: usual) == 45 * 60)
        #expect(UsualSession.duration(for: .keep, elapsed: elapsed, usual: usual) == elapsed)
        // After Use, the stepper still works from the new length.
        let used = UsualSession.duration(for: .useUsual, elapsed: elapsed, usual: usual)
        #expect(FinishRules.raised(used, elapsed: elapsed) == 50 * 60)
        #expect(FinishRules.lowered(used) == 40 * 60)
    }
}

struct TimerCommandTests {
    let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)
    let craft = UUID()

    @Test func beginWhenIdleStartsASession() {
        let result = TimerCommands.begin(nil, craftId: craft, craftName: "Piano", now: t0)
        #expect(result == .started(TimerState(craftId: craft, craftName: "Piano", startedAt: t0)))
    }

    @Test func beginWhenAlreadyRunningDoesNothing() {
        let running = TimerState(craftId: craft, craftName: "Piano", startedAt: t0)
        #expect(TimerCommands.begin(running, craftId: craft, craftName: "Piano", now: t0.addingTimeInterval(600)) == .alreadyRunning)
    }

    @Test func beginWhenPausedResumes() {
        var paused = TimerState(craftId: craft, craftName: "Piano", startedAt: t0)
        paused.pause(at: t0.addingTimeInterval(600))
        guard case .resumed(let s) = TimerCommands.begin(paused, craftId: craft, craftName: "Piano", now: t0.addingTimeInterval(900)) else {
            Issue.record("expected a resume"); return
        }
        #expect(s.pausedAt == nil)
        #expect(s.elapsed(at: t0.addingTimeInterval(900)) == 600)
    }

    @Test func beginWithNoCraftOpensTheApp() {
        #expect(TimerCommands.begin(nil, craftId: nil, craftName: "", now: t0) == .noCraft)
    }

    @Test func pauseAndResume() throws {
        let running = TimerState(craftId: craft, craftName: "Piano", startedAt: t0)
        let paused = try #require(TimerCommands.pauseOrResume(running, now: t0.addingTimeInterval(600)))
        #expect(paused.isPaused(at: t0.addingTimeInterval(700)))
        #expect(paused.elapsed(at: t0.addingTimeInterval(5000)) == 600)
        let resumed = try #require(TimerCommands.pauseOrResume(paused, now: t0.addingTimeInterval(1200)))
        #expect(!resumed.isPaused(at: t0.addingTimeInterval(1300)))
        #expect(resumed.elapsed(at: t0.addingTimeInterval(1500)) == 900)
        #expect(TimerCommands.pauseOrResume(nil, now: t0) == nil)
    }

    @Test func theControlsToggle() {
        // Idle and off: nothing to pause.
        #expect(TimerCommands.setPlaying(false, nil, craftId: craft, craftName: "Piano", now: t0) == .nothing)
        // Idle, tapped on: begins.
        #expect(TimerCommands.setPlaying(true, nil, craftId: craft, craftName: "Piano", now: t0)
                == .begin(.started(TimerState(craftId: craft, craftName: "Piano", startedAt: t0))))
        // Playing, tapped off: pauses.
        let running = TimerState(craftId: craft, craftName: "Piano", startedAt: t0)
        #expect(TimerCommands.isPlaying(running, now: t0.addingTimeInterval(60)))
        guard case .paused(let p) = TimerCommands.setPlaying(false, running, craftId: craft, craftName: "Piano", now: t0.addingTimeInterval(60)) else {
            Issue.record("expected a pause"); return
        }
        #expect(!TimerCommands.isPlaying(p, now: t0.addingTimeInterval(120)))
        // Paused, tapped on: resumes.
        guard case .begin(.resumed) = TimerCommands.setPlaying(true, p, craftId: craft, craftName: "Piano", now: t0.addingTimeInterval(120)) else {
            Issue.record("expected a resume"); return
        }
    }

    @MainActor @Test func theTimerStoreAppliesThem() {
        let store = TimerStore()
        store.clear()
        defer { store.clear() }
        #expect(store.begin(craftId: craft, craftName: "Piano", now: t0) == .started(TimerState(craftId: craft, craftName: "Piano", startedAt: t0)))
        #expect(store.state?.startedAt == t0)
        #expect(store.begin(craftId: craft, craftName: "Piano", now: t0.addingTimeInterval(60)) == .alreadyRunning)
        #expect(store.state?.startedAt == t0)
        store.pauseOrResume(now: t0.addingTimeInterval(600))
        #expect(store.state?.pausedAt == t0.addingTimeInterval(600))
        store.pauseOrResume(now: t0.addingTimeInterval(900))
        #expect(store.state?.pausedAt == nil)
        #expect(store.state?.accumulatedPause == 300)
    }
}

struct WatchAddTimeTests {
    @Test func stepsAndRange() {
        #expect(WatchAddTime.clamped(0) == 5 * 60)
        #expect(WatchAddTime.clamped(32 * 60) == 30 * 60)
        #expect(WatchAddTime.clamped(9 * 3600) == 8 * 3600)
        #expect(WatchAddTime.quickPicks == [15 * 60, 30 * 60, 3600])
        #expect(WatchAddTime.initial == 30 * 60)
    }

    @Test func theDailyLimit() {
        #expect(WatchAddTime.canAdd(3600, todaySeconds: 11 * 3600))
        #expect(!WatchAddTime.canAdd(3600 + 60, todaySeconds: 11 * 3600))
    }

    @Test func theAmount() {
        #expect(WatchAddTime.amount(30 * 60) == "30 m")
        #expect(WatchAddTime.amount(3600) == "1 h")
    }
}
