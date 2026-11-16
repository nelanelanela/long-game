import XCTest
@testable import LongGame

/// How long the heavy Logic work takes with eight years of daily practice (about 2,900 sessions), the size of the
/// `-demoData.heavy` game (docs/PERFORMANCE_PLAN.md).
///
/// Xcode keeps a baseline for each test once one is set (in the test report, "Set Baseline"); after that a test fails
/// when it gets more than 10% slower than its baseline. In the Simulator and a Debug build the times are only a guide
/// for comparing one change with the next, not what a phone does.
final class LogicPerformanceTests: XCTestCase {
    private static let now = Date(timeIntervalSince1970: 1_794_787_200)   // 15 November 2026
    private static let onboarding = Date(timeIntervalSince1970: 1_546_300_800)   // 1 January 2019

    /// One session most days from January 2019 to today, a few days with two.
    private static let sessions: [SessionRecord] = {
        var out: [SessionRecord] = []
        let day = 86_400.0
        var t = onboarding.timeIntervalSince1970 + 18 * 3_600
        var i = 0
        while t < now.timeIntervalSince1970 {
            let r = abs(sin(Double(i + 7) * 12.9898) * 43758.5453).truncatingRemainder(dividingBy: 1)
            if r >= 0.08 {
                out.append(SessionRecord(start: Date(timeIntervalSince1970: t), durationSec: (0.5 + r * 2.5) * 3_600))
                if r > 0.85 { out.append(SessionRecord(start: Date(timeIntervalSince1970: t - 10 * 3_600), durationSec: 1_800)) }
            }
            t += day
            i += 1
        }
        return out
    }()

    private static let estimates = [3, 5, 6, 8, 10, 8, 12, 12].enumerated().map { YearRate(year: 2019 + $0.offset, hoursPerWeek: Double($0.element)) }

    func testTheHeavyGameIsHeavy() {
        XCTAssertGreaterThan(Self.sessions.count, 2_500)
    }

    /// Home's summary: total, this week, pace and the forecast.
    func testHomeSummary() {
        measure {
            _ = ProgressSummary.make(estimates: Self.estimates, sessions: Self.sessions, onboardingDate: Self.onboarding,
                                     weekStart: .monday, now: Self.now)
        }
    }

    /// This week's day bars and last week's, as Home works them out on each redraw.
    func testWeekBars() {
        measure {
            _ = WeekBars.make(sessions: Self.sessions, now: Self.now, weekStart: .monday)
            _ = WeekBars.lastWeek(sessions: Self.sessions, now: Self.now, weekStart: .monday, onboardingDate: Self.onboarding)
        }
    }

    /// The Growth chart's history line.
    func testGrowthHistory() {
        measure {
            _ = GrowthSeries.past(estimates: Self.estimates, sessions: Self.sessions, onboardingDate: Self.onboarding,
                                  startYear: 2019, now: Self.now)
        }
    }

    /// The Calendar: hours per day, then Rhythm.
    func testDailyTotalsAndRhythm() {
        measure {
            let daily = Practice.dailySeconds(Self.sessions)
            _ = Rhythm.compute(daily: daily, since: Self.onboarding, now: Self.now, weekStart: .monday)
        }
    }
}
