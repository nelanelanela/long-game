import Testing
import Foundation
@testable import LongGame

struct HoursSteppingTests {
    @Test func wholeHourStepsMoveByOneAndStopAtTheLimits() {
        let spec = HoursStepSpec.wholeHours
        #expect(HoursStepping.stepped(10, direction: 1, spec) == 11)
        #expect(HoursStepping.stepped(10, direction: -1, spec) == 9)
        #expect(HoursStepping.stepped(168, direction: 1, spec) == 168)
        #expect(HoursStepping.stepped(0, direction: -1, spec) == 0)
        #expect(HoursStepping.atLimit(0, direction: -1, spec))
        #expect(!HoursStepping.atLimit(0, direction: 1, spec))
        #expect(HoursStepping.atLimit(168, direction: 1, spec))
    }

    @Test func halfHourStepsMoveByHalfAndStopAtOneAnd168() {
        let spec = HoursStepSpec.pace
        #expect(HoursStepping.stepped(8, direction: 1, spec) == 8.5)
        #expect(HoursStepping.stepped(8.5, direction: -1, spec) == 8)
        #expect(HoursStepping.stepped(1, direction: -1, spec) == 1)
        #expect(HoursStepping.stepped(168, direction: 1, spec) == 168)
        #expect(HoursStepping.atLimit(1, direction: -1, spec))
        #expect(HoursStepping.atLimit(168, direction: 1, spec))
        #expect(spec.needsDecimals)
        #expect(!HoursStepSpec.wholeHours.needsDecimals)
    }

    @Test func typedValuesAreParsedSnappedAndClamped() {
        let whole = HoursStepSpec.wholeHours
        let en = Locale(identifier: "en_GB")
        #expect(HoursStepping.parse("", whole, locale: en) == nil)
        #expect(HoursStepping.parse("   ", whole, locale: en) == nil)
        #expect(HoursStepping.parse("abc", whole, locale: en) == nil)
        #expect(HoursStepping.parse("12", whole, locale: en) == 12)
        #expect(HoursStepping.parse("200", whole, locale: en) == 168)
        #expect(HoursStepping.parse("99", whole, locale: en) == 99)
        #expect(HoursStepping.parse("200", HoursStepSpec.pace, locale: en) == 168)
        #expect(HoursStepping.parse("-5", whole, locale: en) == 0)
        #expect(HoursStepping.parse("0", HoursStepSpec.pace, locale: en) == 1)
    }

    @Test func theDecimalMarkFollowsTheLocale() {
        let pace = HoursStepSpec.pace
        #expect(HoursStepping.parse("7.5", pace, locale: Locale(identifier: "en_GB")) == 7.5)
        #expect(HoursStepping.parse("7,5", pace, locale: Locale(identifier: "de_DE")) == 7.5)
        #expect(HoursStepping.parse("7,5", pace, locale: Locale(identifier: "pl_PL")) == 7.5)
        #expect(HoursStepping.text(7.5, locale: Locale(identifier: "de_DE")) == "7,5")
        #expect(HoursStepping.text(7, locale: Locale(identifier: "en_GB")) == "7")
    }

    @Test func holdingRepeatsSixAStepASecondAfterAFortiethThenTwelve() {
        #expect(HoldRepeater.totalSteps(heldFor: 0.39) == 0)
        #expect(HoldRepeater.totalSteps(heldFor: 0.4) == 1)
        #expect(HoldRepeater.totalSteps(heldFor: 1.4) == 1 + 6)
        // 1.5 s: 0.4 s start + 6 steps a second for 1.1 s
        #expect(HoldRepeater.totalSteps(heldFor: 1.5) == 1 + 6)
        // one second faster: 12 more
        #expect(HoldRepeater.totalSteps(heldFor: 2.5) == 1 + 6 + 12)
    }

    @Test func theRepeaterHandsOutOnlyNewStepsAndStopsWhenReleased() {
        var now = 100.0
        var repeater = HoldRepeater(clock: { now })
        #expect(repeater.stepsDue() == 0)           // not holding
        repeater.begin()
        now += 0.3
        #expect(repeater.stepsDue() == 0)
        now += 0.15                                 // 0.45 s
        #expect(repeater.stepsDue() == 1)
        #expect(repeater.stepsDue() == 0)
        now += 0.5                                  // 0.95 s: three more at 6 a second
        #expect(repeater.stepsDue() == 3)
        repeater.end()
        now += 5
        #expect(repeater.stepsDue() == 0)
        #expect(!repeater.isHolding)
    }

    @Test func useNHoursCopiesToLaterYearsOnly() {
        let years = [2021, 2022, 2023, 2024]
        let values = [2021: 3, 2022: 5, 2023: 5, 2024: 5]
        let result = YearHoursFill.applying(9, after: 2022, to: values, years: years)
        #expect(result == [2021: 3, 2022: 5, 2023: 9, 2024: 9])
        #expect(YearHoursFill.hasLaterYears(after: 2023, years: years))
        #expect(!YearHoursFill.hasLaterYears(after: 2024, years: years))
    }

    @Test func quickPicksSetTheValueWithinTheRange() {
        #expect(HoursStepping.clamped(15, .pace) == 15)
        #expect(HoursStepping.clamped(0, .wholeHours) == 0)
        #expect(HoursStepping.clamped(12.3, .pace) == 12.5)
        #expect(HoursStepping.clamped(0, .pace) == 1)
    }
}
