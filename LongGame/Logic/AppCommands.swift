import Foundation
import Observation

/// What the keyboard shortcuts and menu commands ask the screens to do.
enum AppCommand: Equatable, Sendable {
    /// ⌘N: start a session, or finish the running one.
    case startOrFinish
    /// Space: pause or resume (on the timer).
    case pauseResume
    /// ⌘L
    case addHours
    /// ⌘1 … ⌘5
    case show(SidebarSection)
    /// ⌘,
    case settings
}

/// The menu bar and the screens meet here: a command is issued with a number, so the same command twice in a row
/// is still a change that `onChange` sees.
@MainActor @Observable
final class CommandCenter {
    struct Issued: Equatable, Sendable {
        var number: Int
        var command: AppCommand
    }

    private(set) var issued: Issued?
    private var count = 0

    func send(_ command: AppCommand) {
        count += 1
        issued = Issued(number: count, command: command)
    }
}
