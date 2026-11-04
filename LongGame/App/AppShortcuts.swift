import AppIntents

/// What Siri and the Shortcuts app know about Long Game without any set-up.
struct LongGameShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartPlayingCraftIntent(),
            phrases: [
                "Start playing \(\.$craft) in \(.applicationName)",
                "Start playing \(\.$craft) with \(.applicationName)",
            ],
            shortTitle: "Start playing",
            systemImageName: "sun.max.fill")
        AppShortcut(
            intent: StartPlayingIntent(),
            phrases: [
                "Start playing in \(.applicationName)",
                "Start a session in \(.applicationName)",
            ],
            shortTitle: "Start playing",
            systemImageName: "sun.max.fill")
    }
}
