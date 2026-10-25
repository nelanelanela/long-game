import SwiftUI

/// The sun peeking over the sea, with the total underneath.
struct SunriseCard: View {
    /// The displayed total. Animating it counts the number up.
    let total: Double
    var face: SunFace = .happy

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                LinearGradient(colors: [LGColor.homeSkyTop, LGColor.homeSkyBottom], startPoint: .top, endPoint: .bottom)
                SunView(face: face)
                    .frame(width: 180, height: 180)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 30)
                SeaView().frame(height: 44)
            }
            .frame(height: 170)
            .clipped()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("A smiling sun peeking over the sea")

            Divider().overlay(LGColor.divider)

            CountingTotal(value: total)
                .frame(maxWidth: .infinity)
                .padding(.top, 22).padding(.bottom, 24).padding(.horizontal, 20)
                .accessibilityElement(children: .combine)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .lgCard(radius: 24)
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
        VStack(spacing: 4) {
            Text(Totals.wholeHours(total: value).formatted()).lgNumber(.bigNumber)
            Text("of 10,000 hours · \(Totals.percent(total: value))%")
                .lgText(.row, color: LGColor.inkMuted)
        }
    }
}

struct SeaView: View {
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                Rectangle().fill(LGColor.seaFill).padding(.top, 6)
                WaveShape(y: 8, offset: 0).stroke(LGColor.ink, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                WaveShape(y: 24, offset: 9).stroke(LGColor.seaLine, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                WaveShape(y: 38, offset: 0).stroke(LGColor.seaLine, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .accessibilityHidden(true)
    }
}

struct WaveShape: Shape {
    var y: CGFloat
    var offset: CGFloat
    func path(in rect: CGRect) -> Path {
        var p = Path()
        var x = rect.minX + offset - 18
        p.move(to: CGPoint(x: x, y: y))
        var up = true
        while x < rect.maxX {
            p.addQuadCurve(to: CGPoint(x: x + 18, y: y), control: CGPoint(x: x + 9, y: y + (up ? -6 : 6)))
            x += 18
            up.toggle()
        }
        return p
    }
}

#Preview {
    SunriseCard(total: 3294).padding(24).lgScreen()
}
