import Testing
import Foundation
@testable import LongGame

struct TimerStateTests {
    let t0 = Date(timeIntervalSinceReferenceDate: 1_000_000)
    func state() -> TimerState { TimerState(craftId: UUID(), startedAt: t0) }

    @Test func elapsedRunsFromTimestamps() {
        #expect(state().elapsed(at: t0.addingTimeInterval(600)) == 600)
    }

    @Test func pauseFreezesElapsed() {
        var s = state()
        s.pause(at: t0.addingTimeInterval(600))
        #expect(s.elapsed(at: t0.addingTimeInterval(5000)) == 600)
        #expect(s.isPaused(at: t0.addingTimeInterval(5000)))
    }

    @Test func resumeExcludesPausedTime() {
        var s = state()
        s.pause(at: t0.addingTimeInterval(600))
        s.resume(at: t0.addingTimeInterval(1200))
        #expect(s.accumulatedPause == 600)
        #expect(s.elapsed(at: t0.addingTimeInterval(1500)) == 900)
        #expect(!s.isPaused(at: t0.addingTimeInterval(1500)))
    }

    @Test func autoPausesAtTwelveHours() {
        let s = state()
        let later = t0.addingTimeInterval(15 * 3600)
        #expect(s.elapsed(at: later) == 12 * 3600)
        #expect(s.isAutoPaused(at: later))
        var n = s
        n.normalize(at: later)
        #expect(n.pausedAt == t0.addingTimeInterval(12 * 3600))
        n.resume(at: later)
        #expect(n.accumulatedPause == 3 * 3600)
        #expect(n.elapsed(at: later) == 12 * 3600)
    }

    @Test func clockGoingBackwardsNeverGivesNegative() {
        #expect(state().elapsed(at: t0.addingTimeInterval(-100)) == 0)
    }

    @Test func survivesEncoding() throws {
        var s = state()
        s.pause(at: t0.addingTimeInterval(30))
        let data = try JSONEncoder().encode(s)
        #expect(try JSONDecoder().decode(TimerState.self, from: data) == s)
    }

    @Test func longSessionReminderDate() {
        let s = state()
        let now = t0.addingTimeInterval(3600)
        #expect(s.longSessionDate(at: now) == t0.addingTimeInterval(4 * 3600))
        var p = s
        p.pause(at: now)
        #expect(p.longSessionDate(at: now) == nil)
        #expect(s.longSessionDate(at: t0.addingTimeInterval(5 * 3600)) == nil)
    }
}

struct SunHourTests {
    @Test func designExample() {
        let h = SunHour(elapsed: 42 * 60 + 18)
        #expect(h.litRays == 8)
        #expect(h.minutesIntoHour == 42)
        #expect(h.caption == "Next ray in 2:42 · golden hour in 17:42")
        #expect(h.accessibilityLabel.contains("8 of 12 rays lit: 42 minutes"))
    }

    @Test func raysLightEveryFiveMinutes() {
        #expect(SunHour(elapsed: 299).litRays == 0)
        #expect(SunHour(elapsed: 300).litRays == 1)
        #expect(SunHour(elapsed: 3599).litRays == 11)
    }

    @Test func raysResetEachHour() {
        let h = SunHour(elapsed: 3600 + 10)
        #expect(h.litRays == 0)
        #expect(h.hoursCompleted == 1)
    }

    @Test func goldenHourWindow() {
        #expect(abs((SunHour(elapsed: 3600.6).goldenProgress() ?? 0) - 0.5) < 0.001)
        #expect(SunHour(elapsed: 3602).goldenProgress() == nil)
        #expect(SunHour(elapsed: 0.5).goldenProgress() == nil)
    }

    @Test func rayGrowWindow() {
        #expect(abs((SunHour(elapsed: 300.3).rayGrowProgress() ?? 0) - 0.5) < 0.001)
        #expect(SunHour(elapsed: 301).rayGrowProgress() == nil)
        #expect(SunHour(elapsed: 10).rayGrowProgress() == nil)
    }

    @Test func skyWarmsThroughTheHour() {
        #expect(SunHour(elapsed: 1800).hourFraction == 0.5)
    }
}

struct FinishRuleTests {
    @Test func underAMinuteCannotBeSaved() {
        #expect(!FinishRules.canSave(elapsed: 59))
        #expect(FinishRules.canSave(elapsed: 60))
    }

    @Test func stepsByFiveMinutes() {
        #expect(FinishRules.lowered(3000 + 120) == 3000)
        #expect(FinishRules.lowered(3000) == 2700)
        #expect(FinishRules.lowered(120) == 60)
        #expect(FinishRules.raised(3000, elapsed: 4000) == 3300)
    }

    @Test func neverMoreThanRealElapsed() {
        #expect(FinishRules.raised(3000 + 100, elapsed: 3150) == 3150)
    }
}
