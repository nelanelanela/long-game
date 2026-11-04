import SwiftUI

/// Today's arc and its moon: a wide half-ellipse from the sea on the left to a small moon on the horizon on the
/// right ("today's resting place"). The dotted road is always whole; the part travelled is a solid gold line.
/// No ticks, no labels: the arc is the scale.

/// Where the arc sits inside a hero `width` wide.
struct ArcGeometry: Equatable {
    var centreX: CGFloat
    var baseY: CGFloat
    var radiusX: CGFloat
    var radiusY: CGFloat
    /// The sun on the arc is smaller than the gauge's (about 120 pt).
    var sunSize: CGFloat

    init(centreX: CGFloat, baseY: CGFloat, radiusX: CGFloat, radiusY: CGFloat, sunSize: CGFloat) {
        self.centreX = centreX
        self.baseY = baseY
        self.radiusX = radiusX
        self.radiusY = radiusY
        self.sunSize = sunSize
    }

    init(width: CGFloat, metrics: GaugeMetrics) {
        // The same side margins as the gauge's scale line (45 pt on a phone), so the arc starts where the scale would.
        let margin = max(40, metrics.scaleX - 3)
        sunSize = metrics.sunSize >= 170 ? 120 : metrics.sunSize
        centreX = width / 2
        baseY = metrics.waterY
        radiusX = max(60, (width - 2 * margin) / 2)
        radiusY = max(40, metrics.waterY - (sunSize / 2 + 8))
    }

    func point(_ fraction: Double) -> CGPoint {
        StretchArc.point(fraction: fraction, centreX: centreX, baseY: baseY, radiusX: radiusX, radiusY: radiusY)
    }
}

/// The half-ellipse up to `upTo` (0...1 of the way along), as a polyline so the sun and the gold line agree exactly.
struct ArcShape: Shape {
    var geometry: ArcGeometry
    var upTo: Double = 1

    nonisolated var animatableData: Double {
        get { upTo }
        set { upTo = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let end = GaugeGeometry.clamped(upTo)
        guard end > 0 else {
            p.move(to: geometry.point(0))
            return p
        }
        let steps = max(2, Int((64 * end).rounded(.up)))
        p.move(to: geometry.point(0))
        for i in 1...steps { p.addLine(to: geometry.point(end * Double(i) / Double(steps))) }
        return p
    }
}

/// A small crescent moon, drawn in a 24 × 24 grid.
struct MoonShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 24
        func circle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) -> Path {
            Path(ellipseIn: CGRect(x: rect.minX + (cx - r) * s, y: rect.minY + (cy - r) * s, width: 2 * r * s, height: 2 * r * s))
        }
        return circle(12.19, 10, 8).subtracting(circle(15, 8.75, 7.385))
    }
}

/// The arc, the gold line travelled so far and the moon, drawn behind the sea and the sun.
struct StretchArcLayer: View {
    var geometry: ArcGeometry
    /// How far along the sun is: the gold line stops here.
    var fraction: Double
    var moon: Color = LGColor.moon

    var body: some View {
        let g = geometry
        let end = g.point(1)
        let moonSize = 31 * g.sunSize / 120
        ZStack(alignment: .topLeading) {
            ArcShape(geometry: g)
                .stroke(LGColor.arcDots, style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [2, 8]))
            ArcShape(geometry: g, upTo: fraction)
                .stroke(LGColor.sunRays, style: StrokeStyle(lineWidth: 3, lineCap: .round))
            // Resting on the horizon: its bottom edge a little above the waterline.
            MoonShape()
                .fill(moon)
                .frame(width: moonSize, height: moonSize)
                .offset(x: end.x - moonSize / 2 + 1, y: end.y - moonSize - 13 * g.sunSize / 120)
        }
        .accessibilityHidden(true)
    }
}

#Preview("Arc · 0, most of the way, covered") {
    VStack(spacing: 8) {
        ForEach([0.0, 0.62, 1.0], id: \.self) { f in
            let g = ArcGeometry(width: 390, metrics: .standard)
            StretchArcLayer(geometry: g, fraction: f)
                .frame(width: 390, height: 280)
                .background(LGColor.background)
        }
    }
}
