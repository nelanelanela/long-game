import Foundation
import Observation
#if os(iOS)
import UIKit
#endif

/// "Practising" Focus: when a session starts or ends it can run the person's own Shortcuts, which switch their
/// Practising Focus on and off, because iOS does not let an app do that itself.
/// The choices live in UserDefaults on this device only.
@MainActor
@Observable
final class FocusMode {
    static let shared = FocusMode()

    private(set) var settings: FocusSettings
    private static let settingsKey = "focus.settings.v1"

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.settingsKey),
           let saved = try? JSONDecoder().decode(FocusSettings.self, from: data) {
            settings = saved
        } else {
            settings = FocusSettings()
        }
    }

    // MARK: Choices

    func setSwitchFocus(_ on: Bool) {
        settings.switchFocus = on
        saveSettings()
    }

    func setStartShortcut(_ name: String) { settings.startShortcut = name; saveSettings() }
    func setStopShortcut(_ name: String) { settings.stopShortcut = name; saveSettings() }

    private func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) { UserDefaults.standard.set(data, forKey: Self.settingsKey) }
    }

    // MARK: A session starts or ends

    /// Runs the person's Shortcut that turns the Focus on or off. Only while the app is open: iOS will not open
    /// Shortcuts from the background, and a missed run is better than a surprise.
    func runShortcut(starting: Bool) {
        guard let name = FocusPlan.shortcutName(settings, starting: starting), let url = FocusPlan.shortcutURL(name: name) else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(FocusPlan.shortcutDelay))
            #if os(iOS)
            guard UIApplication.shared.applicationState == .active else { return }
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
            #endif
        }
    }

}
