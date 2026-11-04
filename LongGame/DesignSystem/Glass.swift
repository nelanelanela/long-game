import SwiftUI

// Liquid Glass (iOS 26 and later) for controls only: tabs, buttons, toolbar icons and the Timer's strip.
// Only Apple's glass APIs are used (glassEffect, GlassEffectContainer, glassEffectID), never a home-made blur.
// Every use sits behind `if #available(iOS 26, *)`; before that the app looks exactly as it always did.
// The shared styles in Components.swift pick the look, so feature views do not change per OS.

private struct LGFlatKey: EnvironmentKey { static let defaultValue = false }

extension EnvironmentValues {
    /// Forces the flat, pre-iOS 26 look on a newer system: for previews and for comparing the two looks.
    var lgFlat: Bool {
        get { self[LGFlatKey.self] }
        set { self[LGFlatKey.self] = newValue }
    }
}

extension LGColor {
    /// The soft warm wash at the top of Home and History on iOS 26, so the glass has something to catch.
    static let warmWash = Color(hex: 0xFFF0D6)
}

extension View {
    /// The warm-white screen background. On iOS 26 Home and History add a soft warm wash at the top that fades into
    /// the background by about 40% of the screen height.
    func lgWarmScreen() -> some View {
        modifier(WarmScreenModifier())
    }

    /// A bar pinned to the top while the page scrolls under it. On iOS 26 it floats on the system's soft scroll edge
    /// (the content blurs gently under it); before that it has the screen colour behind it, as it always did.
    @ViewBuilder
    func lgTopBar<Bar: View>(@ViewBuilder _ bar: () -> Bar) -> some View {
        if #available(iOS 26, *) {
            safeAreaBar(edge: .top, spacing: 0) { bar() }
        } else {
            safeAreaInset(edge: .top, spacing: 0) { bar().background(LGColor.background) }
        }
    }

    /// Clear glass with rounded corners for a control-like strip (the Timer's stretch strip); before iOS 26 the
    /// translucent white it always had, with its 18 pt corners.
    @ViewBuilder
    func lgGlassStrip(radius: CGFloat) -> some View {
        modifier(GlassStripModifier(radius: radius))
    }
}

private struct WarmScreenModifier: ViewModifier {
    @Environment(\.lgFlat) private var flat

    func body(content: Content) -> some View {
        content.background {
            ZStack(alignment: .top) {
                LGColor.background
                if #available(iOS 26, *), !flat {
                    LinearGradient(stops: [.init(color: LGColor.warmWash, location: 0), .init(color: LGColor.background, location: 0.4)],
                                   startPoint: .top, endPoint: .bottom)
                }
            }
            .ignoresSafeArea()
        }
    }
}

private struct GlassStripModifier: ViewModifier {
    var radius: CGFloat
    @Environment(\.lgFlat) private var flat

    func body(content: Content) -> some View {
        if #available(iOS 26, *), !flat {
            content.glassEffect(.clear, in: .rect(cornerRadius: radius))
        } else {
            content.background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
}
