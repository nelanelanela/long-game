import Testing
@testable import LongGame

struct OpeningSunriseTests {
    func plan(cold: Bool = true, from: OpeningSource = .icon, session: Bool = false, reduceMotion: Bool = false,
              voiceOver: Bool = false, onboarded: Bool = true) -> OpeningPlan {
        openingStyle(coldStart: cold, openedFrom: from, sessionRunning: session, reduceMotion: reduceMotion,
                     voiceOver: voiceOver, onboarded: onboarded)
    }

    @Test func aColdStartFromTheIconPlaysTheWholeSunrise() {
        #expect(plan() == OpeningPlan(style: .full, landing: .home))
    }

    @Test func comingBackFromTheBackgroundPlaysNothing() {
        #expect(plan(cold: false).style == .skip)
    }

    @Test(arguments: [OpeningSource.widget, .liveActivity, .notification, .url])
    func openingFromAnythingButTheIconPlaysNothing(source: OpeningSource) {
        #expect(plan(from: source).style == .skip)
    }

    @Test func aRunningSessionStillGetsTheWholeSunrise() {
        // The Launch board makes no exception for a running session.
        #expect(plan(session: true) == OpeningPlan(style: .full, landing: .home))
    }

    @Test func reduceMotionGetsTheShortFade() {
        #expect(plan(reduceMotion: true).style == .short)
    }

    @Test func voiceOverGetsTheShortFade() {
        #expect(plan(voiceOver: true).style == .short)
    }

    @Test func beforeOnboardingItEndsOnWelcome() {
        #expect(plan(onboarded: false) == OpeningPlan(style: .full, landing: .welcome))
        #expect(plan(reduceMotion: true, onboarded: false) == OpeningPlan(style: .short, landing: .welcome))
    }

    @Test func darkModePlaysTheWholeSunriseToo() {
        // The opening is night to dawn whatever the phone's look, so dark mode no longer stops it at dusk.
        #expect(plan() == OpeningPlan(style: .full, landing: .home))
    }

    @Test func theShortFadeStillBeatsTheFullSunrise() {
        #expect(plan(reduceMotion: true).style == .short)
        #expect(plan(session: true, voiceOver: true).style == .short)
    }

    @Test func aWarmStartOrLinkStaysSilentEvenInDarkModeOrWithReduceMotion() {
        #expect(plan(cold: false, reduceMotion: true).style == .skip)
        #expect(plan(from: .url, voiceOver: true).style == .skip)
    }

    // MARK: Timings

    @Test func theLengthsMatchTheSpec() {
        #expect(OpeningStyle.full.duration == 2.2)
        #expect(OpeningStyle.short.duration == 0.3)
        #expect(OpeningStyle.skip.duration == 0)
    }

    @Test func theFullSunriseStartsOnTheNightFrame() {
        let f = OpeningTimeline.frame(at: 0, style: .full)
        #expect(f == OpeningFrame(sky: 0, rise: 0, awake: 0, eyesOpen: 0, glide: 0, scenery: 1))
    }

    @Test func theBoardsKeyframesLandOnTheAppsPhases() {
        // Launch.dc.html: 20% → 0 s, 50% → 1.1 s, 58% → 1.4 s, 72% → 2.2 s.
        #expect(abs(OpeningTimeline.boardTime(20) - 0) < 1e-9)
        #expect(abs(OpeningTimeline.boardTime(50) - 1.1) < 1e-9)
        #expect(abs(OpeningTimeline.boardTime(58) - 1.4) < 1e-9)
        #expect(abs(OpeningTimeline.boardTime(72) - 2.2) < 1e-9)
        // The moments in the update 39 table, to two decimals.
        #expect(abs(OpeningTimeline.wakeStart - 0.55) < 0.005)
        #expect(abs(OpeningTimeline.wakeEnd - 0.92) < 0.005)
        #expect(abs(OpeningTimeline.eyesOpenStart - 1.1) < 0.005)
        #expect(abs(OpeningTimeline.eyesOpenEnd - 1.18) < 0.005)
        #expect(abs(OpeningTimeline.eyesCloseStart - 1.32) < 0.01)
        #expect(abs(OpeningTimeline.eyesCloseEnd - 1.4) < 0.005)
        #expect(abs(OpeningTimeline.homeStart - 1.62) < 0.01)
    }

    @Test func theSunWakesHalfwayUpAndIsFullyAwakeBy092() {
        #expect(OpeningTimeline.frame(at: 0.54, style: .full).awake == 0)
        let mid = OpeningTimeline.frame(at: 0.73, style: .full).awake
        #expect(mid > 0 && mid < 1)
        #expect(OpeningTimeline.frame(at: 0.92, style: .full).awake == 1)
    }

