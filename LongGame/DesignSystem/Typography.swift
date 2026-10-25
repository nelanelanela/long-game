import SwiftUI

/// SF Pro text styles that follow Dynamic Type.
struct LGTextStyle: Sendable {
    var size: CGFloat
    var weight: Font.Weight
    var relativeTo: Font.TextStyle
    var tracking: CGFloat = 0

    static let screenTitle = LGTextStyle(size: 32, weight: .bold, relativeTo: .largeTitle, tracking: -0.64)
    static let welcomeTitle = LGTextStyle(size: 44, weight: .bold, relativeTo: .largeTitle, tracking: -1.3)
    static let sheetTitle = LGTextStyle(size: 24, weight: .bold, relativeTo: .title2, tracking: -0.48)
    static let navTitle = LGTextStyle(size: 17, weight: .semibold, relativeTo: .headline)
    static let bigNumber = LGTextStyle(size: 52, weight: .bold, relativeTo: .largeTitle, tracking: -2)
    static let yearNumber = LGTextStyle(size: 64, weight: .bold, relativeTo: .largeTitle, tracking: -2.5)
    static let timerNumber = LGTextStyle(size: 88, weight: .light, relativeTo: .largeTitle, tracking: -3.5)
    static let statValue = LGTextStyle(size: 19, weight: .semibold, relativeTo: .title3)
    static let body = LGTextStyle(size: 16, weight: .regular, relativeTo: .body)
    static let bodyLarge = LGTextStyle(size: 17, weight: .regular, relativeTo: .body)
    static let row = LGTextStyle(size: 15, weight: .regular, relativeTo: .subheadline)
    static let rowStrong = LGTextStyle(size: 15, weight: .semibold, relativeTo: .subheadline)
    static let button = LGTextStyle(size: 16, weight: .semibold, relativeTo: .body)
    static let label = LGTextStyle(size: 13, weight: .semibold, relativeTo: .footnote)
    static let caption = LGTextStyle(size: 13, weight: .regular, relativeTo: .footnote)
    static let tiny = LGTextStyle(size: 11, weight: .regular, relativeTo: .caption2)
}

private struct LGTextModifier: ViewModifier {
    let style: LGTextStyle
    @ScaledMetric private var size: CGFloat

    init(style: LGTextStyle) {
        self.style = style
        _size = ScaledMetric(wrappedValue: style.size, relativeTo: style.relativeTo)
    }

    func body(content: Content) -> some View {
        content
            .font(.system(size: size, weight: style.weight))
            .tracking(style.tracking)
    }
}

extension View {
    func lgText(_ style: LGTextStyle, color: Color = LGColor.ink) -> some View {
        modifier(LGTextModifier(style: style)).foregroundStyle(color)
    }

    /// Big numbers shrink before they wrap.
    func lgNumber(_ style: LGTextStyle, color: Color = LGColor.ink) -> some View {
        lgText(style, color: color)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.4)
    }
}
