import SwiftUI

enum SunFace: Equatable, Sendable {
    case happy, focus, wink, sleepy, celebrate
    /// Only during a giggle (spec section 18): open eyes and a small "o", then eyes > < and an open laughing mouth.
    case surprised, laughing
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
    /// Reduce Motion: the new ray fades in instead of growing.
    var growFade: Bool = false
    var raysRotation: Angle = .zero
    var raysOpacity: Double = 1
    var unlitOpacity: Double = 0.22
    var rayColor: Color = LGColor.sunRays
    /// Extra reach of all rays, used by the golden-hour burst (1 = normal).
    var raySpread: Double = 1
    /// 0...1: a happy sun opening both eyes for a peek (Home, every 7 s). The mouth stays the same.
    var eyesOpen: Double = 0
    /// The giggle's pose for this moment (Home, the intro and the future-self sheet); at rest it changes nothing.
    var giggle: GigglePose = .rest

    /// The face that is showing: the giggle's, or the sun's own.
    private var shown: SunFace { giggle.face ?? face }

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height) / 200
            ZStack {
                ZStack {
                    raysLayer
                        .scaleEffect(giggle.raysScale)
                        .rotationEffect(raysRotation + .degrees(giggle.raysSpin))
                        .opacity(raysOpacity)
                    Circle().fill(LGColor.sunBody)
                        .frame(width: 112, height: 112)
                        .position(x: 100, y: 100)
                    Circle().fill(LGColor.sunCheeks).frame(width: 14, height: 14).position(x: 72, y: 113)
                        .opacity(shown == .laughing ? 0 : 1)
                    Circle().fill(LGColor.sunCheeks).frame(width: 14, height: 14).position(x: 128, y: 113)
                        .opacity(shown == .laughing ? 0 : 1)
                    faceLayers
                }
                .scaleEffect(x: giggle.scaleX, y: giggle.scaleY)
                .rotationEffect(.degrees(giggle.rotation))
                .offset(y: giggle.dy)
                sparkleLayer
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
        if k == growingRay {
            return growFade ? (1, growProgress) : (max(0.001, growProgress), 1)
        }
        if k < litRays { return (1, 1) }
        if k == glowingRay { return (1, glowOpacity) }
        return (1, unlitOpacity)
    }

    // MARK: Face

    private var faceLayers: some View {
        ZStack {
            // closed, smiling eyes
            EyeArc(x: 76, y: 98, bend: -9).stroke(ink, style: line).opacity(shown == .happy ? 1 - eyesOpen : 0)
            EyeArc(x: 108, y: 98, bend: -9).stroke(ink, style: line).opacity(shown == .happy ? 1 - eyesOpen : 0)
            // relaxed, closed eyes
            EyeArc(x: 76, y: 98, bend: 7).stroke(ink, style: line).opacity(shown == .focus || shown == .wink ? 1 : 0)
            EyeArc(x: 108, y: 98, bend: 7).stroke(ink, style: line).opacity(shown == .focus ? 1 : 0)
            // winking: right eye open
            OpenEye(cx: 116).opacity(shown == .wink ? 1 : 0)
            // celebrating: both eyes open
            OpenEye(cx: 84).opacity(shown == .celebrate ? 1 : shown == .happy ? eyesOpen : 0)
            OpenEye(cx: 116).opacity(shown == .celebrate ? 1 : shown == .happy ? eyesOpen : 0)
            // sleepy: droopy lids
            DroopyEye(x: 76, direction: 1).stroke(ink, style: line).opacity(shown == .sleepy ? 1 : 0)
            DroopyEye(x: 124, direction: -1).stroke(ink, style: line).opacity(shown == .sleepy ? 1 : 0)
            // mouths
            EyeArc(x: 88, y: 114, bend: 11, width: 24).stroke(ink, style: line).opacity(shown == .happy ? 1 : 0)
            EyeArc(x: 92, y: 116, bend: 6).stroke(ink, style: line).opacity(shown == .focus || shown == .wink ? 1 : 0)
            EyeArc(x: 94, y: 118, bend: 3, width: 12).stroke(ink, style: line).opacity(shown == .sleepy ? 1 : 0)
            BigSmile().fill(ink).opacity(shown == .celebrate ? 1 : 0)
            // surprised: wide eyes and a small "o"
            OpenEye(cx: 84).opacity(shown == .surprised ? 1 : 0)
            OpenEye(cx: 116).opacity(shown == .surprised ? 1 : 0)
            Ellipse().fill(ink).frame(width: 12, height: 14).position(x: 100, y: 118).opacity(shown == .surprised ? 1 : 0)
            // laughing: eyes > <, deeper cheeks, an open mouth with a small pink tongue
            Group {
                Circle().fill(LGColor.sunCheeksDeep).frame(width: 18, height: 18).position(x: 70, y: 114)
                Circle().fill(LGColor.sunCheeksDeep).frame(width: 18, height: 18).position(x: 130, y: 114)
                LaughEyes().stroke(ink, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                LaughMouth().fill(ink)
                LaughTongue().fill(LGColor.sunCheeks)
            }
            .opacity(shown == .laughing ? 1 : 0)
            Text("z")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(ink)
                .position(x: 134, y: 78)
                .opacity(shown == .sleepy ? 1 : 0)
        }
        .animation(giggle.face == nil ? .easeInOut(duration: 0.18) : nil, value: shown)
    }

    /// Four small gold sparkles that pop out around the sun during a giggle.
    private var sparkleLayer: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { i in
                let spot = GiggleMotion.sparkleSpots[i]
                let sparkle = giggle.sparkles[i]
                SparkleCross()
                    .stroke(LGColor.sunRays, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                    .frame(width: 16, height: 16)
                    .scaleEffect(sparkle.scale)
                    .opacity(sparkle.opacity)
                    .position(x: spot.x, y: spot.y)
            }
        }
        .frame(width: 200, height: 200)
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
        // outer corner sits lower than the inner one: a drooping lid
        p.move(to: CGPoint(x: x, y: 103))
        p.addQuadCurve(to: CGPoint(x: x + 16 * direction, y: 98), control: CGPoint(x: x + 8 * direction, y: 104))
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

private struct SparkleCross: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY)); p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.move(to: CGPoint(x: rect.minX, y: rect.midY)); p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p
    }
}

