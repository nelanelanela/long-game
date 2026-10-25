import SwiftUI

enum SunFace: Equatable, Sendable {
    case happy, focus, wink, sleepy, celebrate
}

/// The smiling sun, drawn in the spec's 200 × 200 space and scaled to fit.
/// Rays are numbered 0...11 clockwise from the top.
struct SunView: View {
    var face: SunFace = .happy
    /// Rays 0..<litRays are lit.
    var litRays: Int = 12
    /// Ray that glows softly because it lights next (timer).
    var glowingRay: Int? = nil
    var glowOpacity: Double = 1
    /// Ray that is growing in right now, and how far (0...1).
    var growingRay: Int? = nil
    var growProgress: Double = 1
    var raysRotation: Angle = .zero
    var raysOpacity: Double = 1
    var unlitOpacity: Double = 0.22
    var rayColor: Color = LGColor.sunRays
    /// Extra reach of all rays, used by the golden-hour burst (1 = normal).
    var raySpread: Double = 1

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height) / 200
            ZStack {
                raysLayer
                    .rotationEffect(raysRotation)
                    .opacity(raysOpacity)
                Circle().fill(LGColor.sunBody)
                    .frame(width: 112, height: 112)
                    .position(x: 100, y: 100)
                Circle().fill(LGColor.sunCheeks).frame(width: 14, height: 14).position(x: 72, y: 113)
                Circle().fill(LGColor.sunCheeks).frame(width: 14, height: 14).position(x: 128, y: 113)
                faceLayers
            }
            .frame(width: 200, height: 200)
            .scaleEffect(s)
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    // MARK: Rays

    private var raysLayer: some View {
        ZStack {
            ForEach(0..<12, id: \.self) { k in
                let state = rayState(k)
                RayShape(index: k, grow: state.grow, spread: raySpread)
                    .stroke(rayColor, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .opacity(state.opacity)
            }
        }
        .frame(width: 200, height: 200)
    }

    private func rayState(_ k: Int) -> (grow: Double, opacity: Double) {
        if k == growingRay { return (max(0.001, growProgress), 1) }
        if k < litRays { return (1, 1) }
        if k == glowingRay { return (1, glowOpacity) }
        return (1, unlitOpacity)
    }

    // MARK: Face

    private var faceLayers: some View {
        ZStack {
            // closed, smiling eyes
            EyeArc(x: 76, y: 98, bend: -9).stroke(ink, style: line).opacity(face == .happy ? 1 : 0)
            EyeArc(x: 108, y: 98, bend: -9).stroke(ink, style: line).opacity(face == .happy ? 1 : 0)
            // relaxed, closed eyes
            EyeArc(x: 76, y: 98, bend: 7).stroke(ink, style: line).opacity(face == .focus || face == .wink ? 1 : 0)
            EyeArc(x: 108, y: 98, bend: 7).stroke(ink, style: line).opacity(face == .focus ? 1 : 0)
            // winking: right eye open
            OpenEye(cx: 116).opacity(face == .wink ? 1 : 0)
            // celebrating: both eyes open
            OpenEye(cx: 84).opacity(face == .celebrate ? 1 : 0)
            OpenEye(cx: 116).opacity(face == .celebrate ? 1 : 0)
            // sleepy: droopy lids
            DroopyEye(x: 76, direction: 1).stroke(ink, style: line).opacity(face == .sleepy ? 1 : 0)
            DroopyEye(x: 124, direction: -1).stroke(ink, style: line).opacity(face == .sleepy ? 1 : 0)
            // mouths
            EyeArc(x: 88, y: 114, bend: 11, width: 24).stroke(ink, style: line).opacity(face == .happy ? 1 : 0)
            EyeArc(x: 92, y: 116, bend: 6).stroke(ink, style: line).opacity(face == .focus || face == .wink ? 1 : 0)
            EyeArc(x: 94, y: 118, bend: 3, width: 12).stroke(ink, style: line).opacity(face == .sleepy ? 1 : 0)
            BigSmile().fill(ink).opacity(face == .celebrate ? 1 : 0)
            Text("z")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(ink)
                .position(x: 146, y: 62)
                .opacity(face == .sleepy ? 1 : 0)
        }
        .animation(.easeInOut(duration: 0.18), value: face)
    }

    private var ink: Color { LGColor.ink }
    private var line: StrokeStyle { StrokeStyle(lineWidth: 4.5, lineCap: .round) }
}

// MARK: Shapes (all in the 200 × 200 space)

private struct RayShape: Shape {
    var index: Int
    var grow: Double
    var spread: Double

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(grow, spread) }
        set { grow = newValue.first; spread = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        let angle = (Double(index) * 30 - 90) * .pi / 180
        let inner = 66.0
        let full = (index % 2 == 1 ? 92.0 : 82.0)
        let outer = inner + (full - inner) * grow + (spread - 1) * 14
        var p = Path()
        p.move(to: CGPoint(x: 100 + inner * cos(angle), y: 100 + inner * sin(angle)))
        p.addLine(to: CGPoint(x: 100 + max(inner, outer) * cos(angle), y: 100 + max(inner, outer) * sin(angle)))
        return p
    }
}

private struct EyeArc: Shape {
    var x: CGFloat, y: CGFloat, bend: CGFloat
    var width: CGFloat = 16
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: x, y: y))
        p.addQuadCurve(to: CGPoint(x: x + width, y: y), control: CGPoint(x: x + width / 2, y: y + bend))
        return p
    }
}

private struct DroopyEye: Shape {
    var x: CGFloat
    var direction: CGFloat
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: x, y: 98))
        p.addQuadCurve(to: CGPoint(x: x + 16 * direction, y: 103), control: CGPoint(x: x + 8 * direction, y: 102))
        return p
    }
}

private struct OpenEye: View {
    var cx: CGFloat
    var body: some View {
        ZStack {
            Circle().fill(LGColor.ink).frame(width: 12, height: 12).position(x: cx, y: 96)
            Circle().fill(.white).frame(width: 4, height: 4).position(x: cx + 2, y: 94)
        }
    }
}

private struct BigSmile: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 82, y: 111))
        p.addQuadCurve(to: CGPoint(x: 118, y: 111), control: CGPoint(x: 100, y: 142))
        p.addQuadCurve(to: CGPoint(x: 82, y: 111), control: CGPoint(x: 100, y: 115))
        p.closeSubpath()
        return p
    }
}

#Preview("Sun faces") {
    HStack {
        ForEach([SunFace.happy, .focus, .wink, .sleepy, .celebrate], id: \.self) { f in
            SunView(face: f).frame(width: 64, height: 64)
        }
    }
    .padding()
}
