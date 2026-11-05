import SwiftUI

/// A small sun for a tip row. Bigger tips have more rays; the biggest one also has cheeks and a smile.
struct TipSunIcon: View {
    let tier: TipTier

    var body: some View {
        Canvas { context, size in
            let s = size.width / 200
            func point(_ r: Double, _ k: Int) -> CGPoint {
                let a = (Double(k) * 30 - 90) * .pi / 180
                return CGPoint(x: (100 + r * cos(a)) * s, y: (100 + r * sin(a)) * s)
            }
            var rays = Path()
            for k in tier.rays {
                rays.move(to: point(66, k))
                rays.addLine(to: point(k % 2 == 1 ? 92 : 82, k))
            }
            context.stroke(rays, with: .color(LGColor.sunRays), style: StrokeStyle(lineWidth: 12 * s, lineCap: .round))
            let body = CGRect(x: 44 * s, y: 44 * s, width: 112 * s, height: 112 * s)
            context.fill(Path(ellipseIn: body), with: .color(LGColor.sunBody))
            if tier.hasFace {
                for x in [72.0, 128.0] {
                    context.fill(Path(ellipseIn: CGRect(x: (x - 7) * s, y: 106 * s, width: 14 * s, height: 14 * s)),
                                 with: .color(LGColor.sunCheeks))
                }
                var face = Path()
                for x in [76.0, 108.0] {
                    face.move(to: CGPoint(x: x * s, y: 98 * s))
                    face.addQuadCurve(to: CGPoint(x: (x + 16) * s, y: 98 * s), control: CGPoint(x: (x + 8) * s, y: 89 * s))
                }
                face.move(to: CGPoint(x: 88 * s, y: 114 * s))
                face.addQuadCurve(to: CGPoint(x: 112 * s, y: 114 * s), control: CGPoint(x: 100 * s, y: 125 * s))
                context.stroke(face, with: .color(LGColor.ink), style: StrokeStyle(lineWidth: 4.5 * s, lineCap: .round))
            }
        }
        .frame(width: 40, height: 40)
        .accessibilityHidden(true)
    }
}

extension TipTier {
    var title: LocalizedStringKey {
        switch self {
        case .ray: "A ray of sunshine"
        case .morning: "A sunny morning"
        case .goldenhour: "A golden hour"
        case .sunrise: "A whole sunrise"
        }
    }

    var line: LocalizedStringKey {
        switch self {
        case .ray: "A small thank-you"
        case .morning: "Like buying a coffee"
        case .goldenhour: "A big thank-you"
        case .sunrise: "For the biggest fans"
        }
    }

    var spokenTitle: String {
        switch self {
        case .ray: String(localized: "A ray of sunshine")
        case .morning: String(localized: "A sunny morning")
        case .goldenhour: String(localized: "A golden hour")
        case .sunrise: String(localized: "A whole sunrise")
        }
    }
}
