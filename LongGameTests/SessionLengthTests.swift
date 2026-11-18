import Testing
@testable import LongGame

struct SessionLengthTests {
    @Test func listAndEditAgreeOnASessionWithSeconds() {
        let seconds = 4 * 60 + 40.0
        #expect(TodaySessions.duration(seconds) == "4 m")
        #expect(SessionLength.fields(seconds: seconds) == (0, 4))
    }

    @Test func fieldsKeepExactMinutes() {
        #expect(SessionLength.fields(seconds: 23 * 60 + 59) == (0, 23))
        #expect(SessionLength.fields(seconds: 100 * 60) == (1, 40))
        #expect(SessionLength.fields(seconds: 0) == (0, 0))
        #expect(SessionLength.fields(seconds: 13 * 3600) == (12, 0))
    }

    @Test func minuteStepsLandOnTheFiveMinuteGrid() {
        #expect(SessionLength.steppedMinutes(4, up: true) == 5)
        #expect(SessionLength.steppedMinutes(4, up: false) == 0)
        #expect(SessionLength.steppedMinutes(5, up: true) == 10)
        #expect(SessionLength.steppedMinutes(5, up: false) == 0)
        #expect(SessionLength.steppedMinutes(23, up: false) == 20)
        #expect(SessionLength.steppedMinutes(55, up: true) == 55)
        #expect(SessionLength.steppedMinutes(57, up: true) == 57)
        #expect(SessionLength.steppedMinutes(57, up: false) == 55)
        #expect(SessionLength.steppedMinutes(0, up: false) == 0)
    }

    @Test func unchangedFieldsKeepTheExactSeconds() {
        let original = 4 * 60 + 40.0
        #expect(SessionLength.savedSeconds(original: original, hours: 0, minutes: 4) == original)
        #expect(SessionLength.savedSeconds(original: original, hours: 0, minutes: 5) == 300)
        #expect(SessionLength.savedSeconds(original: 13 * 3600, hours: 12, minutes: 0) == 13 * 3600)
    }

    @Test func formHeadlineMatchesTheList() {
        #expect(DurationFormat.hoursMinutes(seconds: 4 * 60 + 40) == "0:04")
    }
}
