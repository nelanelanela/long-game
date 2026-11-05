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
        #expect(pose(0.07)?.face == .surprised)
        #expect(pose(0.10)?.face == .laughing)
        #expect(pose(0.60)?.face == .laughing)
        #expect(pose(0.71)?.face == nil)          // the happy face again
        #expect(pose(0.80)?.face == .wink)        // a 0.2 s wink
        #expect(pose(0.95)?.face == nil)
    }

    @Test func itLastsAboutOneSecondThenStops() {
        #expect(pose(0.99) != nil)
        #expect(pose(1.0) == nil)
        #expect(GiggleMotion.duration(of: .small, reduceMotion: false) == 1.0)
        #expect(GiggleMotion.duration(of: .big, reduceMotion: false) == 1.5)
        #expect(pose(1.49, .big) != nil)
        #expect(pose(1.5, .big) == nil)
    }

    @Test func theSquishIsAtItsDeepestAtTheEndOfTheFirstEightHundredths() {
        let p = pose(0.08)!
        #expect(abs(p.scaleX - 1.07) < 0.001)
        #expect(abs(p.scaleY - 0.92) < 0.001)
        #expect(abs(p.dy - 6) < 0.001)
    }

    @Test func theWiggleHitsEachStopOfTheSpec() {
        #expect(abs(pose(0.14)!.rotation - -8) < 0.001)
        #expect(abs(pose(0.26)!.rotation - 7) < 0.001)
        #expect(abs(pose(0.38)!.rotation - -5) < 0.001)
        #expect(abs(pose(0.50)!.rotation - 3) < 0.001)
        #expect(abs(pose(0.62)!.rotation - -1) < 0.001)
        // hops of 6 and 5 points
        #expect(abs(pose(0.14)!.dy - -6) < 0.001)
        #expect(abs(pose(0.38)!.dy - -5) < 0.001)
    }

    @Test(arguments: [GiggleKind.small, .big])
    func theSunNeverMovesMoreThanSixPointsOrTurnsMoreThanEightDegrees(kind: GiggleKind) {
        var t = 0.0
        while let p = pose(t, kind) {
            #expect(abs(p.dy) <= 6.0001)
            #expect(abs(p.rotation) <= 8.0001)
            #expect(p.scaleX <= 1.0701 && p.scaleY >= 0.9199)
            #expect(p.raysScale <= 1.0801 && p.raysScale >= 1)
            t += 0.005
        }
    }

    @Test func theSunIsBackWhereItWasWhenItEnds() {
        let p = pose(0.99)!
        #expect(abs(p.dy) < 0.2 && abs(p.rotation) < 0.001)
        #expect(p.scaleX == 1 && p.scaleY == 1)
    }

    @Test func fourSparklesPopOutAndFade() {
        let mid = pose(0.40)!
        #expect(mid.sparkles.count == 4)
        #expect(mid.sparkles.allSatisfy { $0.opacity > 0 && $0.scale > 0.3 })
        #expect(pose(0.0)!.sparkles.allSatisfy { $0.opacity == 0 })
        #expect(pose(0.95)!.sparkles.allSatisfy { $0.opacity == 0 })
        #expect(GiggleMotion.sparkleSpots.count == 4)
    }

    @Test func hapticsComeAtZeroThenAtAQuarterAndNearlyHalfASecond() {
        #expect(pose(0.0)?.hapticStep == 1)
        #expect(pose(0.24)?.hapticStep == 1)
        #expect(pose(0.25)?.hapticStep == 2)
        #expect(pose(0.44)?.hapticStep == 2)
        #expect(pose(0.45)?.hapticStep == 3)
        #expect(pose(0.9)?.hapticStep == 3)
    }

    @Test func theSpringBackSettles() {
        #expect(GiggleMotion.spring(0) == 1)
        #expect(abs(GiggleMotion.spring(0.3)) < 0.2)
        #expect(abs(GiggleMotion.spring(1.0)) < 0.001)
    }
}

@Suite("Giggle · the big laugh and the quiet versions")
struct GiggleVariantTests {
    @Test func theBigLaughSpinsTheRaysOnceAround() {
        #expect(pose(0.0, .big)!.raysSpin == 0)
        #expect(pose(1.49, .big)!.raysSpin == 360)
        var last = 0.0
        var t = 0.0
        while let p = pose(t, .big) {
            #expect(p.raysSpin >= last)
            last = p.raysSpin
            t += 0.01
        }
        #expect(pose(0.5)!.raysSpin == 0)   // the small giggle does not spin
    }

