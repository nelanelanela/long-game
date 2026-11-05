import Testing
import Foundation
@testable import LongGame

struct SunPositionWordsTests {
    private func phrase(_ p: Double) -> SunPhrase { sunPositionWords(fraction: p) }

    @Test func zeroAndBelowIsTheHorizon() {
        #expect(phrase(0).step == .horizon)
        #expect(phrase(-0.4).step == .horizon)
        #expect(phrase(.nan).step == .horizon)
        #expect(phrase(0).words == "on the horizon")
    }

    @Test func underFifteenPercentIsJustRising() {
        #expect(phrase(0.01).step == .rising)
        #expect(phrase(0.149).step == .rising)
        #expect(phrase(0.01).words == "just rising")
        // From 0.15 it is the nearest step.
        #expect(phrase(0.15).step == .quarter)
    }

    @Test func everyStepOnItsOwnHasNoQualifier() {
        let expected: [(Double, SunPhrase.Step, String)] = [
            (0.25, .quarter, "a quarter of the way"), (0.33, .third, "a third of the way"), (0.5, .half, "halfway"),
            (0.67, .twoThirds, "two thirds of the way"), (0.75, .threeQuarters, "three quarters of the way"),
        ]
        for (p, step, words) in expected {
            #expect(phrase(p) == SunPhrase(step: step, qualifier: .none))
            #expect(phrase(p).words == words)
        }
    }

    @Test func withinOnePercentCountsAsOnTheStep() {
        #expect(phrase(0.51).qualifier == .none)
        #expect(phrase(0.49).qualifier == .none)
        #expect(phrase(1.0 / 3).qualifier == .none)
        #expect(phrase(0.66).qualifier == .none)
        #expect(phrase(0.76).step == .threeQuarters)
    }

    @Test func nearAStepIsJustOverOrJustUnder() {
        #expect(phrase(0.54) == SunPhrase(step: .half, qualifier: .justOver))
        #expect(phrase(0.46) == SunPhrase(step: .half, qualifier: .justUnder))
        #expect(phrase(0.5417).words == "just over halfway")
        #expect(phrase(0.46).words == "just under halfway")
        #expect(phrase(0.30).words == "just under a third of the way")
    }

    @Test func exactlyFivePercentAwayStillCountsAsNear() {
        #expect(phrase(0.55).qualifier == .justOver)
        #expect(phrase(0.45).qualifier == .justUnder)
        #expect(phrase(0.80).qualifier == .justOver)
    }

    @Test func furtherThanFivePercentIsAbout() {
        #expect(phrase(0.40) == SunPhrase(step: .third, qualifier: .about))
        #expect(phrase(0.85).words == "about three quarters of the way")
        #expect(phrase(0.15).words == "about a quarter of the way")
    }

    @Test func fromNinetyPercentItIsAlmostThere() {
        #expect(phrase(0.899).step == .threeQuarters)
        #expect(phrase(0.9).step == .almostThere)
        #expect(phrase(0.999).step == .almostThere)
        #expect(phrase(0.9).words == "almost there")
    }

    @Test func oneAndAboveIsThere() {
        #expect(phrase(1).step == .there)
        #expect(phrase(1.8).step == .there)
        #expect(phrase(1).words == "there")
    }

    @Test func sentencesReadNaturally() {
        #expect(phrase(0.5417).sentence(to: "your weekly target") == "The sun is just over halfway to your weekly target.")
        #expect(phrase(0.3294).sentence(to: "the finish line") == "The sun is a third of the way to the finish line.")
        #expect(phrase(0).sentence(to: "anywhere") == "The sun is on the horizon.")
        #expect(phrase(0.05).sentence(to: "anywhere") == "The sun is just rising.")
        #expect(phrase(0.95).sentence(to: "the finish line") == "The sun is almost at the finish line.")
        #expect(phrase(1).sentence(to: "the finish line") == "The sun has reached the finish line.")
    }
}

struct SunSpeechTests {
    @Test func thisWeekLeadsWithWordsThenNumbers() {
        let g = SunSpeech.week(hours: 6.5, target: 12, daysLeft: 3)
        #expect(g.label == "The sun is just over halfway to your weekly target.")
        #expect(g.value == "6.5 of 12 hours, 5.5 to go, 3 days left.")
        #expect(g.text == g.label + " " + g.value)
    }

    @Test func thisWeekPluralisesDaysLeftAndTheLastDay() {
        #expect(SunSpeech.week(hours: 6.5, target: 12, daysLeft: 1).value == "6.5 of 12 hours, 5.5 to go, 1 day left.")
        #expect(SunSpeech.week(hours: 6.5, target: 12, daysLeft: 0).value == "6.5 of 12 hours, 5.5 to go, last day of the week.")
    }

