import AppIntents

/// What Siri, Spotlight, the Shortcuts app and the Action Button know about Long Game without any set-up.
struct LongGameShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: BeginSessionIntent(),
            phrases: [
                "Begin a session in \(.applicationName)",
                "Start practising in \(.applicationName)",
            ],
            shortTitle: "Begin a session",
            systemImageName: "sun.max.fill")
        AppShortcut(
            intent: PauseResumeSessionIntent(),
            phrases: [
                "Pause my \(.applicationName) session",
            ],
            shortTitle: "Pause session",
            systemImageName: "pause.fill")
        AppShortcut(
            intent: StartPlayingCraftIntent(),
            phrases: [
                "Start playing \(\.$craft) in \(.applicationName)",
            ],
            shortTitle: "Start playing",
            systemImageName: "sun.max.fill")
    }
}
