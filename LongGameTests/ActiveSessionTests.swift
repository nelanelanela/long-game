import Testing
import Foundation
@testable import LongGame

struct ActiveSessionTests {
    let craft = UUID()
    let t0 = Date(timeIntervalSinceReferenceDate: 3_000_000)

    func state(start: TimeInterval = 0) -> TimerState {
        TimerState(craftId: craft, craftName: "Piano", startedAt: t0.addingTimeInterval(start))
    }

    func record(_ s: TimerState, device: String, changed: TimeInterval, ended: TimeInterval? = nil) -> ActiveSessionRecord {
        ActiveSessionRecord(state: s, deviceName: device, changedAt: t0.addingTimeInterval(changed),
                            endedAt: ended.map { t0.addingTimeInterval($0) })
    }

    // MARK: Which session counts

    @Test func theEarlierStartWins() {
        let mac = record(state(start: 0), device: "Mac", changed: 0)
        let phone = record(state(start: 3), device: "iPhone", changed: 3)
        #expect(ActiveSessionSync.winner([phone, mac])?.deviceName == "Mac")
        #expect(ActiveSessionSync.losers([phone, mac]).map(\.deviceName) == ["iPhone"])
    }

    @Test func aTieGoesTheSameWayOnEveryDevice() {
        let a = record(state(), device: "Mac", changed: 0)
        let b = record(state(), device: "iPhone", changed: 0)
        // Same craft, same moment: it is the same session, so there is one winner and nothing loses.
        #expect(ActiveSessionSync.losers([a, b]).isEmpty)
        #expect(ActiveSessionSync.winner([a, b]) != nil)
    }

    @Test func aDeviceThatStartedLaterShowsTheEarlierSession() {
        let mac = record(state(start: 0), device: "Mac", changed: 0)
        let action = ActiveSessionSync.action(local: state(start: 2), localChangedAt: t0.addingTimeInterval(2), records: [mac])
        #expect(action == .adopt(state(start: 0), changedAt: t0, startedOn: "Mac"))
    }

    @Test func theDeviceThatStartedFirstKeepsItsOwn() {
        let phone = record(state(start: 2), device: "iPhone", changed: 2)
        #expect(ActiveSessionSync.action(local: state(start: 0), localChangedAt: t0, records: [phone]) == .keep)
    }

    @Test func aDeviceWithNothingRunningPicksUpTheSession() {
        let mac = record(state(start: 0), device: "Mac", changed: 0)
        let action = ActiveSessionSync.action(local: nil, localChangedAt: .distantPast, records: [mac])
        #expect(action == .adopt(state(start: 0), changedAt: t0, startedOn: "Mac"))
        #expect(ActiveSessionSync.action(local: nil, localChangedAt: .distantPast, records: []) == .keep)
    }

    // MARK: Pause and finish from the other device

    @Test func pausingOnTheOtherDeviceIsTaken() {
        var paused = state()
        paused.pause(at: t0.addingTimeInterval(600))
        let theirs = record(paused, device: "Mac", changed: 600)
        let action = ActiveSessionSync.action(local: state(), localChangedAt: t0, records: [theirs])
        #expect(action == .adopt(paused, changedAt: t0.addingTimeInterval(600), startedOn: "Mac"))
    }

    @Test func resumingOnTheOtherDeviceIsTaken() {
        var resumed = state()
        resumed.pause(at: t0.addingTimeInterval(600))
        var local = resumed
        resumed.resume(at: t0.addingTimeInterval(900))
        let theirs = record(resumed, device: "iPhone", changed: 900)
        let action = ActiveSessionSync.action(local: local, localChangedAt: t0.addingTimeInterval(600), records: [theirs])
        #expect(action == .adopt(resumed, changedAt: t0.addingTimeInterval(900), startedOn: "iPhone"))
        local.resume(at: t0.addingTimeInterval(900))
        #expect(local.elapsed(at: t0.addingTimeInterval(1_200)) == resumed.elapsed(at: t0.addingTimeInterval(1_200)))
    }

    @Test func aNewerChangeHereIsNotOverwrittenByAnOlderRecord() {
        var mine = state()
        mine.pause(at: t0.addingTimeInterval(700))
        let old = record(state(), device: "Mac", changed: 0)
        #expect(ActiveSessionSync.action(local: mine, localChangedAt: t0.addingTimeInterval(700), records: [old]) == .keep)
    }

    @Test func finishingOnTheOtherDeviceStopsTheTimerHere() {
        let ended = record(state(), device: "Mac", changed: 1_800, ended: 1_800)
        let action = ActiveSessionSync.action(local: state(), localChangedAt: t0, records: [ended])
        #expect(action == .stop(at: t0.addingTimeInterval(1_800)))
    }

    @Test func aFinishedSessionIsNotPickedUpAgain() {
        let ended = record(state(), device: "Mac", changed: 1_800, ended: 1_800)
        #expect(ActiveSessionSync.action(local: nil, localChangedAt: .distantPast, records: [ended]) == .keep)
    }

    @Test func aFinishWinsEvenIfAnOlderCopyArrivesLater() {
        let live = record(state(), device: "iPhone", changed: 100)
        let ended = record(state(), device: "Mac", changed: 1_800, ended: 1_800)
        let merged = ActiveSessionSync.merge([ended, live])
        #expect(merged.count == 1)
        #expect(merged[0].endedAt != nil)
    }

    @Test func aSessionNotSharedYetIsLeftAlone() {
        #expect(ActiveSessionSync.action(local: state(), localChangedAt: t0, records: []) == .keep)
    }

    @Test func aLosingSessionEndsAndTheWinnerCarriesOn() {
        // The phone started 3 s after the Mac. Once both records are in iCloud, the phone gives way.
        let mac = record(state(start: 0), device: "Mac", changed: 0)
        let phone = record(state(start: 3), device: "iPhone", changed: 3)
        let phoneAction = ActiveSessionSync.action(local: state(start: 3), localChangedAt: t0.addingTimeInterval(3), records: [mac, phone])
        let macAction = ActiveSessionSync.action(local: state(start: 0), localChangedAt: t0, records: [mac, phone])
        #expect(phoneAction == .adopt(state(start: 0), changedAt: t0, startedOn: "Mac"))
        #expect(macAction == .keep)
    }

    // MARK: Housekeeping and words

    @Test func endedRecordsAreDroppedAfterADay() {
        let ended = record(state(), device: "Mac", changed: 0, ended: 0)
        #expect(!ActiveSessionSync.isStale(ended, now: t0.addingTimeInterval(3_600)))
        #expect(ActiveSessionSync.isStale(ended, now: t0.addingTimeInterval(25 * 3_600)))
        #expect(!ActiveSessionSync.isStale(record(state(), device: "Mac", changed: 0), now: t0.addingTimeInterval(99 * 3_600)))
    }

    @Test func theRecordRebuildsTheTimerExactly() {
        var s = state()
        s.pause(at: t0.addingTimeInterval(300)); s.resume(at: t0.addingTimeInterval(500))
        let r = record(s, device: "Mac", changed: 500)
        #expect(r.timerState == s)
        #expect(r.timerState.elapsed(at: t0.addingTimeInterval(1_000)) == 800)
    }

    @Test func startedOnWording() {
        #expect(ActiveSessionText.startedOn("Natalia’s Mac") == "Started on Natalia’s Mac")
    }
}
