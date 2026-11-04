import SwiftUI

/// The slim strip under the Timer header: a small arc that fills live, "Today's stretch" and "1 h 05 of 1 h 45".
/// When the stretch is covered the strip turns gold. It never asks for attention: no sound, no pop-up, no haptic.
struct StretchStrip: View {
    var done: TimeInterval
    var target: TimeInterval
    /// The sun winks (closed-eye arcs on one side) for a moment when the stretch gets covered.
    var winking = false

    private var covered: Bool { done >= target }
    private var fraction: Double { target > 0 ? GaugeGeometry.clamped(done / target) : 0 }

    // A small version of Today's arc, 84 × 44 pt: from the left end at (13, 38) over the top (y 13) to the moon.
    private let arc = ArcGeometry(centreX: 42, baseY: 38, radiusX: 29, radiusY: 25, sunSize: 18)

    var body: some View {
        HStack(spacing: 12) {
            miniArc
            VStack(alignment: .leading, spacing: 1) {
                Text("Today's stretch").lgText(LGTextStyle(size: 12, weight: .regular, relativeTo: .caption), color: .white.opacity(0.65))
                Text(verbatim: covered ? StretchText.stripCovered(target) : StretchText.progress(done: done, target: target))
                    .lgText(LGTextStyle(size: 15, weight: .semibold, relativeTo: .subheadline),
                            color: covered ? LGColor.mote : .white)
                    .monospacedDigit()
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(covered
            ? String(localized: "Today's stretch covered, \(StretchText.spoken(seconds: target))")
            : String(localized: "Today's stretch: \(StretchText.spoken(seconds: done)) of \(StretchText.spoken(seconds: target))"))
    }

    private var miniArc: some View {
        let sun = arc.point(fraction)
        return ZStack(alignment: .topLeading) {
            Path { p in
                p.move(to: CGPoint(x: 3, y: arc.baseY))
                p.addLine(to: CGPoint(x: 81, y: arc.baseY))
            }
            .stroke(.white.opacity(0.25), lineWidth: 1.5)
            ArcShape(geometry: arc)
                .stroke(.white.opacity(0.25), style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [2, 7]))
            ArcShape(geometry: arc, upTo: fraction)
                .stroke(covered ? LGColor.mote : LGColor.sunRaysBright, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
            MoonShape()
                .fill(LGColor.moonOnDark)
                .frame(width: 24, height: 24)
                .offset(x: arc.point(1).x - 9, y: 18)
            SunView(face: winking ? .wink : .focus)
                .frame(width: 18, height: 18)
                .position(x: sun.x, y: sun.y)
        }
        .frame(width: 84, height: 44, alignment: .topLeading)
        .accessibilityHidden(true)
    }
}

#Preview("Strip · on the way, nearly, covered") {
    VStack(spacing: 10) {
        StretchStrip(done: 65 * 60, target: 105 * 60)
        StretchStrip(done: 100 * 60, target: 105 * 60)
        StretchStrip(done: 110 * 60, target: 105 * 60)
        StretchStrip(done: 0, target: 105 * 60)
    }
    .padding()
    .background(Color(hex: 0x1F2A5A))
}
