import SwiftUI

/// Mini suns and petals bursting out of the sun when a session is saved.
struct SaveBurst: View {
    /// 0...1 over the 1.2 s burst.
    let progress: Double

    var body: some View {
        let eased = 1 - pow(1 - progress, 3)
        ZStack {
            ForEach(0..<8, id: \.self) { i in
                let angle = Double(i) / 8 * 2 * .pi + 0.2
                SunView(face: .happy, unlitOpacity: 1)
                    .frame(width: 30, height: 30)
                    .offset(x: cos(angle) * 150 * eased, y: sin(angle) * 150 * eased)
                    .scaleEffect(0.6 + 0.6 * sin(progress * .pi))
                    .opacity(1 - pow(progress, 2))
            }
            ForEach(0..<12, id: \.self) { i in
                let angle = Double(i) / 12 * 2 * .pi
                Capsule()
                    .fill(i.isMultiple(of: 2) ? LGColor.sunCheeks : LGColor.sunRaysBright)
                    .frame(width: 8, height: 16)
                    .rotationEffect(.radians(angle + .pi / 2))
                    .offset(x: cos(angle) * 105 * eased, y: sin(angle) * 105 * eased)
                    .opacity(1 - progress)
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}
