import Foundation
import Testing
@testable import LongGame

struct TimerSunriseTests {
    /// Fractions like 0.95 are not exact in binary, so layer opacities are compared with a tiny tolerance.
    private func same(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 1e-9 }

    private let stretch: TimeInterval = 105 * 60   // 1 h 45, the board's example

    // MARK: Progress

    @Test func theFirstSessionOfTheDayStartsInTheDark() {
        #expect(TimerSunrise.progress(doneSaved: 0, running: 0, target: stretch) == 0)
    }

    @Test func aLaterSessionStartsWhereTheDayLeftOff() {
        // 40 minutes saved this morning: the afternoon session starts 40/105 of the way up.
        let p = TimerSunrise.progress(doneSaved: 40 * 60, running: 0, target: stretch)
        #expect(abs(p - 40.0 / 105) < 1e-9)
    }

    @Test func theRunningSessionAddsToTheDay() {
        let p = TimerSunrise.progress(doneSaved: 40 * 60, running: 25 * 60, target: stretch)
        #expect(abs(p - 65.0 / 105) < 1e-9)
    }

    @Test func onceTheStretchIsCoveredTheSunStaysUp() {
        #expect(TimerSunrise.progress(doneSaved: 0, running: stretch, target: stretch) == 1)
        #expect(TimerSunrise.progress(doneSaved: 0, running: stretch * 3, target: stretch) == 1)
        #expect(TimerSunrise.progress(doneSaved: stretch * 2, running: 0, target: stretch) == 1)
    }

    @Test func withoutAWeeklyPaceAnHourStandsIn() {
        #expect(TimerSunrise.progress(doneSaved: 0, running: 1800, target: nil) == 0.5)
    }

    // MARK: Sun position

    @Test func theSunClimbsFromTheHorizonToTheTop() {
        // The 844 pt board: horizon 470, rise 245.
        #expect(TimerSunrise.sunCentreY(p: 0, horizonY: 470, rise: 245) == 470)
        #expect(TimerSunrise.sunCentreY(p: 1, horizonY: 470, rise: 245) == 225)
        #expect(TimerSunrise.sunCentreY(p: 0.5, horizonY: 470, rise: 245) == 347.5)
        #expect(TimerSunrise.sunCentreY(p: 2, horizonY: 470, rise: 245) == 225)
    }

