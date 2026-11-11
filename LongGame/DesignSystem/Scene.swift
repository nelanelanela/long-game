import SwiftUI

// The We Have Sun scene (update prompt 32, part 2): SkyView above the horizon, LandView (dunes and sea) below it.
// Shapes and numbers come from design/redesign/Sky.dc.html and Land.dc.html.

enum SceneTone: Equatable, Sendable {
    case night, dawn, day
}

// MARK: Sky

/// The sky. Night is a navy gradient with stars and a crescent moon, dawn runs navy → violet → warm peach at the
/// horizon, and day is transparent so the screen background shows. The warm glow is clipped at the horizon, so
/// nothing gold ever shows below it.
struct SkyView: View {
    var tone: SceneTone = .night
    /// Where the horizon sits, as a fraction of the height (0.3...1).
    var horizon: CGFloat = 0.85
    var moon = true
    /// Where the moon sits, as fractions of the width and height (default: three quarters across, near the top).
    var moonAt = CGPoint(x: 0.74, y: 0.12)
    /// Where the glow is centred across the width (0...1).
    var glowX: CGFloat = 0.5

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let hy = horizon * h
            ZStack(alignment: .topLeading) {
                backgroundGradient
                // The glow, cut off at the horizon.
                RadialGradient(gradient: glow, center: .center, startRadius: 0, endRadius: glowSize(w, h) * 0.62 / 2 * 2.0.squareRoot())
                    .frame(width: glowSize(w, h), height: glowSize(w, h))
                    .position(x: glowX * w, y: hy)
                    .frame(width: w, height: hy, alignment: .topLeading)
                    .clipped()
                    // Clipping hides the glow but not its touch area: the full glow circle reaches well above a
                    // small sky and would swallow taps on the controls over it (the − on Your weekly pace).
                    .contentShape(Rectangle())
                    .frame(width: w, height: h, alignment: .topLeading)
                Canvas { ctx, size in
                    drawStars(&ctx, size: size)
                    if moon && tone != .day { drawMoon(&ctx, size: size) }
                }
            }
            .frame(width: w, height: h)
            .clipped()
            .contentShape(Rectangle())
        }
        .accessibilityHidden(true)
    }

    private func glowSize(_ w: CGFloat, _ h: CGFloat) -> CGFloat { max(w, h) * (tone == .night ? 1.1 : 1.3) }

    private var backgroundGradient: some View {
        let p = Double(horizon)
        func at(_ f: Double) -> Double { min(max(f * p, 0), 1) }
        let stops: [Gradient.Stop]
        switch tone {
        case .night:
            stops = [.init(color: Color(hex: 0x060A1E), location: 0),
                     .init(color: Color(hex: 0x0F1A3D), location: at(0.55)),
                     .init(color: Color(hex: 0x22305C), location: at(0.85)),
                     .init(color: Color(hex: 0x6B5A5E), location: max(p - 0.03, 0)),
                     .init(color: Color(hex: 0xC8915A), location: p),
                     .init(color: LGColor.night, location: p),
                     .init(color: LGColor.night, location: 1)]
        case .dawn:
            stops = [.init(color: Color(hex: 0x1B2552), location: 0),
                     .init(color: Color(hex: 0x3A4A7E), location: at(0.5)),
                     .init(color: Color(hex: 0x9A8AA0), location: at(0.8)),
                     .init(color: Color(hex: 0xF2C38E), location: max(p - 0.02, 0)),
                     .init(color: Color(hex: 0xFFE2B0), location: p),
                     .init(color: LGColor.background, location: p),
                     .init(color: LGColor.background, location: 1)]
        case .day:
            stops = [.init(color: .clear, location: 0), .init(color: .clear, location: 1)]
        }
        return LinearGradient(stops: stops, startPoint: .top, endPoint: .bottom)
    }

    private var glow: Gradient {
        switch tone {
        case .night:
            // Peach, not gold: translucent gold over navy goes olive green on a phone. Peach over navy goes to mauve.
            Gradient(stops: [.init(color: Color(.sRGB, red: 242 / 255, green: 160 / 255, blue: 122 / 255, opacity: 0.55), location: 0),
                             .init(color: Color(.sRGB, red: 242 / 255, green: 160 / 255, blue: 122 / 255, opacity: 0.22), location: 0.30 / 0.62),
                             .init(color: Color(.sRGB, red: 242 / 255, green: 160 / 255, blue: 122 / 255, opacity: 0), location: 1)])
        case .dawn:
            Gradient(stops: [.init(color: Color(.sRGB, red: 1, green: 240 / 255, blue: 205 / 255, opacity: 0.85), location: 0),
                             .init(color: Color(.sRGB, red: 1, green: 205 / 255, blue: 140 / 255, opacity: 0.35), location: 0.32 / 0.64),
                             .init(color: Color(.sRGB, red: 1, green: 205 / 255, blue: 140 / 255, opacity: 0), location: 1)])
        case .day:
            Gradient(stops: [.init(color: Color(.sRGB, red: 1, green: 226 / 255, blue: 170 / 255, opacity: 0.7), location: 0),
                             .init(color: Color(.sRGB, red: 1, green: 214 / 255, blue: 150 / 255, opacity: 0.25), location: 0.34 / 0.64),
                             .init(color: Color(.sRGB, red: 1, green: 214 / 255, blue: 150 / 255, opacity: 0), location: 1)])
        }
    }

    /// How strongly the stars show: full at night, under half at dawn, none by day.
    private var starStrength: Double { tone == .night ? 1 : (tone == .dawn ? 0.45 : 0) }

    /// The natural star field of Logic/StarField.swift, one path per brightness class.
    private func drawStars(_ ctx: inout GraphicsContext, size: CGSize) {
        guard starStrength > 0 else { return }
        var paths = Array(repeating: Path(), count: StarClass.allCases.count)
        for s in StarField.cached(width: size.width, height: size.height, horizon: horizon) {
            paths[s.kind.rawValue].addEllipse(in: CGRect(x: s.x - s.radius, y: s.y - s.radius, width: 2 * s.radius, height: 2 * s.radius))
        }
        for kind in StarClass.allCases {
            ctx.fill(paths[kind.rawValue], with: .color(Color(hex: kind.hex).opacity(kind.opacity * starStrength)))
        }
    }

    private func drawMoon(_ ctx: inout GraphicsContext, size: CGSize) {
        let centre = CGPoint(x: size.width * moonAt.x, y: size.height * moonAt.y)
        ctx.fill(Path(SkyMoon.path(centre: centre)), with: .color(Color(hex: 0xF4E9D2).opacity(0.9)))
    }
}

