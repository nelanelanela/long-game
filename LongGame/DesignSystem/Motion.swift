import SwiftUI

/// `.animation(_:value:)` that is skipped when Reduce Motion is on: the change simply happens.
private struct LGAnimationModifier<V: Equatable>: ViewModifier {
    let animation: Animation?
    let value: V
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : animation, value: value)
    }
}

extension View {
    func lgAnimation<V: Equatable>(_ animation: Animation?, value: V) -> some View {
        modifier(LGAnimationModifier(animation: animation, value: value))
    }
}