    @Test func pausingSinksTheSun24Points() {
        #expect(TimerSunrise.sunCentreY(p: 0.58, horizonY: 470, rise: 245, paused: true)
                == TimerSunrise.sunCentreY(p: 0.58, horizonY: 470, rise: 245) + 24)
    }

    @Test func theFractionsMatchTheBoard() {
        #expect(abs(TimerSunrise.horizonFraction * 844 - 470) < 1e-9)
        #expect(abs(TimerSunrise.riseFraction * 844 - 245) < 1e-9)
    }

    // MARK: Layers

    @Test func theNightFadesOverTheFirstHalf() {
        #expect(same(TimerSunrise.nightOpacity(p: 0), 1))
        #expect(same(TimerSunrise.nightOpacity(p: 0.25), 0.5))
        #expect(same(TimerSunrise.nightOpacity(p: 0.5), 0))
        #expect(same(TimerSunrise.nightOpacity(p: 1), 0))
    }

    @Test func dawnPeaksAtHalfThenFadesOutByNinetyFivePercent() {
        #expect(same(TimerSunrise.dawnOpacity(p: 0), 0))
        #expect(same(TimerSunrise.dawnOpacity(p: 0.5), 1))
        #expect(abs(TimerSunrise.dawnOpacity(p: 0.725) - 0.5) < 1e-9)
        #expect(same(TimerSunrise.dawnOpacity(p: 0.95), 0))
        #expect(same(TimerSunrise.dawnOpacity(p: 1), 0))
    }

    @Test func theDaySkyFadesInFromHalfToNinetyFive() {
        #expect(same(TimerSunrise.dayOpacity(p: 0.5), 0))
        #expect(same(TimerSunrise.dayOpacity(p: 0.95), 1))
        #expect(same(TimerSunrise.dayOpacity(p: 0.2), 0))
    }

    @Test func theDayLandFadesInOnTopFromFortyFiveToEightyFive() {
        #expect(same(TimerSunrise.landDayOpacity(p: 0.45), 0))
        #expect(abs(TimerSunrise.landDayOpacity(p: 0.65) - 0.5) < 1e-9)
        #expect(same(TimerSunrise.landDayOpacity(p: 0.85), 1))
    }

    @Test func theSeaIsNeverTransparent() {
        // The layer underneath (the night land and the navy fill) has no fade at all, so at every p some layer is
        // fully opaque there: the night land is always drawn at 1 and the day land only ever fades in over it.
        for step in 0...100 {
            let p = Double(step) / 100
            let top = TimerSunrise.landDayOpacity(p: p)
            #expect(top >= 0 && top <= 1)
        }
    }

    @Test func textTurnsFromWhiteToNavyBetweenFiftyFiveAndEightyFive() {
        #expect(TimerSunrise.inkHex(p: 0.55) == 0xFFFFFF)
        #expect(TimerSunrise.inkHex(p: 0.85) == 0x16244A)
        #expect(TimerSunrise.inkHex(p: 0) == 0xFFFFFF)
        #expect(TimerSunrise.inkHex(p: 1) == 0x16244A)
    }

    @Test func theBigNumberGoesFromGoldToEmber() {
        #expect(TimerSunrise.goldHex(p: 0) == 0xFFD66B)
        #expect(TimerSunrise.goldHex(p: 1) == 0xB4561A)
    }

    @Test func theGlowGrowsWithTheDayAndDimsWhenPaused() {
        #expect(same(TimerSunrise.glowOpacity(p: 0, paused: false), 0.35))
        #expect(same(TimerSunrise.glowOpacity(p: 1, paused: false), 1))
        #expect(abs(TimerSunrise.glowOpacity(p: 1, paused: true) - 0.4) < 1e-9)
    }

    // MARK: Moments

    @Test func theCelebrateFaceLastsOneAndAThirdSeconds() {
        #expect(!TimerSunrise.isCelebrating(sinceCovered: nil))
        #expect(!TimerSunrise.isCelebrating(sinceCovered: -1))
        #expect(TimerSunrise.isCelebrating(sinceCovered: 0))
        #expect(TimerSunrise.isCelebrating(sinceCovered: 1.29))
        #expect(!TimerSunrise.isCelebrating(sinceCovered: 1.3))
    }

    @Test func theQuietLineFollowsTheState() {
        #expect(TimerSunrise.note(paused: false, covered: false, secondsToNextRay: 97) == .nextRay(seconds: 97))
        #expect(TimerSunrise.note(paused: false, covered: true, secondsToNextRay: 97) == .covered)
        #expect(TimerSunrise.note(paused: true, covered: true, secondsToNextRay: 97) == .paused)
    }

    @Test func theBarShowsTheEarlierPartSofterThanThePartPlayedNow() {
        let bar = TimerSunrise.bar(doneSaved: 40 * 60, running: 25 * 60, target: stretch)
        #expect(abs(bar.before - 40.0 / 105) < 1e-9)
        #expect(abs(bar.now - 25.0 / 105) < 1e-9)
        let over = TimerSunrise.bar(doneSaved: 40 * 60, running: 500 * 60, target: stretch)
        #expect(abs(over.before + over.now - 1) < 1e-9)
    }

    // MARK: Saved moment

    @Test func theSavedProgressCountsTheSessionJustSaved() {
        let plan = StretchPlan(target: 6300, doneSaved: 1800)
        let m = SavedMoment.make(plan: plan, duration: 2400, startedToday: true)
        #expect(abs(m.p - 4200.0 / 6300) < 1e-9)
        #expect(m.todayTotal == 4200)
        #expect(m.added == 2400)
    }

    @Test func theCoveredLineOnlyAppearsWhenTheSaveReachesTheStretch() {
        let plan = StretchPlan(target: 6300, doneSaved: 1800)
        let short = SavedMoment.make(plan: plan, duration: 2400, startedToday: true)
        #expect(!short.covered)
        #expect(short.accentLine == "35 m left of today's stretch")
        let reaches = SavedMoment.make(plan: plan, duration: 4500, startedToday: true)
        #expect(reaches.covered && reaches.p == 1)
        #expect(reaches.accentLine == "Today's stretch covered.")
        #expect(reaches.spoken.hasSuffix("Today's stretch covered."))
        #expect(!short.spoken.contains("covered"))
    }

    @Test func aSessionFromYesterdayLeavesTodayAsItWas() {
        let m = SavedMoment.make(plan: StretchPlan(target: 6300, doneSaved: 1800), duration: 2400, startedToday: false)
        #expect(m.todayTotal == 1800)
        #expect(abs(m.p - 1800.0 / 6300) < 1e-9)
    }

    @Test func withoutAStretchThereIsNoAccentLine() {
        let m = SavedMoment.make(plan: StretchPlan(target: nil, doneSaved: 0), duration: 600, startedToday: true)
        #expect(m.accentLine == nil && !m.covered)
    }
}