/// The crescent moon of Sky.dc.html, drawn from the board's own SVG path (r = 14 around the moon's spot):
/// `M x+0.6r y-0.8r  A r r 0 1 1 x-r y+0.2r  A 0.95r 0.95r 0 0 0 x+0.6r y-0.8r Z`.
/// Lit along its lower right, with the horns pointing up-right and left. `Tools/MakeLaunchAssets.swift` keeps a copy.
enum SkyMoon {
    static let radius: CGFloat = 14

    static func path(centre c: CGPoint, radius r: CGFloat = radius) -> CGPath {
        let p = CGMutablePath()
        let a = CGPoint(x: c.x + 0.6 * r, y: c.y - 0.8 * r)
        let b = CGPoint(x: c.x - r, y: c.y + 0.2 * r)
        p.move(to: a)
        addSVGArc(p, from: a, to: b, radius: r, largeArc: true, sweep: true)
        addSVGArc(p, from: b, to: a, radius: 0.95 * r, largeArc: false, sweep: false)
        p.closeSubpath()
        return p
    }

    /// SVG's endpoint arc (circular, unrotated), converted to a centre arc. `sweep` true = increasing angle, which on
    /// a y-down screen is clockwise.
    static func addSVGArc(_ p: CGMutablePath, from a: CGPoint, to b: CGPoint, radius: CGFloat, largeArc: Bool, sweep: Bool) {
        let hx = (a.x - b.x) / 2, hy = (a.y - b.y) / 2
        let d2 = hx * hx + hy * hy
        let r = max(radius, d2.squareRoot())
        let k = (largeArc != sweep ? 1 : -1) * max(0, (r * r - d2) / d2).squareRoot()
        let centre = CGPoint(x: k * hy + (a.x + b.x) / 2, y: -k * hx + (a.y + b.y) / 2)
        let start = atan2(a.y - centre.y, a.x - centre.x)
        let end = atan2(b.y - centre.y, b.x - centre.x)
        p.addArc(center: centre, radius: r, startAngle: start, endAngle: end, clockwise: !sweep)
    }
}

