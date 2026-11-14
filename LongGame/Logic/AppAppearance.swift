import Foundation

/// Settings › Appearance › Look (update 45): Automatic follows the iPhone; Light and Dark choose one.
enum AppAppearance: String, CaseIterable, Sendable {
    case automatic, light, dark

    /// What the app asks the system for: nil follows the device.
    var prefersDark: Bool? {
        switch self {
        case .automatic: nil
        case .light: false
        case .dark: true
        }
    }

    /// Whether the dark look shows, given the device's own setting.
    func isDark(systemIsDark: Bool) -> Bool { prefersDark ?? systemIsDark }
}