    @Test func at11SecondsItIsDawnAndTheSunHasRisen() {
        let f = OpeningTimeline.frame(at: 1.1, style: .full)
        #expect(f.sky == 1 && f.rise == 1 && f.awake == 1 && f.glide == 0 && f.scenery == 1)
    }

    @Test func theEyesOpenForAMomentThenCloseBeforeTheGlide() {
        #expect(OpeningTimeline.frame(at: 1.1, style: .full).eyesOpen == 0)
        #expect(OpeningTimeline.frame(at: 1.2, style: .full).eyesOpen == 1)
        #expect(OpeningTimeline.frame(at: 1.4, style: .full).eyesOpen == 0)
        #expect(OpeningTimeline.frame(at: 2.0, style: .full).eyesOpen == 0)
    }

    @Test func theGlideIsAboutHalfDoneAt18Seconds() {
        // 1.8 s is halfway through the glide's time (1.4-2.2 s).
        #expect(abs(OpeningTimeline.progress(1.8, OpeningTimeline.glideStart, OpeningTimeline.total) - 0.5) < 1e-9)
        // The sun's curve (.45,0,.25,1) lands soft, so by then it has covered about 73% of the way.
        let g = OpeningTimeline.frame(at: 1.8, style: .full).glide
        #expect(g > 0.7 && g < 0.76)
    }

    @Test func homeShowsOnlyInTheLastPartOfTheSettle() {
        #expect(OpeningTimeline.frame(at: OpeningTimeline.homeStart, style: .full).scenery == 1)
        let f = OpeningTimeline.frame(at: (OpeningTimeline.homeStart + 2.2) / 2, style: .full)
        #expect(f.scenery > 0.4 && f.scenery < 0.6)
        #expect(OpeningTimeline.frame(at: 2.2, style: .full).scenery == 0)
    }

    @Test func atTheEndTheSunIsOnHomeAndTheSceneryIsGone() {
        let f = OpeningTimeline.frame(at: 2.2, style: .full)
        #expect(f.glide == 1 && f.scenery == 0)
    }

    @Test func withoutASunOnHomeTheSunStaysAndFadesWithTheScenery() {
        let f = OpeningTimeline.frame(at: 2.2, style: .full, hasTarget: false)
        #expect(f.glide == 0 && f.scenery == 0)
    }

    @Test func theSunGlidesBetweenTheGoodMorningAndTheEnd() {
        #expect(OpeningTimeline.frame(at: 1.4, style: .full).glide == 0)
        var last = 0.0
        for t in stride(from: 1.4, through: 2.2, by: 0.05) {
            let g = OpeningTimeline.frame(at: t, style: .full).glide
            #expect(g >= last - 1e-9 && g <= 1)
            last = g
        }
        #expect(OpeningTimeline.frame(at: 2.2, style: .full).glide == 1)
    }

    @Test func theShortFadeKeepsTheNightFrameAndFadesIt() {
        let start = OpeningTimeline.frame(at: 0, style: .short)
        let end = OpeningTimeline.frame(at: 0.3, style: .short)
        #expect(start.scenery == 1 && start.sky == 0 && start.awake == 0)
        #expect(end.scenery == 0)
    }

    @Test func cubicBezierMatchesCSS() {
        #expect(abs(cubicBezier(0, 0.42, 0, 0.58, 1)) < 1e-6)
        #expect(abs(cubicBezier(1, 0.42, 0, 0.58, 1) - 1) < 1e-6)
        // ease-in-out is symmetric, so halfway in time is halfway in value.
        #expect(abs(cubicBezier(0.5, 0.42, 0, 0.58, 1) - 0.5) < 1e-6)
        // The sun's curve (.45,0,.25,1) starts slow and lands soft: past halfway by the midpoint.
        #expect(cubicBezier(0.5, 0.45, 0, 0.25, 1) > 0.5)
        #expect(cubicBezier(0.1, 0.45, 0, 0.25, 1) < 0.05)
    }

    @Test func colourMixHitsItsAnchors() {
        #expect(mixHex(0x16244A, 0xFFFFFF, 0) == 0x16244A)
        #expect(mixHex(0x000000, 0xFFFFFF, 1) == 0xFFFFFF)
        #expect(mixHex(0x000000, 0xFEFEFE, 0.5) == 0x7F7F7F || mixHex(0x000000, 0xFEFEFE, 0.5) == 0x808080)
        #expect(openingMix(0x111111, 0x222222, 0x333333, sky: 0.5) == 0x222222)
        #expect(openingMix(0x111111, 0x222222, 0x333333, sky: 1) == 0x333333)
    }
}
