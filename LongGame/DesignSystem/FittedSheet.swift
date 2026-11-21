import SwiftUI

/// A bottom sheet only as tall as what it holds, with the buttons at its foot (update 53: "Can we check in?" and
/// "Bring the weather in?"). At the accessibility text sizes it opens full height and scrolls, so nothing is cut.
struct FittedSheet<Content: View>: View {
    @ViewBuilder let content: () -> Content

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var height: CGFloat = 560

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                ScrollView { content() }
                    .scrollBounceBehavior(.basedOnSize)
                    .presentationDetents([.large])
            } else {
                content()
                    .fixedSize(horizontal: false, vertical: true)
                    .onGeometryChangeCompat { height = $0 }
                    .frame(maxHeight: .infinity, alignment: .top)
                    .presentationDetents([.height(height)])
            }
        }
        .lgScreen()
        .presentationDragIndicator(.visible)
    }
}

private extension View {
    /// Reports the view's height whenever it changes (iOS 17 has no `onGeometryChange`).
    func onGeometryChangeCompat(_ action: @escaping (CGFloat) -> Void) -> some View {
        background {
            GeometryReader { geo in
                Color.clear
                    .onAppear { action(geo.size.height) }
                    .onChange(of: geo.size.height) { _, new in action(new) }
            }
        }
    }
}
