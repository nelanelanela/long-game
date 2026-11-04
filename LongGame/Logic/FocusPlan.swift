import Foundation

/// What the person chose for "Practising" Focus. Only choices live here; whether a session is running comes from the timer.
struct FocusSettings: Codable, Equatable, Sendable {
    /// Run the person's own Shortcuts that turn their Practising Focus on at the start and off at the end.
    var switchFocus = false
    /// Block the chosen distracting apps until the session is finished.
    var muteApps = false
    var startShortcut = FocusPlan.defaultStartShortcut
    var stopShortcut = FocusPlan.defaultStopShortcut
}

/// Pure decisions for the Practising Focus feature, so they can be tested without Screen Time or Shortcuts.
enum FocusPlan {
    static let defaultStartShortcut = "Start Practising"
    static let defaultStopShortcut = "Stop Practising"

    /// Should the chosen apps be blocked right now? Blocked only while a session exists (paused counts, so a
    /// coffee break does not hand the phone back), and never without permission or without any chosen apps.
    static func shouldShield(_ settings: FocusSettings, sessionActive: Bool, hasChosenApps: Bool, authorised: Bool) -> Bool {
        settings.muteApps && sessionActive && hasChosenApps && authorised
    }

    /// The Shortcut to run when a session starts or ends, or nil when the Focus switch is off or the name is empty.
    static func shortcutName(_ settings: FocusSettings, starting: Bool) -> String? {
        guard settings.switchFocus else { return nil }
        let name = (starting ? settings.startShortcut : settings.stopShortcut).trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }

    /// Runs a Shortcut and comes straight back to Long Game afterwards.
    static func shortcutURL(name: String) -> URL? {
        var parts = URLComponents()
        parts.scheme = "shortcuts"
        parts.host = "x-callback-url"
        parts.path = "/run-shortcut"
        let back = "\(WidgetLink.scheme)://focus"
        parts.queryItems = [
            URLQueryItem(name: "name", value: name),
            URLQueryItem(name: "x-success", value: back),
            URLQueryItem(name: "x-error", value: back),
            URLQueryItem(name: "x-cancel", value: back),
        ]
        return parts.url
    }

    /// Seconds to wait before jumping to Shortcuts, so the start or the save animation is not cut short.
    static let shortcutDelay: TimeInterval = 1.2

    /// How the chosen apps read in Settings.
    static func chosenSummary(apps: Int, categories: Int, websites: Int) -> String {
        let total = apps + categories + websites
        guard total > 0 else { return "None" }
        var parts: [String] = []
        if apps > 0 { parts.append(apps == 1 ? "1 app" : "\(apps) apps") }
        if categories > 0 { parts.append(categories == 1 ? "1 category" : "\(categories) categories") }
        if websites > 0 { parts.append(websites == 1 ? "1 website" : "\(websites) websites") }
        return parts.joined(separator: ", ")
    }
}
