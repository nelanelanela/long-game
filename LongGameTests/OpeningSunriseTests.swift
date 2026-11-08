import Testing
@testable import LongGame

struct OpeningSunriseTests {
    func plan(cold: Bool = true, from: OpeningSource = .icon, session: Bool = false, reduceMotion: Bool = false,
              voiceOver: Bool = false, onboarded: Bool = true, dark: Bool = false) -> OpeningPlan {
        openingStyle(coldStart: cold, openedFrom: from, sessionRunning: session, reduceMotion: reduceMotion,
                     voiceOver: voiceOver, onboarded: onboarded, dark: dark)
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

    @Test func aRunningSessionGetsTheShortFade() {
        #expect(plan(session: true).style == .short)
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

    @Test func darkModeStopsAtDusk() {
        #expect(plan(dark: true).style == .dusk)
    }

    @Test func theShortFadeBeatsDarkMode() {
        #expect(plan(reduceMotion: true, dark: true).style == .short)
        #expect(plan(session: true, dark: true).style == .short)
    }

    @Test func aWarmStartOrLinkStaysSilentEvenInDarkModeOrWithReduceMotion() {
        #expect(plan(cold: false, reduceMotion: true, dark: true).style == .skip)
        #expect(plan(from: .url, voiceOver: true).style == .skip)
    }

    // MARK: Timings

    @Test func theLengthsMatchTheSpec() {
        #expect(OpeningStyle.full.duration == 1.0)
        #expect(OpeningStyle.short.duration == 0.3)
        #expect(OpeningStyle.skip.duration == 0)
    }

    @Test func theFullSunriseStartsOnTheNightFrame() {
        let f = OpeningTimeline.frame(at: 0, style: .full)
        #expect(f.sky == 0 && f.stars == 1 && f.rays == 0 && f.glow == 0)
        #expect(!f.awake && f.glide == 0 && f.scenery == 1 && f.sun == 1)
    }

    @Test func atHalfASecondItIsDawnAndTheSunWakesWithWideEyes() {
        let f = OpeningTimeline.frame(at: 0.5, style: .full)
        #expect(f.sky == 1 && f.stars == 0 && f.rays == 1 && f.awake && f.eyesOpen && f.glide == 0)
    }

    @Test func theEyesCloseToASmileBeforeTheGlide() {
        let f = OpeningTimeline.frame(at: 0.7, style: .full)
        #expect(f.awake && !f.eyesOpen && f.glide > 0 && f.glide < 1)
        #expect(!OpeningTimeline.frame(at: 0.49, style: .full).awake)
    }

    @Test func atTheEndTheSunIsOnHomeAndTheSceneryIsGone() {
        let f = OpeningTimeline.frame(at: 1.0, style: .full)
        #expect(f.glide == 1 && f.scenery == 0 && f.sun == 1)
    }

    @Test func withoutASunOnHomeTheSunFadesWithTheScenery() {
        let f = OpeningTimeline.frame(at: 1.0, style: .full, hasTarget: false)
        #expect(f.glide == 0 && f.sun == 0)
    }

    @Test func darkModeNeverGoesPastDuskAndKeepsTheSunAsleep() {
        for t in stride(from: 0.0, through: 1.0, by: 0.05) {
            let f = OpeningTimeline.frame(at: t, style: .dusk)
            #expect(f.sky <= 0.5 && !f.awake && f.rays == 0)
        }
        #expect(OpeningTimeline.frame(at: 0.5, style: .dusk).sky == 0.5)
        #expect(OpeningTimeline.frame(at: 1.0, style: .dusk).scenery == 0)
    }

    @Test func theShortFadeKeepsTheNightFrameAndFadesIt() {
        let start = OpeningTimeline.frame(at: 0, style: .short)
        let end = OpeningTimeline.frame(at: 0.3, style: .short)
        #expect(start.scenery == 1 && start.sky == 0 && start.stars == 1)
        #expect(end.scenery == 0)
    }

    @Test func colourMixHitsItsAnchors() {
        #expect(mixHex(0x16244A, 0xFFFFFF, 0) == 0x16244A)
        #expect(mixHex(0x000000, 0xFFFFFF, 1) == 0xFFFFFF)
        #expect(mixHex(0x000000, 0xFEFEFE, 0.5) == 0x7F7F7F || mixHex(0x000000, 0xFEFEFE, 0.5) == 0x808080)
        #expect(openingMix(0x111111, 0x222222, 0x333333, sky: 0.5) == 0x222222)
        #expect(openingMix(0x111111, 0x222222, 0x333333, sky: 1) == 0x333333)
    }
}
