import Testing
import Foundation
@testable import LongGame

struct MenuBarTextTests {
    let t0 = Date(timeIntervalSinceReferenceDate: 2_000_000)
    func running() -> TimerState { TimerState(craftId: UUID(), startedAt: t0) }

    @Test func runningShowsTheClockFromTimestamps() {
        // 25 min 18 s after the start.
        #expect(MenuBarText.title(timer: running(), savedToday: 3_900, now: t0.addingTimeInterval(25 * 60 + 18)) == "25:18")
        // The same state a minute later reads a minute later: nothing is counted in memory.
        #expect(MenuBarText.title(timer: running(), savedToday: 3_900, now: t0.addingTimeInterval(26 * 60 + 18)) == "26:18")
    }

    @Test func runningPastAnHourShowsHours() {
        #expect(MenuBarText.title(timer: running(), savedToday: 0, now: t0.addingTimeInterval(3_723)) == "1:02:03")
    }

    @Test func pausedShowsTheFrozenClock() {
        var s = running()
        s.pause(at: t0.addingTimeInterval(600))
        #expect(MenuBarText.title(timer: s, savedToday: 0, now: t0.addingTimeInterval(9_000)) == "10:00")
    }

    @Test func idleShowsTodaysTime() {
        #expect(MenuBarText.title(timer: nil, savedToday: 3_900, now: t0) == "1 h 05")
        #expect(MenuBarText.title(timer: nil, savedToday: 2_400, now: t0) == "40 m")
        #expect(MenuBarText.title(timer: nil, savedToday: 0, now: t0) == "0 m")
    }

    @Test func onlyARunningSessionTicksEverySecond() {
        #expect(MenuBarText.ticksEverySecond(timer: running()))
        #expect(!MenuBarText.ticksEverySecond(timer: nil))
    }

    @Test func runningLineAndIdleCaptionUseTodaysStretch() {
        let mid = StretchState.inProgress(target: 6_300, done: 5_400)
        #expect(MenuBarText.todayLine(mid) == "1 h 30 of 1 h 45 · 15 m to the moon")
        let idle = StretchState.inProgress(target: 6_300, done: 3_900)
        #expect(MenuBarText.bigTime(idle) == "1 h 05")
        #expect(MenuBarText.idleCaption(idle) == "of today's 1 h 45 · 40 m to the moon")
    }

    @Test func coveredAndNoTargetWording() {
        let covered = StretchState.covered(target: 6_300, done: 7_000)
        #expect(MenuBarText.idleCaption(covered) == "today's 1 h 45 · covered")
        #expect(MenuBarText.todayLine(covered).hasSuffix("covered"))
        #expect(MenuBarText.todayLine(.noTarget) == "")
    }

    @Test func nextRayCountsDownFromTheTimer() {
        // 2 min 18 s into a 5-minute ray: 2:42 to go.
        #expect(MenuBarText.nextRay(timer: running(), now: t0.addingTimeInterval(138)) == "Next ray in 2:42")
    }

    @Test func pauseButtonFollowsTheState() {
        var s = running()
        #expect(MenuBarText.pauseTitle(timer: s, now: t0.addingTimeInterval(60)) == "Pause")
        s.pause(at: t0.addingTimeInterval(60))
        #expect(MenuBarText.pauseTitle(timer: s, now: t0.addingTimeInterval(120)) == "Resume")
    }

    @Test func dockIsShownUnlessTurnedOff() {
        let defaults = UserDefaults(suiteName: "MenuBarTests.\(UUID().uuidString)")!
        #expect(DockVisibility.isShown(defaults))
        defaults.set(false, forKey: DockVisibility.defaultsKey)
        #expect(!DockVisibility.isShown(defaults))
        defaults.set(true, forKey: DockVisibility.defaultsKey)
        #expect(DockVisibility.isShown(defaults))
    }
}
