import SwiftUI

/// The timer's sky: navy that warms through violet to rose over each hour.
struct TimerSky: View {
    /// 0...1 through the hour.
    let warmth: Double
    let paused: Bool

    private static let top: [UInt32] = [0x16244A, 0x1F2A5A, 0x2C3466]
    private static let mid: [UInt32] = [0x1F2A5A, 0x3A2F6B, 0x8C5A8E]
    private static let bottom: [UInt32] = [0x2A2F63, 0x6E3D74, 0xC2678A]

    var body: some View {
        LinearGradient(stops: [
            .init(color: Self.color(Self.top, warmth), location: 0),
            .init(color: Self.color(Self.mid, warmth), location: 0.5),
            .init(color: Self.color(Self.bottom, warmth), location: 1),
        ], startPoint: .top, endPoint: .bottom)
        .saturation(paused ? 0.45 : 1)
        .animation(.easeOut(duration: 0.5), value: paused)
        .ignoresSafeArea()
    }

    /// Piecewise blend across three stages (navy, violet, rose).
    private static func color(_ stages: [UInt32], _ w: Double) -> Color {
        let x = min(1, max(0, w)) * 2
        let i = min(1, Int(x))
        return blend(stages[i], stages[i + 1], x - Double(i))
    }

    private static func blend(_ a: UInt32, _ b: UInt32, _ t: Double) -> Color {
        func channel(_ shift: UInt32) -> Double {
            let ca = Double((a >> shift) & 0xFF), cb = Double((b >> shift) & 0xFF)
            return (ca + (cb - ca) * t) / 255
        }
        return Color(.sRGB, red: channel(16), green: channel(8), blue: channel(0), opacity: 1)
    }
}
