import SwiftUI

/// The sun rising over two thin wave lines, full width. No card: it sits straight on the screen background.
/// The higher the total, the higher the sun: 0% shows only the top rays, 100% has the whole sun above the water.
struct SunriseScene: View {
    /// The displayed total. Animating it counts the number up.
    let total: Double
    var face: SunFace = .happy

    static let height: CGFloat = 200
    private static let sunSize: CGFloat = 190
    /// Sun top edge at 0% (only the top rays above the waves) and at 100% (the whole sun clear of the water).
    private static let lowTop: CGFloat = 150
    private static let highTop: CGFloat = 0

    /// Where the sun's top edge sits for a given total. The rise eases off (fourth root), so the first
    /// few hundred hours visibly lift the sun and the last ones settle it into place.
    static func sunTop(total: Double) -> CGFloat {
        let progress = pow(Totals.progress(total: total), 0.25)
        return lowTop + (highTop - lowTop) * CGFloat(progress)
    }

    var body: some View {
        ZStack(alignment: .top) {
            // An offset, not padding: padding would grow the stack and push the sea out of view.
            SunView(face: face)
                .frame(width: Self.sunSize, height: Self.sunSize)
                .offset(y: Self.sunTop(total: total))
            SeaView().frame(height: 40)
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .frame(height: Self.height)
        .clipped()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("A smiling sun rising over the sea, \(Totals.percent(total: total))% of the way up")
    }
}

/// The big total and its percentage; interpolates smoothly when animated.
struct CountingTotal: View, Animatable {
    var value: Double
    nonisolated var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        VStack(spacing: 6) {
            Text(Totals.wholeHours(total: value).formatted()).lgNumber(.homeTotal)
            Text("of 10,000 hours · \(Totals.percent(total: value))%")
                .lgText(.body, color: LGColor.inkMuted)
        }
    }
}

struct SeaView: View {
    var body: some View {
        ZStack(alignment: .top) {
            // Hides the part of the sun that is still below the water.
            Rectangle().fill(LGColor.background).padding(.top, 10)
            WaveShape(y: 12, offset: 0).stroke(LGColor.ink, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            WaveShape(y: 28, offset: 10).stroke(LGColor.seaLine, style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
        .accessibilityHidden(true)
    }
}

struct WaveShape: Shape {
    var y: CGFloat
    var offset: CGFloat
    func path(in rect: CGRect) -> Path {
        var p = Path()
        var x = rect.minX + offset - 20
        p.move(to: CGPoint(x: x, y: y))
        var up = true
        while x < rect.maxX {
            p.addQuadCurve(to: CGPoint(x: x + 20, y: y), control: CGPoint(x: x + 10, y: y + (up ? -7 : 7)))
            x += 20
            up.toggle()
        }
        return p
    }
}

#Preview {
    SunriseScene(total: 3294).lgScreen()
}
