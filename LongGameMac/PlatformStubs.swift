import Foundation

/// The Mac has no Live Activities. The shared Timer screen and TimerStore call this; here it does nothing.
enum LiveActivityManager {
    static func sync(_ state: TimerState?, now: Date) {}
}

import SwiftUI

extension View {
    /// Screens rotate on the iPhone only; a Mac window has no orientation.
    func allowsRotation() -> some View { self }
}