    @Test func theBigLaughKeepsLaughingUntilTheLongerClipIsDone() {
        #expect(pose(1.0, .big)?.face == .laughing)
        #expect(pose(0.8)?.face == .wink)   // the small one is already winking
        #expect(pose(0.8, .big)?.face == .laughing)
    }

    @Test func reduceMotionShowsOnlyTheLaughingFaceForEightTenths() {
        for t in stride(from: 0.0, to: 0.8, by: 0.05) {
            let p = pose(t, reduce: true)!
            #expect(p.face == .laughing)
            #expect(p.scaleX == 1 && p.scaleY == 1 && p.dy == 0 && p.rotation == 0)
            #expect(p.raysScale == 1 && p.raysSpin == 0)
            #expect(p.sparkles.allSatisfy { $0.opacity == 0 })
        }
        #expect(pose(0.8, reduce: true) == nil)
        #expect(pose(0.0, reduce: true)?.hapticStep == 1)
        #expect(pose(0.5, reduce: true)?.hapticStep == 3)   // the haptics stay as normal
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

    @Test func aTapDuringAGiggleRestartsTheAnimationButNeverStartsASecondSound() {
        var taps = GiggleTaps()
        _ = taps.tap(at: at(0), soundAllowed: true)
        taps.soundStarted(at: at(0), length: 1.25)
        let during = taps.tap(at: at(0.5), soundAllowed: true)
        #expect(during.action == .giggle)          // the animation restarts…
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
        let winkOnly = taps.tap(at: at(1.2 + 1.5 + 1.0), soundAllowed: true)
        #expect(winkOnly.action == .wink && winkOnly.playsSound == false)
        #expect(taps.tap(at: at(1.2 + 1.5 + 2.9), soundAllowed: true).action == .wink)
        #expect(taps.tap(at: at(1.2 + 1.5 + 3.1), soundAllowed: true).action == .giggle)   // the rest is over
    }

    @Test func tapsDuringTheRestDoNotCountTowardsTheNextBigLaugh() {
        var taps = GiggleTaps()
        for i in 0..<5 { _ = taps.tap(at: at(Double(i) * 0.1), soundAllowed: true) }   // big laugh at 0.4 s
        for i in 0..<10 { _ = taps.tap(at: at(2.5 + Double(i) * 0.2), soundAllowed: true) }   // winks
        #expect(taps.tap(at: at(5.0), soundAllowed: true).action == .giggle)
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

    @Test func withTheSettingOnTheSessionIsSetUpOnceAsAmbient() {
        let session = FakeAudioSession()
        let player = GiggleSoundPlayer(session: session) { [] }
        player.prepare(enabled: true)
        _ = player.play(big: false, enabled: true)
        _ = player.play(big: false, enabled: true)
        #expect(session.useAmbientCalls == 1)
    }

    @Test func itStaysQuietWhenSomethingElseWantsSilence() {
        let session = FakeAudioSession()
        session.wantsSilence = true
        let player = GiggleSoundPlayer(session: session)
        #expect(player.play(big: false, enabled: true) == nil)
        #expect(player.play(big: true, enabled: true) == nil)
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

    @Test func aTapRestartsTheAnimation() {
        let (c, _) = controller()
        c.tap(soundOn: false, reduceMotion: false, now: t0)
        let first = c.run!
        c.tap(soundOn: false, reduceMotion: false, now: t0.addingTimeInterval(0.3))
        #expect(c.run!.id != first.id)
        #expect(c.run!.start == t0.addingTimeInterval(0.3))
        #expect(c.run!.kind == .small)
    }

    @Test func fiveQuickTapsStartTheBigLaughAndThenTheRestWinks() {
        let (c, _) = controller()
        for i in 0..<5 { c.tap(soundOn: false, reduceMotion: false, now: t0.addingTimeInterval(Double(i) * 0.2)) }
        #expect(c.run?.kind == .big)
        let big = c.run!
        c.tap(soundOn: false, reduceMotion: false, now: t0.addingTimeInterval(1.0))   // during the laugh
        #expect(c.run == big)
        c.tap(soundOn: false, reduceMotion: false, now: t0.addingTimeInterval(3.0))   // during the rest
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
        #expect(entries.count > 55 && entries.count < 70)
        #expect(zip(entries, entries.dropFirst()).allSatisfy { $1.timeIntervalSince($0) <= 1.0 / 60 + 0.0001 })
    }

    @Test func afterItIsOverThereIsNothingMoreToDraw() {
        let start = Date(timeIntervalSinceReferenceDate: 3_000_000)
        let run = GiggleRun(id: 1, kind: .small, start: start, reduceMotion: false)
        let later = start.addingTimeInterval(5)
        #expect(GiggleSchedule(run: run).entries(from: later, mode: .normal) == [later])
    }
}
