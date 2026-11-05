import Testing
import Foundation
import AVFoundation
@testable import LongGame

private func pose(_ t: Double, _ kind: GiggleKind = .small, reduce: Bool = false) -> GigglePose? {
    GiggleMotion.pose(at: t, kind: kind, reduceMotion: reduce)
}

@Suite("Giggle · the sequence")
struct GiggleSequenceTests {
    @Test func theFacesFollowTheTimingTable() {
        #expect(pose(0.0)?.face == .surprised)
        #expect(pose(0.09)?.face == .surprised)
        #expect(pose(0.10)?.face == .laughing)
        #expect(pose(0.89)?.face == .laughing)
        #expect(pose(0.90)?.face == .happy)       // contented, eyes closed
        #expect(pose(1.24)?.face == .happy)       // and no wink at the end
    }

    @Test func itLastsAboutAQuarterPastOneSecondThenStops() {
        #expect(abs(GiggleMotion.duration(of: .small, reduceMotion: false) - 1.25) < 0.0001)
        #expect(pose(1.24) != nil)
        #expect(pose(1.25) == nil)
        #expect(abs(GiggleMotion.duration(of: .big, reduceMotion: false) - 1.73) < 0.0001)
        #expect(pose(1.72, .big) != nil)
        #expect(pose(1.74, .big) == nil)
    }

    @Test func theGaspStretchesToNinetyFourByOneHundredEightAndUpFour() {
        let p = pose(0.0999)!
        #expect(abs(p.scaleX - 0.94) < 0.001)
        #expect(abs(p.scaleY - 1.08) < 0.001)
        #expect(abs(p.dy - -4) < 0.01)
    }

    @Test func eachBounceSquashesThenStretchesAndGetsSmaller() {
        // bounce 1: starts at 0.10, squash peak a quarter in (0.14), stretch peak at three quarters (0.22)
        let squash = pose(0.14)!
        #expect(squash.scaleX > 1.03 && squash.scaleY < 0.97 && squash.dy > 1.5)
        let stretch = pose(0.22)!
        #expect(stretch.scaleX < 0.99 && stretch.scaleY > 1.02 && stretch.dy < -3)
        // bounce 5 is smaller than bounce 1
        let late = pose(0.10 + 4 * 0.16 + 0.12)!
        #expect(late.dy > -5 && abs(late.dy) < abs(stretch.dy))
    }

    @Test func theSunTipsBackFiveDegreesAndSpringsBack() {
        #expect(abs(pose(0.5)!.rotation - -5) < 0.001)
        #expect(abs(pose(0.89)!.rotation - -5) < 0.001)
        #expect(abs(pose(1.24)!.rotation) < 0.5)
    }

    @Test(arguments: [GiggleKind.small, .big])
    func theSunNeverMovesMoreThanSixPointsOrTurnsMoreThanFiveDegrees(kind: GiggleKind) {
        var t = 0.0
        while let p = pose(t, kind) {
            #expect(abs(p.dy) <= 6.0001)
            #expect(abs(p.rotation) <= 5.0001)
            #expect(p.scaleX <= 1.0601 && p.scaleX >= 0.9399 && p.scaleY >= 0.9399 && p.scaleY <= 1.0801)
            #expect(p.raysScale <= 1.0801 && p.raysScale >= 1)
            t += 0.005
        }
    }

    @Test func oneTinyHiccupOfTwoPointsAtOnePointZeroFive() {
        let p = pose(1.05)!
        #expect(abs(p.dy - -2) < 0.1)
        #expect(abs(pose(1.24)!.dy) < 0.01)
    }

    @Test func theBlushDeepensThenFadesBack() {
        #expect(pose(0.0)!.blush == 0)
        #expect(pose(0.5)!.blush == 1)
        #expect(pose(1.075)!.blush > 0.3 && pose(1.075)!.blush < 0.7)
        #expect(pose(1.249)!.blush < 0.01)
    }

    @Test func theSunIsBackWhereItWasWhenItEnds() {
        let p = pose(1.249)!
        #expect(abs(p.dy) < 0.05 && abs(p.rotation) < 0.5)
        #expect(abs(p.scaleX - 1) < 0.0001 && abs(p.scaleY - 1) < 0.0001)
    }

