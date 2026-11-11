import Foundation

/// What the person chose for "Practising" Focus. Only choices live here; whether a session is running comes from the timer.
struct FocusSettings: Codable, Equatable, Sendable {
    /// Run the person's own Shortcuts that turn their Practising Focus on at the start and off at the end.
    var switchFocus = false
    var startShortcut = FocusPlan.defaultStartShortcut
    var stopShortcut = FocusPlan.defaultStopShortcut
}

/// Pure decisions for the Practising Focus feature, so they can be tested without Shortcuts.
enum FocusPlan {
    static let defaultStartShortcut = "Start Practising"
    static let defaultStopShortcut = "Stop Practising"

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
}
