import Foundation

/// The views the sidebar layout (iPad, shared with the Mac app) can show.
enum SidebarSection: String, CaseIterable, Codable, Sendable {
    case today, week, longGame, calendar, growth, year, settings

    /// Play: Today, This week, The long game.
    static let play: [SidebarSection] = [.today, .week, .longGame]
    /// History: Calendar, Growth, Your year.
    static let history: [SidebarSection] = [.calendar, .growth, .year]

    /// The Home tab this view is, when it is one of the Play views.
    var homeTab: HomeTab? {
        switch self {
        case .today: .today
        case .week: .week
        case .longGame: .longGame
        default: nil
        }
    }

    init(tab: HomeTab) {
        switch tab {
        case .today: self = .today
        case .week: self = .week
        case .longGame: self = .longGame
        }
    }

    /// ⌘1 … ⌘5 pick these five views; Settings is ⌘,.
    static let numbered: [SidebarSection] = [.today, .week, .longGame, .calendar, .growth]
}

/// Small numbers the iPad's card column shows.
enum IPadFigures {
    /// "6 days/wk": how many days a week the person usually practises (the Rhythm), or "–" with nothing to go on.
    static func rhythmText(daysPerWeek: Int) -> String {
        daysPerWeek > 0 ? String(localized: "\(daysPerWeek) days/wk") : "–"
    }

    /// Hours per calendar day, for `Rhythm.compute`.
    static func daily(_ sessions: [SessionRecord], calendar: Calendar = .current) -> [Date: Double] {
        Dictionary(sessions.map { (calendar.startOfDay(for: $0.start), $0.hours) }, uniquingKeysWith: +)
    }
}
