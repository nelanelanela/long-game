import SwiftUI

extension LGColor {
    static func calendar(_ level: CalendarLevel) -> Color {
        level == .rest ? rest : practice[level.rawValue - 1]
    }
}
