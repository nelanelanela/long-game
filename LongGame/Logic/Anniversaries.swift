import Foundation

/// Small anniversaries: one quiet line under Home's number, for that calendar day only. No sheet, sound, haptic or
/// notification, and one a day at most.
enum Anniversary: Equatable, Sendable {
    /// Full years since the first session logged in the app.
    case years(Int)
    /// The 10th, 50th, 100th, 250th, 500th or 1,000th session, on the day it was saved.
    case session(Int)
    /// The 100th or 365th day with practice.
    case practiceDays(Int)
    /// One or six months since the first session logged in the app.
    case months(Int)

    static let sessionCounts = [10, 50, 100, 250, 500, 1_000]
    static let practiceDayCounts = [100, 365]

    /// What the app knows for today.
    struct Input: Equatable, Sendable {
        /// When each session was logged in the app (its `createdAt`).
        var loggedAt: [Date]
        /// When each session started (its day counts as a day of practice).
        var starts: [Date]
        /// An hour milestone (100, 500, 1,000 h …) was reached today: it has its own celebration, so no line.
        var hourMilestoneToday: Bool
    }

    /// Today's anniversary, if any. Priority: an hour milestone (no line), then years, then session counts, then days
    /// of practice, then months.
    static func today(_ input: Input, now: Date, calendar: Calendar = .current) -> Anniversary? {
        guard !input.hourMilestoneToday else { return nil }
        let today = calendar.startOfDay(for: now)
        let logged = input.loggedAt.sorted()

        var years: Int?, months: Int?
        if let first = logged.first {
            let firstDay = calendar.startOfDay(for: first)
            for n in 1...100 {
                guard let date = calendar.date(byAdding: .year, value: n, to: firstDay) else { break }
                let day = calendar.startOfDay(for: date)
                if day == today { years = n; break }
                if day > today { break }
            }
            for n in [1, 6] {
                if let date = calendar.date(byAdding: .month, value: n, to: firstDay), calendar.startOfDay(for: date) == today {
                    months = n
                }
            }
        }

        var session: Int?
        for n in sessionCounts where logged.count >= n && calendar.startOfDay(for: logged[n - 1]) == today {
            session = n
        }

        var days: Int?
        let practiceDays = Set(input.starts.map { calendar.startOfDay(for: $0) }).sorted()
        for n in practiceDayCounts where practiceDays.count >= n && practiceDays[n - 1] == today {
            days = n
        }

        if let years { return .years(years) }
        if let session { return .session(session) }
        if let days { return .practiceDays(days) }
        if let months { return .months(months) }
        return nil
    }

    /// Whether today's total carried the total over an hour milestone.
    static func hourMilestoneToday(totalAtStartOfToday: Double, total: Double) -> Bool {
        Milestones.all.contains { Double($0) > totalAtStartOfToday && Double($0) <= total }
    }

    /// "A year since you started.", "Your 100th session.", "100 days of practice."
    var line: String {
        switch self {
        case .years(1): return String(localized: "A year since you started.")
        case .years(let n): return String(localized: "\(Self.capitalisedWord(n)) years since you started.")
        case .session(let n): return String(localized: "Your \(DurationFormat.grouped(n))th session.")
        case .practiceDays(let n): return String(localized: "\(n) days of practice.")
        case .months(1): return String(localized: "A month since you started.")
        case .months(let n): return String(localized: "\(Self.capitalisedWord(n)) months since you started.")
        }
    }

    /// "Two", "Six", "Eleven".
    static func capitalisedWord(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .spellOut
        f.locale = Locale(identifier: "en_GB")
        let word = f.string(from: NSNumber(value: n)) ?? "\(n)"
        return word.prefix(1).uppercased() + word.dropFirst()
    }
}
