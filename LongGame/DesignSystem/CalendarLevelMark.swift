import SwiftUI

/// The calendar's levels as shapes as well as colours (the redesign), drawn in a 14 pt cell and scaled to fit. Every
/// level is the same 12 pt size and the corners tighten as the hours grow: rest = a 4 pt dot, under 1 h = a circle,
/// 1–2 h = a square with 4 pt corners, 2–3 h = 2 pt corners, 3 h and more = a sharp square.
struct CalendarLevelShape: Shape {
    var level: CalendarLevel

    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let k = side / 14
        let origin = CGPoint(x: rect.midX - side / 2, y: rect.midY - side / 2)
        func box(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
            CGRect(x: origin.x + x * k, y: origin.y + y * k, width: w * k, height: h * k)
        }
        switch level {
        case .rest: return Path(ellipseIn: box(7 - 2, 7 - 2, 4, 4))
        case .under1: return Path(roundedRect: box(1, 1, 12, 12), cornerRadius: 6 * k, style: .continuous)
        case .from1to2: return Path(roundedRect: box(1, 1, 12, 12), cornerRadius: 4 * k, style: .continuous)
        case .from2to3: return Path(roundedRect: box(1, 1, 12, 12), cornerRadius: 2 * k, style: .continuous)
        case .over3: return Path(box(1, 1, 12, 12))
        }
    }
}

extension LGColor {
    /// The 1 pt outline Increase Contrast adds to the lightest shapes (level 1 and the rest dot).
    static func calendarOutline(_ level: CalendarLevel) -> Color? {
        switch level {
        case .rest: Color(hex: 0x6F7FAE)
        case .under1: Color(hex: 0x9A7B14)
        default: nil
        }
    }
}

/// One calendar day: the level's shape and colour, centred in a square cell, with the photo dot in the middle.
/// Used by the History calendar and its legend, and anywhere else the levels appear.
struct CalendarLevelMark: View {
    var level: CalendarLevel
    var size: CGFloat = 14
    var hasPhoto = false
    /// For previews: act as if Increase Contrast were on.
    var forceIncreasedContrast = false
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        ZStack {
            CalendarLevelShape(level: level).fill(LGColor.calendar(level))
            if contrast == .increased || forceIncreasedContrast, let outline = LGColor.calendarOutline(level) {
                CalendarLevelShape(level: level).stroke(outline, lineWidth: 1)
            }
            // A white dot in the middle: this day has a photo (4 pt; the palest level gets a hairline around it).
            if hasPhoto && level != .rest {
                Circle().fill(.white).frame(width: 4 * size / 14, height: 4 * size / 14)
                    .overlay { if level == .under1 { Circle().stroke(LGColor.ink.opacity(0.28), lineWidth: 0.5) } }
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

#Preview("Levels") {
    HStack(spacing: 8) {
        ForEach(CalendarLevel.allCases, id: \.self) { CalendarLevelMark(level: $0, size: 28, hasPhoto: $0 != .rest) }
    }
    .padding().background(LGColor.background)
}

#Preview("Greyscale") {
    HStack(spacing: 8) {
        ForEach(CalendarLevel.allCases, id: \.self) { CalendarLevelMark(level: $0, size: 28, hasPhoto: $0 != .rest) }
    }
    .padding().background(LGColor.background).grayscale(1)
}

#Preview("Increase Contrast") {
    HStack(spacing: 8) {
        ForEach(CalendarLevel.allCases, id: \.self) { CalendarLevelMark(level: $0, size: 28, forceIncreasedContrast: true) }
    }
    .padding().background(LGColor.background)
}

#Preview("AX5 calendar legend") {
    HStack(spacing: 6) {
        Text("Less").lgText(.tiny, color: LGColor.inkMuted)
        ForEach(CalendarLevel.allCases, id: \.self) { CalendarLevelMark(level: $0, size: 14) }
        Text("More").lgText(.tiny, color: LGColor.inkMuted)
    }
    .padding().background(LGColor.background)
    .dynamicTypeSize(.accessibility5)
}
