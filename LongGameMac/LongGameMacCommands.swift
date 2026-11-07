import SwiftUI

/// The Mac menus: File, View and Session carry every shortcut, so each is found in a menu as well as on the keys.
struct LongGameMacCommands: Commands {
    let center: CommandCenter
    let timer: TimerStore
    @Environment(\.openWindow) private var openWindow

    /// Opens the window first when it has been closed, then sends the command once the screens can hear it.
    private func send(_ command: AppCommand) {
        MacActions.openMain(openWindow) { center.send(command) }
    }

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button(timer.isActive ? "Finish session" : "Start session") { send(.startOrFinish) }
                .keyboardShortcut("n", modifiers: .command)
            Button("Add past hours") { send(.addHours) }
                .keyboardShortcut("l", modifiers: .command)
        }
        CommandGroup(after: .toolbar) {
            Divider()
            Button("Today") { send(.show(.today)) }.keyboardShortcut("1", modifiers: .command)
            Button("This week") { send(.show(.week)) }.keyboardShortcut("2", modifiers: .command)
            Button("The long game") { send(.show(.longGame)) }.keyboardShortcut("3", modifiers: .command)
            Divider()
            Button("Calendar") { send(.show(.calendar)) }.keyboardShortcut("4", modifiers: .command)
            Button("Growth") { send(.show(.growth)) }.keyboardShortcut("5", modifiers: .command)
        }
        CommandMenu("Session") {
            // Space itself is caught by the Timer screen (so it never gets in the way of typing a note);
            // the menu item does the same thing for anyone who prefers the mouse.
            Button(timer.state?.isPaused(at: Date()) == true ? "Resume (Space)" : "Pause (Space)") { send(.pauseResume) }
                .disabled(!timer.isActive)
            Divider()
            Button(timer.isActive ? "Finish session" : "Start session") { send(.startOrFinish) }
            Button("Add past hours") { send(.addHours) }
        }
        CommandGroup(replacing: .appSettings) {
            Button("Settings…") { send(.settings) }.keyboardShortcut(",", modifiers: .command)
        }
    }
}
