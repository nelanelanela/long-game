import SwiftUI

/// Draws one stage of the app icon (the "10,000 ring") with the real SunView, for checking in Xcode previews.
/// The PNGs themselves come from `Tools/MakeIcon.swift`, which uses the same geometry (1024-point canvas).
struct IconStageView: View {
    var stage: IconStage
    var tinted = false

    var body: some View {
        let ink = tinted ? Color.black : LGColor.ink
        let gold = tinted ? Color.white : LGColor.sunRaysBright
        let celebrate = stage.thousands == IconStage.maxThousands
        let fill = stage.ringFill
        let angle = Angle.degrees(-90 + 360 * (fill >= 1 ? 0 : fill))
        let k: CGFloat = celebrate ? 1.3 : 1.1
        let halo: CGFloat = celebrate ? 132 : 112
        Canvas { ctx, _ in
            let c = CGPoint(x: 512, y: 512)
            let ring = Path(ellipseIn: CGRect(x: 152, y: 152, width: 720, height: 720))
            ctx.stroke(ring, with: .color(.white.opacity(tinted ? 0.20 : 0.14)), lineWidth: 56)
            if fill >= 1 {
                ctx.stroke(ring, with: .color(gold), lineWidth: 56)
            } else if fill > 0 {
                var arc = Path()
                arc.addArc(center: c, radius: 360, startAngle: .degrees(-90), endAngle: angle, clockwise: false)
                ctx.stroke(arc, with: .color(gold), style: StrokeStyle(lineWidth: 56, lineCap: .round))
            }
        }
        .frame(width: 1024, height: 1024)
        .overlay {
            ZStack {
                Circle().fill(ink).frame(width: halo * 2, height: halo * 2)
                SunView(idle: false, face: celebrate ? .celebrate : .happy, rayColor: gold)
                    .frame(width: 200 * k, height: 200 * k)
            }
            .position(x: 512 + 360 * cos(angle.radians), y: 512 + 360 * sin(angle.radians))
        }
        .overlay {
            Text(stage.number)
                .font(.system(size: 176, weight: .bold))
                .tracking(-6)
                .foregroundStyle(.white)
        }
        .background {
            if tinted { ink } else {
                LinearGradient(colors: [Color(hex: 0x0B1433), Color(hex: 0x16244A), Color(hex: 0x2B2A4A)], startPoint: .top, endPoint: .bottom)
            }
        }
        .clipped()
        .accessibilityHidden(true)
    }
}

private struct IconStageGrid: View {
    var tinted = false
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(150), spacing: 12), count: 4), spacing: 12) {
            ForEach(IconStage.all, id: \.self) { stage in
                IconStageView(stage: stage, tinted: tinted)
                    .scaleEffect(150.0 / 1024, anchor: .topLeading)
                    .frame(width: 150, height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
            }
        }
        .padding(16)
    }
}

#Preview("App icons · normal") { IconStageGrid() }
#Preview("App icons · dark") { IconStageGrid().background(.black).environment(\.colorScheme, .dark) }
#Preview("App icons · tinted") { IconStageGrid(tinted: true).background(.black) }