    @Test func thisWeekSingularHourAndAboveTarget() {
        #expect(SunSpeech.week(hours: 0.5, target: 1, daysLeft: 2).value == "0.5 of 1 hour, 0.5 to go, 2 days left.")
        let above = SunSpeech.week(hours: 13.5, target: 12, daysLeft: 1)
        #expect(above.label == "The sun is above your weekly target.")
        #expect(above.value == "13.5 of 12 hours.")
        let exact = SunSpeech.week(hours: 12, target: 12, daysLeft: 1)
        #expect(exact.label == "The sun has reached your weekly target.")
    }

    @Test func theLongGameAddsThePaceWhenThereIsOne() {
        let g = SunSpeech.longGame(total: 3_294.7, pace: "At your pace, around November 2035.")
        #expect(g.label == "The sun is a third of the way to the finish line.")
        #expect(g.value == "3,294 of 10,000 hours. At your pace, around November 2035.")
        #expect(SunSpeech.longGame(total: 3_294.7, pace: nil).value == "3,294 of 10,000 hours.")
        // At the finish line there is no pace to announce.
        #expect(SunSpeech.longGame(total: 10_100, pace: "At your pace, around 2040.").value == "10,100 of 10,000 hours.")
    }

    @Test func todayDescribesTheStretchAndTheRestDay() {
        let s = SunSpeech.today(.stretch(target: 6_300, done: 3_900))
        #expect(s.label == "The sun is about two thirds of the way to today's resting place.")
        #expect(s.value == "1 hour 5 minutes of 1 hour 45 minutes, 40 minutes to go.")
        let rest = SunSpeech.today(.restDay(done: 0))
        #expect(rest.label == "Rest day. The sun is resting on the horizon.")
        #expect(rest.value == "")
        #expect(SunSpeech.today(.restDay(done: 600)).value == "Played anyway: 10 minutes.")
        #expect(SunSpeech.today(.covered(target: 3_600, done: 3_700)).label.contains("covered"))
        #expect(SunSpeech.today(.weekCovered(done: 0)).label.contains("covered"))
    }

    @Test func theTimerReadsSessionRaysAndTotal() {
        // 27 min 18 s in: 5 rays lit, the 6th in 2 min 42 s.
        let text = SunSpeech.timer(elapsed: 27 * 60 + 18, total: 3_294.7)
        #expect(text == "Session 27 minutes. 5 of 12 rays lit, next ray in 2 minutes 42 seconds. Total 3,294.7 hours.")
        #expect(SunSpeech.timer(elapsed: 45, total: 10).hasPrefix("Session 45 seconds. 0 of 12 rays lit"))
        #expect(SunSpeech.timer(elapsed: 3_600 + 60, total: 10).hasPrefix("Session 1 hour 1 minute."))
    }

    @Test func theRayAnnouncementIsShort() {
        #expect(SunSpeech.rayLit(SunHour(elapsed: 6 * 300)) == "Ray 6 lit")
        #expect(SunSpeech.rayLit(SunHour(elapsed: 300)) == "Ray 1 lit")
        #expect(SunSpeech.rayLit(SunHour(elapsed: 3_600)) == "Golden hour, all 12 rays lit")
    }

    @Test func calendarDaysReadTheirLevelInWords() {
        #expect(SunSpeech.calendarDay(date: "Thursday 22 October", seconds: 7_200, hasPhoto: true)
                == "Thursday 22 October. 2 hours, a good day. Has a photo.")
        #expect(SunSpeech.calendarDay(date: "Thursday 22 October", seconds: 0, hasPhoto: false) == "Thursday 22 October. Rest day.")
        #expect(SunSpeech.calendarDay(date: "Friday 23 October", seconds: 3_600, hasPhoto: false) == "Friday 23 October. 1 hour, some.")
        #expect(SunSpeech.calendarDay(date: "Friday 23 October", seconds: 1_800, hasPhoto: false) == "Friday 23 October. 30 minutes, a little.")
        #expect(SunSpeech.calendarDay(date: "Friday 23 October", seconds: 4 * 3_600, hasPhoto: false) == "Friday 23 October. 4 hours, a full day.")
    }

    @Test func levelWordsForEveryLevel() {
        #expect(CalendarLevel.allCases.map { SunSpeech.words(for: $0) } == ["rest day", "a little", "some", "a good day", "a full day"])
    }
}

struct CalendarLevelBandTests {
    @Test func eachHourBandHasItsLevel() {
        #expect(CalendarLevel.level(hours: 0) == .rest)
        #expect(CalendarLevel.level(hours: 0.01) == .under1)
        #expect(CalendarLevel.level(hours: 0.99) == .under1)
        #expect(CalendarLevel.level(hours: 1) == .from1to2)
        #expect(CalendarLevel.level(hours: 1.99) == .from1to2)
        #expect(CalendarLevel.level(hours: 2) == .from2to3)
        #expect(CalendarLevel.level(hours: 2.99) == .from2to3)
        #expect(CalendarLevel.level(hours: 3) == .over3)
    }

    @Test func overTwentyFourHoursIsCappedAtTheTopLevel() {
        #expect(CalendarLevel.level(hours: 24) == .over3)
        #expect(CalendarLevel.level(hours: 30) == .over3)
        #expect(CalendarLevel.level(hours: 1_000) == .over3)
    }
}