    @Test func fourSparklesPopOutAndFade() {
        let mid = pose(0.40)!
        #expect(mid.sparkles.count == 4)
        #expect(mid.sparkles.allSatisfy { $0.opacity > 0 && $0.scale > 0.3 })
        #expect(pose(0.0)!.sparkles.allSatisfy { $0.opacity == 0 })
        #expect(pose(1.24)!.sparkles.allSatisfy { $0.opacity == 0 })
        #expect(GiggleMotion.sparkleSpots.count == 4)
    }

    @Test func hapticsAreSoftAtTheGaspThenLightOnTheFirstThreeBounces() {
        #expect(pose(0.0)?.hapticStep == 1)
        #expect(pose(0.11)?.hapticStep == 1)
        #expect(pose(0.12)?.hapticStep == 2)
        #expect(pose(0.28)?.hapticStep == 3)
        #expect(pose(0.44)?.hapticStep == 4)
        #expect(pose(1.2)?.hapticStep == 4)
    }

    @Test func theSpringBackSettles() {
        #expect(GiggleMotion.spring(0) == 1)
        #expect(abs(GiggleMotion.spring(1.0)) < 0.001)
    }

    @Test func theSoundStartsAfterTheGasp() {
        #expect(GiggleSoundPlayer.startDelay == 0.10)
    }
}

@Suite("Giggle · the long laugh and the quiet versions")
struct GiggleVariantTests {
    @Test func theLongLaughHasEightBouncesAndSpinsTheRaysOnceAround() {
        #expect(GiggleMotion.laughEnd(of: .big) == 0.10 + 8 * 0.16)
        #expect(pose(0.0, .big)!.raysSpin == 0)
        #expect(pose(1.72, .big)!.raysSpin == 360)
        var last = 0.0
        var t = 0.0
        while let p = pose(t, .big) {
            #expect(p.raysSpin >= last)
            last = p.raysSpin
            t += 0.01
        }
        #expect(pose(0.5)!.raysSpin == 0)   // the normal laugh does not spin
    }

    @Test func theLongLaughKeepsLaughingLonger() {
        #expect(pose(1.0, .big)?.face == .laughing)
        #expect(pose(1.0)?.face == .happy)   // the normal one is already contented
    }

    @Test func extraBouncesLengthenTheLaughByTheirShare() {
        let normal = GiggleMotion.duration(of: .small, reduceMotion: false)
        let more = GiggleMotion.duration(of: .small, reduceMotion: false, extraBounces: 2)
        #expect(abs(more - normal - 0.32) < 0.0001)
        #expect(GiggleMotion.pose(at: 1.0, kind: .small, reduceMotion: false, extraBounces: 2)?.face == .laughing)
        #expect(GiggleMotion.smallBounces + GiggleMotion.maxBounces - GiggleMotion.smallBounces < GiggleMotion.bigBounces)
    }

    @Test func reduceMotionShowsOnlyTheBabyLaughFaceForEightTenths() {
        for t in stride(from: 0.0, to: 0.8, by: 0.05) {
            let p = pose(t, reduce: true)!
            #expect(p.face == .laughing)
            #expect(p.scaleX == 1 && p.scaleY == 1 && p.dy == 0 && p.rotation == 0)
            #expect(p.raysScale == 1 && p.raysSpin == 0)
            #expect(p.sparkles.allSatisfy { $0.opacity == 0 })
        }
        #expect(pose(0.8, reduce: true) == nil)
        #expect(pose(0.0, reduce: true)?.hapticStep == 1)
        #expect(pose(0.5, reduce: true)?.hapticStep == 4)   // the haptics stay as normal
        #expect(pose(1.0, .big, reduce: true) == nil)
    }

    @Test func theSoftWinkOnlyWinksAndNeverMoves() {
        for t in stride(from: 0.0, to: 0.6, by: 0.05) {
            let p = pose(t, .wink)!
            #expect(p.face == .wink)
            #expect(p.dy == 0 && p.rotation == 0 && p.scaleX == 1 && p.raysSpin == 0 && p.hapticStep == 0)
        }
        #expect(pose(0.6, .wink) == nil)
    }
}

