import SwiftUI

/// What a screen needs to know about its window to choose a layout.
struct WindowInfo: Equatable {
    var shape: WindowShape
    /// The whole window, safe areas included.
    var size: CGSize
    var safeArea: EdgeInsets

    static let phone = WindowInfo(shape: .compact, size: CGSize(width: 393, height: 852), safeArea: EdgeInsets())
}

/// Measures the window and hands the screen its `WindowInfo`. Layout follows the window's size class and its real
/// width and height, never the device, so folding, unfolding and resizing a window just re-run this.
struct AdaptiveLayout<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ViewBuilder var content: (WindowInfo) -> Content

    var body: some View {
        GeometryReader { geo in
            let inset = geo.safeAreaInsets
            let size = CGSize(width: geo.size.width + inset.leading + inset.trailing,
                              height: geo.size.height + inset.top + inset.bottom)
            let shape = WindowShape.make(width: size.width, height: size.height, isRegularWidth: horizontalSizeClass == .regular)
            content(WindowInfo(shape: shape, size: size,
                               safeArea: EdgeInsets(top: inset.top, leading: inset.leading, bottom: inset.bottom, trailing: inset.trailing)))
                .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

extension View {
    /// Sheets become centred cards, no wider than 520 pt, when the window is wide; on a phone they stay as they were.
    func lgSheetCard() -> some View {
        frame(maxWidth: WindowShape.sheetWidth)
            .frame(maxWidth: .infinity)
            .modifier(SheetSizing())
    }

    /// Keeps a phone-shaped column readable in a window that is wide but not wider than tall.
    func lgReadableColumn(_ width: CGFloat = 560) -> some View {
        frame(maxWidth: width).frame(maxWidth: .infinity)
    }
}

private struct SheetSizing: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 18, *) {
            content.presentationSizing(.form)
        } else {
            content
        }
    }
}