// MARK: Land

/// The dunes and the sea, drawn in Land.dc.html's 390 × 120 box and stretched to fit. The sea is always opaque.
/// The shoreline and the contour lines sway side to side on their own loops; `still` (widgets, the Live Activity,
/// the year card image) and Reduce Motion stop that. The sea fill itself never moves.
struct LandView: View {
    var tone: SceneTone = .day
    var still = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    private var night: Bool { tone == .night }

    var body: some View {
        if still || reduceMotion {
            canvas(at: nil)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: scenePhase != .active)) { timeline in
                canvas(at: timeline.date.timeIntervalSinceReferenceDate)
            }
        }
    }

    private func canvas(at time: Double?) -> some View {
        Canvas { ctx, size in
            draw(&ctx, size: size, time: time)
        }
        .accessibilityHidden(true)
    }

    // The five loops: shoreline 9 s, contours 7, 8, 10 and 12 s (as in the board's lg-w0...lg-w4).
    private struct Sway {
        var period: Double
        var amplitude: CGFloat
        var dip: CGFloat
        var startsLeft: Bool

        func offset(at time: Double?) -> CGSize {
            guard let time else { return .zero }
            let c = CGFloat(cos(2 * .pi * time / period))
            // Ease-in-out between the two ends of the loop.
            if startsLeft { return CGSize(width: -amplitude * c, height: dip * (1 - c) / 2) }
            return CGSize(width: amplitude * c, height: dip * (1 + c) / 2)
        }
    }

    private static let shoreSway = Sway(period: 9, amplitude: 7, dip: 0.8, startsLeft: true)
    private static let contourSways = [Sway(period: 7, amplitude: 6, dip: 0.6, startsLeft: false),
                                       Sway(period: 8, amplitude: 7, dip: 0.8, startsLeft: true),
                                       Sway(period: 10, amplitude: 6, dip: 0.6, startsLeft: false),
                                       Sway(period: 12, amplitude: 7, dip: 0.8, startsLeft: true)]

    private func draw(_ ctx: inout GraphicsContext, size: CGSize, time: Double?) {
        let sx = size.width / 390, sy = size.height / 120
        let scale = CGAffineTransform(scaleX: sx, y: sy)
        func scaled(_ p: Path) -> Path { p.applying(scale) }

        // By day the dunes are see-through, so the sun and the sky glow show a little through them. At night they
        // are solid: the sleeping sun must be hidden cleanly behind them.
        let alpha: Double = night ? 1 : 0.6
        let farTop = night ? Color(hex: 0x5A4A5E) : Color(hex: 0xEBD6BC).opacity(alpha)
        let farBottom = night ? Color(hex: 0x2E2A45) : Color(hex: 0xF3E6D6).opacity(alpha)
        let mid = night ? LGColor.duneNight : LGColor.dune.opacity(alpha)
        let farGradient = { (rect: CGRect) in
            GraphicsContext.Shading.linearGradient(Gradient(colors: [farTop, farBottom]),
                                                   startPoint: CGPoint(x: 0, y: rect.minY), endPoint: CGPoint(x: 0, y: 46 * sy))
        }

        // Far dunes: a tall one on the left, a lower one on the right.
        var far1 = Path()
        far1.move(to: CGPoint(x: 0, y: 30))
        far1.addCurve(to: CGPoint(x: 70, y: 9), control1: CGPoint(x: 18, y: 18), control2: CGPoint(x: 44, y: 8))
        far1.addCurve(to: CGPoint(x: 142, y: 30), control1: CGPoint(x: 96, y: 10), control2: CGPoint(x: 118, y: 20))
        far1.addCurve(to: CGPoint(x: 214, y: 46), control1: CGPoint(x: 166, y: 39), control2: CGPoint(x: 190, y: 44))
        // The dunes run on down, well behind the sea, so no sliver of sky can show between a dune and the water.
        far1.addLine(to: CGPoint(x: 214, y: 75)); far1.addLine(to: CGPoint(x: 0, y: 75)); far1.closeSubpath()
        var far2 = Path()
        far2.move(to: CGPoint(x: 300, y: 46))
        far2.addCurve(to: CGPoint(x: 352, y: 36), control1: CGPoint(x: 318, y: 40), control2: CGPoint(x: 336, y: 36))
        far2.addCurve(to: CGPoint(x: 390, y: 41), control1: CGPoint(x: 366, y: 36), control2: CGPoint(x: 380, y: 38))
        far2.addLine(to: CGPoint(x: 390, y: 75)); far2.addLine(to: CGPoint(x: 300, y: 75)); far2.closeSubpath()
        let far1S = scaled(far1), far2S = scaled(far2)
        ctx.fill(far1S, with: farGradient(far1S.boundingRect))
        ctx.fill(far2S, with: farGradient(far2S.boundingRect))

        // Mid dunes in front.
        var mid1 = Path()
        mid1.move(to: CGPoint(x: 0, y: 38))
        mid1.addCurve(to: CGPoint(x: 82, y: 36), control1: CGPoint(x: 24, y: 33), control2: CGPoint(x: 52, y: 32))
        mid1.addCurve(to: CGPoint(x: 150, y: 47), control1: CGPoint(x: 108, y: 39), control2: CGPoint(x: 128, y: 44))
        mid1.addLine(to: CGPoint(x: 150, y: 75)); mid1.addLine(to: CGPoint(x: 0, y: 75)); mid1.closeSubpath()
        var mid2 = Path()
        mid2.move(to: CGPoint(x: 262, y: 47))
        mid2.addCurve(to: CGPoint(x: 362, y: 33), control1: CGPoint(x: 292, y: 43), control2: CGPoint(x: 330, y: 39))
        mid2.addCurve(to: CGPoint(x: 390, y: 30), control1: CGPoint(x: 374, y: 31), control2: CGPoint(x: 384, y: 30))
        mid2.addLine(to: CGPoint(x: 390, y: 75)); mid2.addLine(to: CGPoint(x: 262, y: 75)); mid2.closeSubpath()
        ctx.fill(scaled(mid1), with: .color(mid))
        ctx.fill(scaled(mid2), with: .color(mid))

        // The sea: opaque, from sea through seaDeep to the background (night: three navies). It does not move.
        var near = Path()
        near.move(to: CGPoint(x: 0, y: 46))
        near.addCurve(to: CGPoint(x: 195, y: 45), control1: CGPoint(x: 70, y: 41), control2: CGPoint(x: 130, y: 42))
        near.addCurve(to: CGPoint(x: 390, y: 44), control1: CGPoint(x: 260, y: 48), control2: CGPoint(x: 330, y: 50))
        near.addLine(to: CGPoint(x: 390, y: 120)); near.addLine(to: CGPoint(x: 0, y: 120)); near.closeSubpath()
        let seaColours = night ? LGColor.seaNight : [LGColor.sea, LGColor.seaDeep, LGColor.background]
        let nearS = scaled(near)
        ctx.fill(nearS, with: .linearGradient(
            Gradient(stops: [.init(color: seaColours[0], location: 0), .init(color: seaColours[1], location: 0.55), .init(color: seaColours[2], location: 1)]),
            startPoint: CGPoint(x: 0, y: nearS.boundingRect.minY), endPoint: CGPoint(x: 0, y: nearS.boundingRect.maxY)))
        // Solid fill under the very bottom so nothing can show through if the box is stretched.
        ctx.fill(Path(CGRect(x: 0, y: size.height - 1, width: size.width, height: 2)), with: .color(seaColours[2]))

        // Contour lines, spaced wider as they go down.
        let contourColour = night ? LGColor.contourNight : LGColor.contour
        let lines: [(y: CGFloat, c1: CGFloat, c2: CGFloat, mid: CGFloat, c3: CGFloat, end: CGFloat, width: CGFloat, opacity: Double)] = [
            (55, 51, 52, 54, 58, 53, 0.9, 0.7), (64, 61, 62, 63, 66, 62, 0.8, 0.5),
            (74, 72, 72, 73, 75, 72, 0.7, 0.32), (85, 84, 84, 85, 86, 84, 0.6, 0.18)]
        for (i, l) in lines.enumerated() {
            var p = Path()
            p.move(to: CGPoint(x: -20, y: l.y)); p.addLine(to: CGPoint(x: 0, y: l.y))
            p.addCurve(to: CGPoint(x: 195, y: l.mid), control1: CGPoint(x: 70, y: l.c1), control2: CGPoint(x: 130, y: l.c2))
            p.addCurve(to: CGPoint(x: 390, y: l.end), control1: CGPoint(x: 260, y: 2 * l.mid - l.c2), control2: CGPoint(x: 330, y: l.c3))
            p.addLine(to: CGPoint(x: 410, y: l.end))
            let o = Self.contourSways[i].offset(at: time)
            let moved = scaled(p).applying(CGAffineTransform(translationX: o.width * sx, y: o.height * sy))
            ctx.stroke(moved, with: .color(contourColour.opacity(l.opacity)), lineWidth: l.width)
        }

        // The shoreline: navy at 55% by day, warm sand at night.
        var shore = Path()
        shore.move(to: CGPoint(x: -20, y: 46)); shore.addLine(to: CGPoint(x: 0, y: 46))
        shore.addCurve(to: CGPoint(x: 195, y: 45), control1: CGPoint(x: 70, y: 41), control2: CGPoint(x: 130, y: 42))
        shore.addCurve(to: CGPoint(x: 390, y: 44), control1: CGPoint(x: 260, y: 48), control2: CGPoint(x: 330, y: 50))
        shore.addLine(to: CGPoint(x: 410, y: 44))
        let so = Self.shoreSway.offset(at: time)
        let shoreMoved = scaled(shore).applying(CGAffineTransform(translationX: so.width * sx, y: so.height * sy))
        ctx.stroke(shoreMoved, with: .color((night ? Color(hex: 0xC9A27A) : LGColor.ink).opacity(night ? 0.6 : 0.55)), lineWidth: 1.2)
    }
}

