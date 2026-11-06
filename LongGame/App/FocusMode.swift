import Foundation
import Observation
#if os(iOS)
import UIKit
#endif
#if os(iOS) && canImport(FamilyControls)
import FamilyControls
import ManagedSettings
#endif

/// "Practising" Focus: while a session exists it can run the person's own Shortcuts (which switch their Practising
/// Focus on and off, because iOS does not let an app do that itself) and block the apps they chose with Screen Time.
/// The choices live in UserDefaults on this iPhone only: Screen Time app choices are specific to the device.
@MainActor
@Observable
final class FocusMode {
    static let shared = FocusMode()

    private(set) var settings: FocusSettings
    /// Set when asking Screen Time for permission failed or was refused, in words for the person.
    private(set) var permissionProblem: String?
    #if os(iOS) && canImport(FamilyControls)
    private(set) var selection: FamilyActivitySelection
    #endif

    @ObservationIgnored private var sessionActive = false
    private static let settingsKey = "focus.settings.v1"
    private static let selectionKey = "focus.selection.v1"

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.settingsKey),
           let saved = try? JSONDecoder().decode(FocusSettings.self, from: data) {
            settings = saved
        } else {
            settings = FocusSettings()
        }
        #if os(iOS) && canImport(FamilyControls)
        if let data = UserDefaults.standard.data(forKey: Self.selectionKey),
           let saved = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
            selection = saved
        } else {
            selection = FamilyActivitySelection()
        }
        #endif
    }

    // MARK: Choices

    func setSwitchFocus(_ on: Bool) {
        settings.switchFocus = on
        saveSettings()
    }

    func setStartShortcut(_ name: String) { settings.startShortcut = name; saveSettings() }
    func setStopShortcut(_ name: String) { settings.stopShortcut = name; saveSettings() }

    func setMuteApps(_ on: Bool) async {
        permissionProblem = nil
        if on {
            guard await requestPermission() else { return }
        }
        settings.muteApps = on
        saveSettings()
        sync(sessionActive: sessionActive)
    }

    private func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) { UserDefaults.standard.set(data, forKey: Self.settingsKey) }
    }

    // MARK: A session starts or ends

    /// Called whenever the timer changes. Idempotent: it only makes the block match what the plan says.
    func sync(sessionActive active: Bool) {
        sessionActive = active
        #if os(iOS) && canImport(FamilyControls)
        let shield = FocusPlan.shouldShield(settings, sessionActive: active, hasChosenApps: hasChosenApps, authorised: isAuthorised)
        let store = ManagedSettingsStore(named: .init("practising"))
        if shield {
            store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
            store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
            store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
        } else {
            store.clearAllSettings()
        }
        #endif
    }

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

    // MARK: Screen Time

    var isAuthorised: Bool {
        #if os(iOS) && canImport(FamilyControls)
        AuthorizationCenter.shared.authorizationStatus == .approved
        #else
        false
        #endif
    }

    var hasChosenApps: Bool {
        #if os(iOS) && canImport(FamilyControls)
        !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty || !selection.webDomainTokens.isEmpty
        #else
        false
        #endif
    }

    var chosenSummary: String {
        #if os(iOS) && canImport(FamilyControls)
        FocusPlan.chosenSummary(apps: selection.applicationTokens.count, categories: selection.categoryTokens.count,
                                websites: selection.webDomainTokens.count)
        #else
        "None"
        #endif
    }

    #if os(iOS) && canImport(FamilyControls)
    func setSelection(_ new: FamilyActivitySelection) {
        selection = new
        if let data = try? JSONEncoder().encode(new) { UserDefaults.standard.set(data, forKey: Self.selectionKey) }
        sync(sessionActive: sessionActive)
    }
    #endif

    private func requestPermission() async -> Bool {
        #if os(iOS) && canImport(FamilyControls)
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            return isAuthorised
        } catch {
            permissionProblem = "Screen Time access wasn't given, so no apps can be muted. You can try again, or allow it in the iPhone's Settings app."
            return false
        }
        #else
        return false
        #endif
    }
}
