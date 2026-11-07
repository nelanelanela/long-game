import SwiftUI

/// The Mac menus: File, View and Session carry every shortcut, so each is found in a menu as well as on the keys.
struct LongGameMacCommands: Commands {
    let center: CommandCenter
    let timer: TimerStore

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button(timer.isActive ? "Finish session" : "Start session") { center.send(.startOrFinish) }
                .keyboardShortcut("n", modifiers: .command)
            Button("Add past hours") { center.send(.addHours) }
                .keyboardShortcut("l", modifiers: .command)
        }
        CommandGroup(after: .toolbar) {
            Divider()
            Button("Today") { center.send(.show(.today)) }.keyboardShortcut("1", modifiers: .command)
            Button("This week") { center.send(.show(.week)) }.keyboardShortcut("2", modifiers: .command)
            Button("The long game") { center.send(.show(.longGame)) }.keyboardShortcut("3", modifiers: .command)
            Divider()
            Button("Calendar") { center.send(.show(.calendar)) }.keyboardShortcut("4", modifiers: .command)
            Button("Growth") { center.send(.show(.growth)) }.keyboardShortcut("5", modifiers: .command)
        }
        CommandMenu("Session") {
            // Space itself is caught by the Timer screen (so it never gets in the way of typing a note);
            // the menu item does the same thing for anyone who prefers the mouse.
            Button(timer.state?.isPaused(at: Date()) == true ? "Resume (Space)" : "Pause (Space)") { center.send(.pauseResume) }
                .disabled(!timer.isActive)
            Divider()
            Button(timer.isActive ? "Finish session" : "Start session") { center.send(.startOrFinish) }
            Button("Add past hours") { center.send(.addHours) }
        }
        CommandGroup(replacing: .appSettings) {
            Button("Settings…") { center.send(.settings) }.keyboardShortcut(",", modifiers: .command)
        }
    }
}
