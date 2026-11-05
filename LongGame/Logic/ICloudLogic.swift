import Foundation

// The decisions behind "Save to iCloud", kept free of CloudKit and SwiftData so they can be tested.

/// What the device says about its iCloud account (a plain copy of CloudKit's account status).
enum AccountAvailability: Equatable, Sendable {
    case available
    /// No iCloud account is signed in (or iCloud Drive is off for this device).
    case signedOut
    case restricted
    case unknown
}

/// How the "Save to iCloud" card (onboarding step 3c and Settings) looks and behaves.
struct ICloudSwitchState: Equatable, Sendable {
    var isOn: Bool
    var isEnabled: Bool
    var showsSignInHint: Bool

    /// - Parameters:
    ///   - availability: nil while the account is still being checked; the switch then just shows the wish.
    ///   - wantsOn: what the person (or the default) chose.
    static func make(availability: AccountAvailability?, wantsOn: Bool) -> ICloudSwitchState {
        guard let availability else { return ICloudSwitchState(isOn: wantsOn, isEnabled: true, showsSignInHint: false) }
        if availability == .available { return ICloudSwitchState(isOn: wantsOn, isEnabled: true, showsSignInHint: false) }
        // Without an account the switch is off and disabled, and the card says how to fix it.
        return ICloudSwitchState(isOn: false, isEnabled: false, showsSignInHint: true)
    }
}

/// The status line under the Settings switch.
enum SyncStatus: Equatable, Sendable {
    case off
    case signInNeeded
    case syncing
    /// The last sync that worked, if any has yet.
    case synced(Date?)

    /// "Up to date" for a minute after a sync, then "Last synced 10:42". Nothing yet counts as up to date.
    static let freshFor: TimeInterval = 60

    func text(now: Date, calendar: Calendar = .current) -> String {
        switch self {
        case .off: return String(localized: "Off. Your game stays on this iPhone.")
        case .signInNeeded: return String(localized: "Sign in to iCloud in the Settings app to keep a copy.")
        case .syncing: return String(localized: "Syncing…")
        case .synced(let date):
            guard let date, now.timeIntervalSince(date) > Self.freshFor else { return String(localized: "Up to date") }
            let f = DateFormatter()
            f.calendar = calendar
            f.timeZone = calendar.timeZone
            f.dateFormat = "HH:mm"
            return String(localized: "Last synced \(f.string(from: date))")
        }
    }

    static func make(enabled: Bool, availability: AccountAvailability?, syncing: Bool, lastSync: Date?) -> SyncStatus {
        if let availability, availability != .available { return .signInNeeded }
        if !enabled { return .off }
        return syncing ? .syncing : .synced(lastSync)
    }
}

/// A game found in the person's iCloud, for the Welcome back screen.
struct FoundGame: Equatable, Sendable {
    var craftName: String
    var hours: Int

    /// "Piano · 3,294 hours"
    var summary: String {
        let unit = hours == 1 ? "hour" : "hours"
        return "\(craftName) · \(DurationFormat.grouped(hours)) \(unit)"
    }
}

enum ICloudProbeOutcome: Equatable, Sendable {
    case found(FoundGame)
    case notFound
    case timedOut
}

enum LaunchScreen: Equatable, Sendable {
    case welcomeBack(FoundGame)
    case normalOnboarding
}

enum WelcomeBack {
    /// How long Welcome waits for iCloud before it carries on as normal.
    static let timeout: Duration = .seconds(3)
    static let pollEvery: Duration = .milliseconds(400)

    /// A game that is found shows Welcome back; not found, or no answer in time, is the normal Welcome.
    static func decide(_ outcome: ICloudProbeOutcome) -> LaunchScreen {
        if case .found(let game) = outcome { return .welcomeBack(game) }
        return .normalOnboarding
    }

    /// Looks for a game by calling `load` until it answers the same twice running (the data arrives in pieces:
    /// the craft first, then its hours), or until `timeout`. A game seen but still changing at the deadline counts as
    /// found with its latest numbers; nothing seen is `.timedOut`.
    static func probe(timeout: Duration = timeout, pollEvery: Duration = pollEvery,
                      load: @escaping @MainActor @Sendable () -> FoundGame?) async -> ICloudProbeOutcome {
        await withTaskGroup(of: ICloudProbeOutcome?.self) { group in
            let box = LastSeen()
            group.addTask {
                var previous: FoundGame?
                while !Task.isCancelled {
                    if let now = await load() {
                        await box.set(now)
                        if now == previous { return .found(now) }
                        previous = now
                    }
                    try? await Task.sleep(for: pollEvery)
                }
                return nil
            }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return .timedOut
            }
            let first = await group.next() ?? .timedOut
            group.cancelAll()
            if case .timedOut? = first, let seen = await box.value { return .found(seen) }
            return first ?? .timedOut
        }
    }

    private actor LastSeen {
        var value: FoundGame?
        func set(_ game: FoundGame) { value = game }
    }
}

/// Which launches look for a game in iCloud at all.
enum ICloudLaunch {
    /// Only the very first launch (no database yet), on a device whose iCloud is available.
    static func shouldLookForGame(isFreshInstall: Bool, hasActiveCraft: Bool, availability: AccountAvailability?) -> Bool {
        isFreshInstall && !hasActiveCraft && availability != .signedOut && availability != .restricted
    }
}
