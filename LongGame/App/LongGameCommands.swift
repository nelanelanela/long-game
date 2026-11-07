import SwiftUI

/// The menu commands and keyboard shortcuts (iPad with a keyboard; the Mac app uses the same ones).
struct LongGameCommands: Commands {
    let center: CommandCenter

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Start or finish a session") { center.send(.startOrFinish) }
                .keyboardShortcut("n", modifiers: .command)
            Button("Add past hours") { center.send(.addHours) }
                .keyboardShortcut("l", modifiers: .command)
        }
        CommandMenu("Go") {
            Button("Today") { center.send(.show(.today)) }.keyboardShortcut("1", modifiers: .command)
            Button("This week") { center.send(.show(.week)) }.keyboardShortcut("2", modifiers: .command)
            Button("The long game") { center.send(.show(.longGame)) }.keyboardShortcut("3", modifiers: .command)
            Button("Calendar") { center.send(.show(.calendar)) }.keyboardShortcut("4", modifiers: .command)
            Button("Growth") { center.send(.show(.growth)) }.keyboardShortcut("5", modifiers: .command)
        }
        CommandGroup(replacing: .appSettings) {
            Button("Settings…") { center.send(.settings) }.keyboardShortcut(",", modifiers: .command)
        }
    }
}
