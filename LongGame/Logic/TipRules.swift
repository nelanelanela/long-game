import Foundation

/// The four tips, smallest first. Bigger tips get more rays on their sun icon.
enum TipTier: String, CaseIterable, Identifiable, Sendable {
    case ray, morning, goldenhour, sunrise

    var id: String { "com.wehavesun.LongGame.tip.\(rawValue)" }

    /// Which of the sun's 12 rays (numbered clockwise from the top) the icon shows.
    var rays: [Int] {
        switch self {
        case .ray: [0]
        case .morning: [0, 3, 6, 9]
        case .goldenhour: [0, 2, 3, 4, 6, 8, 9, 11]
        case .sunrise: Array(0..<12)
        }
    }

    /// The biggest tip's sun also gets cheeks and a smile.
    var hasFace: Bool { self == .sunrise }

    static func tier(forProductID id: String) -> TipTier? { allCases.first { $0.id == id } }
}

/// When the one gentle "Support Long Game" offer may appear (after a milestone celebration on Home).
enum TipRules {
    static let minDaysSinceOnboarding = 14
    static let minDaysBetweenOffers = 90
    static let quietMonthsAfterTip = 12
    /// A session that ended this recently counts as "just finished".
    static let justFinishedSeconds: TimeInterval = 10 * 60

    static func shouldOffer(now: Date, onboardedAt: Date, lastOfferAt: Date?, lastTipAt: Date?,
                            timerRunning: Bool, lastSessionEndedAt: Date?,
                            calendar: Calendar = .current) -> Bool {
        if timerRunning { return false }
        if let ended = lastSessionEndedAt, now.timeIntervalSince(ended) < justFinishedSeconds { return false }
        guard let onboardedPlus = calendar.date(byAdding: .day, value: minDaysSinceOnboarding, to: onboardedAt),
              now >= onboardedPlus else { return false }
        if let lastOfferAt,
           let next = calendar.date(byAdding: .day, value: minDaysBetweenOffers, to: lastOfferAt), now < next { return false }
        if let lastTipAt,
           let next = calendar.date(byAdding: .month, value: quietMonthsAfterTip, to: lastTipAt), now < next { return false }
        return true
    }
}