@Suite("Giggle · taps")
struct GiggleTapTests {
    private let t0 = Date(timeIntervalSinceReferenceDate: 1_000_000)
    private func at(_ s: Double) -> Date { t0.addingTimeInterval(s) }

    @Test func aFirstTapGigglesWithSound() {
        var taps = GiggleTaps()
        #expect(taps.tap(at: at(0), soundAllowed: true) == GiggleTapResponse(action: .giggle, playsSound: true))
    }

    @Test func aTapDuringAGiggleNeverStartsASecondSound() {
        var taps = GiggleTaps()
        _ = taps.tap(at: at(0), soundAllowed: true)
        taps.soundStarted(at: at(0), length: 1.25)
        let during = taps.tap(at: at(0.5), soundAllowed: true)
        #expect(during.action == .giggle)          // the controller adds bounces…
        #expect(during.playsSound == false)        // …but the clip is left alone
        #expect(taps.tap(at: at(1.3), soundAllowed: true).playsSound)   // once it has finished, a new laugh may start
    }

    @Test func withTheSoundOffNothingIsEverAskedToPlay() {
        var taps = GiggleTaps()
        for i in 0..<4 { #expect(taps.tap(at: at(Double(i) * 0.3), soundAllowed: false).playsSound == false) }
        let fifth = taps.tap(at: at(1.2), soundAllowed: false)
        #expect(fifth.action == .bigLaugh)
        #expect(fifth.playsSound == false)
    }

    @Test func fiveTapsInTwoSecondsMakeTheBigLaugh() {
        var taps = GiggleTaps()
        for i in 0..<4 { #expect(taps.tap(at: at(Double(i) * 0.4), soundAllowed: true).action == .giggle) }
        taps.soundStarted(at: at(0.4), length: 1.25)
        let fifth = taps.tap(at: at(1.6), soundAllowed: true)
        #expect(fifth.action == .bigLaugh)
        #expect(fifth.playsSound)
        #expect(fifth.interruptsSound)   // one clip at a time: the big one replaces the one still playing
    }

    @Test func fiveSlowTapsDoNot() {
        var taps = GiggleTaps()
        for i in 0..<8 {
            #expect(taps.tap(at: at(Double(i) * 0.6), soundAllowed: true).action == .giggle)
        }
    }

    @Test func afterTheBigLaughTapsAreIgnoredThenOnlyWinkForThreeSeconds() {
        var taps = GiggleTaps()
        for i in 0..<5 { _ = taps.tap(at: at(Double(i) * 0.3), soundAllowed: true) }   // big laugh at 1.2 s
        #expect(taps.tap(at: at(2.0), soundAllowed: true).action == .ignore)          // still laughing
        let winkOnly = taps.tap(at: at(1.2 + 1.73 + 1.0), soundAllowed: true)
        #expect(winkOnly.action == .wink && winkOnly.playsSound == false)
        #expect(taps.tap(at: at(1.2 + 1.73 + 2.9), soundAllowed: true).action == .wink)
        #expect(taps.tap(at: at(1.2 + 1.73 + 3.1), soundAllowed: true).action == .giggle)   // the rest is over
    }

    @Test func tapsDuringTheRestDoNotCountTowardsTheNextBigLaugh() {
        var taps = GiggleTaps()
        for i in 0..<5 { _ = taps.tap(at: at(Double(i) * 0.1), soundAllowed: true) }   // big laugh at 0.4 s
        for i in 0..<10 { _ = taps.tap(at: at(2.5 + Double(i) * 0.2), soundAllowed: true) }   // winks
        #expect(taps.tap(at: at(5.5), soundAllowed: true).action == .giggle)
    }
}

@Suite("Giggle · which clip")
struct GiggleClipPickerTests {
    @Test func neverTheSameClipTwiceInARow() {
        var picker = GiggleClipPicker(count: 4)
        var generator = SystemRandomNumberGenerator()
        var last: Int?
        var seen = Set<Int>()
        for _ in 0..<500 {
            let pick = picker.next(using: &generator)!
            #expect(pick != last)
            #expect((0..<4).contains(pick))
            seen.insert(pick)
            last = pick
        }
        #expect(seen == [0, 1, 2, 3])
    }

    @Test func twoClipsTakeTurns() {
        var picker = GiggleClipPicker(count: 2)
        var generator = SystemRandomNumberGenerator()
        let first = picker.next(using: &generator)!
        #expect(picker.next(using: &generator) == 1 - first)
        #expect(picker.next(using: &generator) == first)
    }

    @Test func oneClipPlaysEveryTimeAndNoClipsGivesNothing() {
        var generator = SystemRandomNumberGenerator()
        var one = GiggleClipPicker(count: 1)
        #expect(one.next(using: &generator) == 0)
        #expect(one.next(using: &generator) == 0)
        var none = GiggleClipPicker(count: 0)
        #expect(none.next(using: &generator) == nil)
    }
}

@MainActor
private final class FakeAudioSession: GiggleAudioSession {
    var useAmbientCalls = 0
    var wantsSilence = false
    var otherAudioWantsSilence: Bool { wantsSilence }
    func useAmbient() { useAmbientCalls += 1 }
}

@MainActor
@Suite("Giggle · sound")
struct GiggleSoundTests {
    @Test func withTheSettingOffTheAudioSessionIsNeverTouched() {
        let session = FakeAudioSession()
        var loads = 0
        let player = GiggleSoundPlayer(session: session) { loads += 1; return [] }
        player.prepare(enabled: false)
        #expect(player.play(big: false, enabled: false) == nil)
        #expect(player.play(big: true, enabled: false) == nil)
        #expect(session.useAmbientCalls == 0)
        #expect(loads == 0)
    }

    @Test func withTheSettingOnTheSessionIsWokenAsAmbientBeforeEveryGiggle() {
        let session = FakeAudioSession()
        let player = GiggleSoundPlayer(session: session) { [] }
        player.prepare(enabled: true)
        _ = player.play(big: false, enabled: true)
        _ = player.play(big: false, enabled: true)
        #expect(session.useAmbientCalls == 3)
    }

    @Test func itStillGigglesWhenOtherAudioIsPlaying() {
        let session = FakeAudioSession()
        session.wantsSilence = true
        let player = GiggleSoundPlayer(session: session)
        #expect(player.play(big: false, enabled: true) != nil)
        #expect(player.play(big: true, enabled: true) != nil)
    }

    @Test func theBundledClipsAreShortAndTheLongestIsTheBigOne() {
        let clips = GiggleSoundPlayer.bundledClips()
        #expect(clips.count >= 2)
        for clip in clips { #expect(clip.duration >= 0.9 && clip.duration <= 1.5) }
        let longest = clips.map(\.duration).max() ?? 0
        #expect(longest <= GiggleMotion.bigDuration)
        #expect(clips.filter { $0.duration == longest }.count == 1)
        #expect(GiggleSoundPlayer.volume == 0.7)
    }

    @Test func theGiggleSoundIsOnByDefault() {
        #expect(AppSettings().giggleSound)
    }
}

@MainActor
@Suite("Giggle · the controller")
struct GiggleControllerTests {
    private func controller() -> (GiggleController, FakeAudioSession) {
        let session = FakeAudioSession()
        return (GiggleController(player: GiggleSoundPlayer(session: session) { [] }), session)
    }
    private let t0 = Date(timeIntervalSinceReferenceDate: 2_000_000)

    @Test func theTimerGetsOnlyASoftWinkAndNeverTouchesAudio() {
        let (c, session) = controller()
        c.tap(soundOn: true, reduceMotion: false, winkOnly: true, now: t0)
        #expect(c.run?.kind == .wink)
        #expect(session.useAmbientCalls == 0)
        #expect(c.run?.pose(at: t0.addingTimeInterval(0.1))?.face == .wink)
    }

    @Test func aTapDuringTheLaughAddsTwoBouncesInsteadOfRestarting() {
        let (c, _) = controller()
        c.tap(soundOn: false, reduceMotion: false, now: t0)
        let first = c.run!
        c.tap(soundOn: false, reduceMotion: false, now: t0.addingTimeInterval(0.3))
        #expect(c.run!.id == first.id)
        #expect(c.run!.start == first.start)
        #expect(c.run!.extraBounces == 2)
        #expect(c.run!.token != first.token)
        #expect(c.run!.kind == .small)
        #expect(abs(c.run!.duration - first.duration - 0.32) < 0.0001)
        // a further tap in the same laugh does not stretch it past seven bounces
        c.tap(soundOn: false, reduceMotion: false, now: t0.addingTimeInterval(0.5))
        #expect(c.run!.extraBounces == 2)
    }

    @Test func aTapAfterTheBouncingHasStoppedStartsANewLaugh() {
        let (c, _) = controller()
        c.tap(soundOn: false, reduceMotion: false, now: t0)
        let first = c.run!
        c.tap(soundOn: false, reduceMotion: false, now: t0.addingTimeInterval(1.0))   // contented end
        #expect(c.run!.id != first.id)
        #expect(c.run!.extraBounces == 0)
        #expect(c.run!.start == t0.addingTimeInterval(1.0))
    }

    @Test func fiveQuickTapsStartTheLongLaughAndThenTheRestWinks() {
        let (c, _) = controller()
        for i in 0..<5 { c.tap(soundOn: false, reduceMotion: false, now: t0.addingTimeInterval(Double(i) * 0.2)) }
        #expect(c.run?.kind == .big)
        #expect(c.run?.extraBounces == 0)
        let big = c.run!
        c.tap(soundOn: false, reduceMotion: false, now: t0.addingTimeInterval(1.0))   // during the laugh
        #expect(c.run == big)
        c.tap(soundOn: false, reduceMotion: false, now: t0.addingTimeInterval(3.5))   // during the rest
        #expect(c.run?.kind == .wink)
    }

    @Test func reduceMotionShortensTheRun() {
        let (c, _) = controller()
        c.tap(soundOn: false, reduceMotion: true, now: t0)
        #expect(c.run?.duration == 0.8)
        #expect(c.run?.pose(at: t0.addingTimeInterval(0.5))?.face == .laughing)
        #expect(c.run?.pose(at: t0.addingTimeInterval(0.81)) == nil)
    }

    @Test func withTheSoundOffTappingNeverTouchesTheAudioSession() {
        let (c, session) = controller()
        c.prepare(soundOn: false)
        for i in 0..<6 { c.tap(soundOn: false, reduceMotion: false, now: t0.addingTimeInterval(Double(i) * 0.2)) }
        #expect(session.useAmbientCalls == 0)
    }
}

@Suite("Giggle · redraws only while it lasts")
struct GiggleScheduleTests {
    @Test func aRestingSunHasASingleEntry() {
        let now = Date()
        #expect(GiggleSchedule(run: nil).entries(from: now, mode: .normal) == [now])
    }

    @Test func aRunningGiggleRedrawsAtSixtyAFrameFromStartToFinish() {
        let start = Date(timeIntervalSinceReferenceDate: 3_000_000)
        let run = GiggleRun(id: 1, kind: .small, start: start, reduceMotion: false)
        let entries = GiggleSchedule(run: run).entries(from: start, mode: .normal)
        #expect(entries.first == start)
        #expect(entries.last == run.end)
        #expect(entries.count > 70 && entries.count < 85)
        #expect(zip(entries, entries.dropFirst()).allSatisfy { $1.timeIntervalSince($0) <= 1.0 / 60 + 0.0001 })
    }

    @Test func afterItIsOverThereIsNothingMoreToDraw() {
        let start = Date(timeIntervalSinceReferenceDate: 3_000_000)
        let run = GiggleRun(id: 1, kind: .small, start: start, reduceMotion: false)
        let later = start.addingTimeInterval(5)
        #expect(GiggleSchedule(run: run).entries(from: later, mode: .normal) == [later])
    }
}