// MARK: Previews

#Preview("Sky · night, dawn, day") {
    HStack(spacing: 8) {
        ForEach([SceneTone.night, .dawn, .day], id: \.self) { tone in
            SkyView(tone: tone).frame(width: 130, height: 300)
        }
    }
    .padding().background(LGColor.background)
}

#Preview("Stars · night and dawn at phone, widget and Watch sizes") {
    // Each size has its own stars (seeded by the size), so these are four different skies.
    let sizes: [(String, CGSize, CGFloat)] = [("Phone", CGSize(width: 390, height: 844), 0.6),
                                             ("Widget, small", CGSize(width: 170, height: 170), 0.7),
                                             ("Widget, medium", CGSize(width: 364, height: 170), 0.7),
                                             ("Watch", CGSize(width: 184, height: 224), 0.7)]
    ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            ForEach([SceneTone.night, .dawn], id: \.self) { tone in
                ForEach(sizes, id: \.0) { name, size, horizon in
                    Text("\(name) · \(tone == .night ? "night" : "dawn")").font(.caption)
                    SkyView(tone: tone, horizon: horizon).frame(width: size.width, height: size.height)
                }
            }
        }
        .padding()
    }
    .background(LGColor.background)
}

#Preview("Land · day, night, still") {
    VStack(spacing: 8) {
        LandView(tone: .day).frame(height: 120)
        LandView(tone: .night).frame(height: 120)
        LandView(tone: .day, still: true).frame(height: 120)
    }
    .background(LGColor.background)
}

#Preview("Water rule · sun at its lowest on every tone") {
    // The sun sits at its lowest point (centre on the horizon, sea in front). No ray may show below the sea.
    VStack(spacing: 8) {
        ForEach([SceneTone.night, .dawn, .day], id: \.self) { tone in
            ZStack(alignment: .bottom) {
                SkyView(tone: tone, horizon: 1)
                SunView(idle: false, face: .sleepy)
                    .frame(width: 120, height: 120)
                    .offset(y: 60 - 120 * 0.38)
                LandView(tone: tone, still: true).frame(height: 120)
            }
            .frame(height: 260)
        }
    }
    .background(LGColor.background)
}
