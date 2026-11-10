import SwiftUI

enum SunFace: Equatable, Sendable {
    case happy, focus, wink, sleepy, celebrate
    /// Only on the opening sunrise's night frame: the Launch board's sleeping sun (low closed eyes, a small mouth and a
    /// blue-grey "z"), exactly as the launch screen draws it.
    case asleep
    /// Only during a giggle (spec section 18): the gasp (wide eyes, round "o"), then the baby laugh (^ ^ eyes, big open mouth).
    case surprised, laughing
}

/// The smiling sun, drawn in the spec's 200 × 200 space and scaled to fit.
/// Rays are numbered 0...11 clockwise from the top.
struct SunView: View {
    /// The sun's own idle life (redesign): breathing (4 s, up 4 pt, 104.5%), rays turning (one turn per 120 s) and the
    /// blink (every ~9 s a happy sun opens both eyes for 0.5 s). Off in widgets, the Live Activity, Watch complications,
    /// the year card, the app icon and the launch animation, and for hosts that drive the motion themselves.
    var idle = true
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
    /// Rays unfolding (the opening sunrise): 0 = folded into the sun, 1 = full length.
    var raysScale: Double = 1
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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if idle && !reduceMotion {
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let breath = (1 - cos(2 * .pi * t / 4)) / 2
                resting(at: t)
                    .scaleEffect(1 + 0.045 * breath)
                    .offset(y: -4 * breath)
            }
        } else {
            drawn
        }
    }

    /// This sun at rest with the idle rotation and blink for time `t` baked in.
    private func resting(at t: Double) -> SunView {
        var copy = self
        copy.idle = false
        copy.raysRotation = raysRotation + .degrees(t.truncatingRemainder(dividingBy: 120) / 120 * 360)
        let cycle = t.truncatingRemainder(dividingBy: 9) / 9
        if face == .happy, cycle > 0.945, cycle < 0.985 { copy.eyesOpen = 1 }
        return copy
    }

    private var drawn: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height) / 200
            ZStack {
                ZStack {
                    raysLayer
                        .scaleEffect(giggle.raysScale * raysScale)
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
        .accessibilityIgnoresInvertColors()
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
            // asleep (the launch screen's sun, Sun.dc.html "sleepy"): same lines as the still image
            EyeArc(x: 77, y: 101, bend: 4, width: 14).stroke(ink, style: line).opacity(shown == .asleep ? 1 : 0)
            EyeArc(x: 109, y: 101, bend: 4, width: 14).stroke(ink, style: line).opacity(shown == .asleep ? 1 : 0)
            EyeArc(x: 95, y: 118, bend: 2, width: 10).stroke(ink, style: line).opacity(shown == .asleep ? 1 : 0)
            // Its "z": 22 pt semibold, #8FA2E0, the baseline's left end at (150, 54).
            Text(verbatim: "z")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(LGColor.sleepZ)
                .fixedSize()
                .position(x: 156, y: 47)
                .opacity(shown == .asleep ? 1 : 0)
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
            // gasp: wide eyes with highlights and a round "o"
            OpenEye(cx: 84, size: 15).opacity(shown == .surprised ? 1 : 0)
            OpenEye(cx: 116, size: 15).opacity(shown == .surprised ? 1 : 0)
            Circle().fill(ink).frame(width: 14, height: 14).position(x: 100, y: 120).opacity(shown == .surprised ? 1 : 0)
            // baby laugh: happy crescent eyes ^ ^, a big open mouth with a pink tongue
            Group {
                EyeArc(x: 76, y: 98, bend: -9).stroke(ink, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                EyeArc(x: 108, y: 98, bend: -9).stroke(ink, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                LaughMouth().fill(ink)
                LaughTongue().fill(LGColor.sunCheeks)
            }
            .opacity(shown == .laughing ? 1 : 0)
            // deeper blush while the sun laughs, fading in the contented end (round cheeks, r 11)
            Group {
                Circle().fill(LGColor.sunCheeksDeep).frame(width: 22, height: 22).position(x: 70, y: 114)
                Circle().fill(LGColor.sunCheeksDeep).frame(width: 22, height: 22).position(x: 130, y: 114)
            }
            .opacity(giggle.blush)
            Text("z")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(ink)
                .position(x: 134, y: 78)
                .opacity(shown == .sleepy ? 1 : 0)
        }
        .lgAnimation(giggle.face == nil ? .easeInOut(duration: 0.18) : nil, value: shown)
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
    /// Diameter; the gasp uses wider eyes (r 7.5).
    var size: CGFloat = 12
    var body: some View {
        ZStack {
            Circle().fill(LGColor.ink).frame(width: size, height: size).position(x: cx, y: 96)
            Circle().fill(.white).frame(width: size / 3, height: size / 3).position(x: cx + size / 6, y: 96 - size / 6)
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
private struct LaughMouth: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 76, y: 108))
        p.addQuadCurve(to: CGPoint(x: 124, y: 108), control: CGPoint(x: 100, y: 112))
        p.addQuadCurve(to: CGPoint(x: 100, y: 138), control: CGPoint(x: 122, y: 138))
        p.addQuadCurve(to: CGPoint(x: 76, y: 108), control: CGPoint(x: 78, y: 138))
        p.closeSubpath()
        return p
    }
}

private struct LaughTongue: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 88, y: 129))
        p.addQuadCurve(to: CGPoint(x: 112, y: 129), control: CGPoint(x: 100, y: 120))
        p.addQuadCurve(to: CGPoint(x: 100, y: 136), control: CGPoint(x: 110, y: 137))
        p.addQuadCurve(to: CGPoint(x: 88, y: 129), control: CGPoint(x: 90, y: 137))
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
            SunView(idle: false, face: f).frame(width: 64, height: 64)
        }
    }
    .padding()
}