/// Eyes > <
private struct LaughEyes: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 74, y: 90)); p.addLine(to: CGPoint(x: 87, y: 97)); p.addLine(to: CGPoint(x: 74, y: 104))
        p.move(to: CGPoint(x: 126, y: 90)); p.addLine(to: CGPoint(x: 113, y: 97)); p.addLine(to: CGPoint(x: 126, y: 104))
        return p
    }
}

private struct LaughMouth: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 82, y: 110))
        p.addQuadCurve(to: CGPoint(x: 118, y: 110), control: CGPoint(x: 100, y: 110))
        p.addQuadCurve(to: CGPoint(x: 100, y: 130), control: CGPoint(x: 116, y: 130))
        p.addQuadCurve(to: CGPoint(x: 82, y: 110), control: CGPoint(x: 84, y: 130))
        p.closeSubpath()
        return p
    }
}

private struct LaughTongue: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 91, y: 123))
        p.addQuadCurve(to: CGPoint(x: 109, y: 123), control: CGPoint(x: 100, y: 117))
        p.addQuadCurve(to: CGPoint(x: 100, y: 129), control: CGPoint(x: 105, y: 129))
        p.addQuadCurve(to: CGPoint(x: 91, y: 123), control: CGPoint(x: 95, y: 129))
        p.closeSubpath()
        return p
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
        ForEach([SunFace.happy, .focus, .wink, .sleepy, .celebrate, .surprised, .laughing], id: \.self) { f in
            SunView(face: f).frame(width: 64, height: 64)
        }
    }
    .padding()
}
