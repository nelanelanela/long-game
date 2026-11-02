import SwiftUI

// The sun rising out of the sea: one set of components for Home (as a gauge), the intro pages and the future-self sheet.
//
// Layer order, back to front: glow → sun → sea fill → pale wave → navy wave line → glints → fade.
// The sea is one closed, fully opaque shape whose top edge is the navy wave path, and the sun is also masked to
// the area above that path, so no part of it can show below the waterline at any phase, size or scale.

/// Where everything sits, in points inside a hero that is as wide as its container and `height` tall.
struct SunriseLayout {
    var height: CGFloat
    /// The middle of the navy wave line.
    var waterY: CGFloat
    var sunSize: CGFloat
    /// Top edge of the sun's 200 × 200 box.
    var sunTop: CGFloat
    /// 0 = no glow.
    var glowSize: CGFloat = 0
    var glowStrength: Double = 0.28
    /// Glow centre below the sun's centre.
    var glowDy: CGFloat = 0
    /// How far right of the middle the sun, its glow and the glints sit (Home leaves room for the scale).
    var sunOffsetX: CGFloat = 0
    var glints = false
    /// Home and the future-self sheet: the sun opens its eyes for a peek every 7 s.
    var peeks = false
    var litRays = 12
    var face: SunFace = .happy
    /// The colour the bottom of the sea fades into.
    var fade: Color = LGColor.background
    var fadeHeight: CGFloat = 34

    static let homeSeaHeight: CGFloat = 64

    /// Home: the sun as a gauge. Its centre runs linearly from the horizon (0) to the top tick (1) and stays at the
    /// top above 1, with the celebrate face (eyes already open, so no peeking).
    static func gauge(fraction: Double, face: SunFace = .happy, metrics: GaugeMetrics = .standard) -> SunriseLayout {
        SunriseLayout(
            height: metrics.height, waterY: metrics.waterY, sunSize: metrics.sunSize,
            sunTop: metrics.centreY(fraction: fraction) - metrics.sunSize / 2,
            glowSize: 260 * metrics.sunSize / GaugeGeometry.sunSize, glowStrength: 0.28, glowDy: 0,
            sunOffsetX: metrics.sunOffsetX, glints: true, peeks: face != .celebrate, face: face)
    }

    /// Pages 0, 1, 2 of "How the game works": the sun high, just rising, and with 8 of 12 rays lit.
    static func intro(page: Int) -> SunriseLayout {
        let tops: [CGFloat] = [70, 150, 96]
        let index = min(max(page, 0), 2)
        return SunriseLayout(height: 300, waterY: 244, sunSize: 170, sunTop: tops[index], litRays: index == 2 ? 8 : 12)
    }

    static let futureSelf = SunriseLayout(
        height: 190, waterY: 190 - homeSeaHeight + 12, sunSize: 150, sunTop: 0,
        glowSize: 240, glowStrength: 0.35, glowDy: 19, glints: true, peeks: true, fade: .white)
}

/// One moment of the animation. `SunriseFrame.at(_:)` gives the live one, `.still` the Reduce Motion one.
struct SunriseFrame {
    var phaseRight: CGFloat = 0
    var phaseLeft: CGFloat = 0
    var breathe: Double = 0
    var rotation: Double = 0
    var eyesOpen: Double = 0
    var glowOpacity: Double = 0.55
    var glowScale: Double = 1
    var glints: [(opacity: Double, scaleX: Double)] = Array(repeating: (0.8, 1), count: 4)
    /// How far below its resting place the sun still is (the future-self sheet).
    var rise: CGFloat = 0

    static let still = SunriseFrame()

    static func at(_ t: TimeInterval, peeks: Bool, rise: CGFloat = 0) -> SunriseFrame {
        SunriseFrame(
            phaseRight: SunriseMotion.wavePhaseRight(t), phaseLeft: SunriseMotion.wavePhaseLeft(t),
            breathe: SunriseMotion.breathe(t), rotation: SunriseMotion.rotationDegrees(t),
            eyesOpen: peeks ? SunriseMotion.eyesOpen(t) : 0,
            glowOpacity: SunriseMotion.glowOpacity(t), glowScale: SunriseMotion.glowScale(t),
            glints: SunriseMotion.glintDelays.map { SunriseMotion.glint(t, delay: $0) }, rise: rise)
    }

    /// Frozen at a wave phase, for previews and tests. `breathe` 0 is the sun at its lowest (the worst case for
    /// "nothing shows below the water"); 1 is it at its highest and largest.
    static func frozen(phase: CGFloat, breathe: Double = 0, rise: CGFloat = 0, eyesOpen: Double = 0) -> SunriseFrame {
        var f = SunriseFrame()
        f.phaseRight = phase
        f.phaseLeft = SunriseMotion.wavelength - phase
        f.breathe = breathe
        f.rotation = Double(phase) * 3
        f.eyesOpen = eyesOpen
        f.rise = rise
        return f
    }
}

/// The drawing itself: no clock, no state. Previews and tests feed it frames directly.
struct SunriseCanvas: View {
    var layout: SunriseLayout
    var frame: SunriseFrame = .still
    /// Tests turn the glints off: they are gold dashes that belong on the water.
    var showsGlints = true

    private static let glintShapes: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat)] = [
        (176, 22, 38, 3), (164, 36, 22, 3), (204, 40, 16, 3), (186, 50, 12, 2.5),
    ]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = layout.height
            let size = layout.sunSize
            ZStack(alignment: .topLeading) {
                if layout.glowSize > 0 { glow(width: w) }

                // The sun, clipped to the area above the wave path.
                Color.clear
                    .frame(width: w, height: h)
                    .overlay(alignment: .topLeading) {
                        SunView(face: layout.face, litRays: layout.litRays, raysRotation: .degrees(frame.rotation),
                                rayColor: LGColor.sunRays, eyesOpen: frame.eyesOpen)
                            .frame(width: size, height: size)
                            .scaleEffect(1 + 0.03 * frame.breathe)
                            .offset(x: w / 2 - size / 2 + layout.sunOffsetX, y: layout.sunTop + frame.rise - 3 * frame.breathe)
                    }
                    .mask { AboveWater(waterY: layout.waterY, phase: frame.phaseRight).fill(Color.black) }

                SeaFill(waterY: layout.waterY, phase: frame.phaseRight).fill(LGColor.seaFill)
                WaveLine(y: layout.waterY + 18, phase: frame.phaseLeft + 10)
                    .stroke(LGColor.seaWave, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                WaveLine(y: layout.waterY, phase: frame.phaseRight)
                    .stroke(LGColor.ink, style: StrokeStyle(lineWidth: 2, lineCap: .round))

                if layout.glints && showsGlints { glints(width: w) }

                // The fade into the background sits on top of the sea, never as transparency inside it.
                LinearGradient(stops: [
                    .init(color: layout.fade.opacity(0), location: 0),
                    .init(color: layout.fade.opacity(0.85), location: 0.7),
                    .init(color: layout.fade, location: 1),
                ], startPoint: .top, endPoint: .bottom)
                .frame(height: layout.fadeHeight)
                .offset(y: h - layout.fadeHeight)
            }
            .frame(width: w, height: h, alignment: .topLeading)
            .clipped()
        }
        .frame(height: layout.height)
    }

    private func glow(width w: CGFloat) -> some View {
        let d = layout.glowSize
        let centreY = layout.sunTop + layout.sunSize / 2 + layout.glowDy + frame.rise
        return Circle()
            .fill(RadialGradient(colors: [LGColor.sunBody.opacity(layout.glowStrength), LGColor.sunBody.opacity(0)],
                                 center: .center, startRadius: 0, endRadius: d * 0.44))
            .frame(width: d, height: d)
            .scaleEffect(frame.glowScale)
            .opacity(frame.glowOpacity)
            .position(x: w / 2 + layout.sunOffsetX, y: centreY)
    }

    private func glints(width w: CGFloat) -> some View {
        ZStack {
            ForEach(0..<Self.glintShapes.count, id: \.self) { i in
                let g = Self.glintShapes[i]
                let state = frame.glints[min(i, frame.glints.count - 1)]
                RoundedRectangle(cornerRadius: g.h / 2)
                    .fill(LGColor.sunBody)
                    .frame(width: g.w, height: g.h)
                    .scaleEffect(x: state.scaleX, y: 1)
                    .opacity(state.opacity)
                    .position(x: w / 2 + layout.sunOffsetX + g.x + g.w / 2 - 195, y: layout.waterY - 12 + g.y + g.h / 2)
            }
        }
    }
}

/// The live hero. It re-draws about 30 times a second while it is running and stands still when `isRunning` is
/// false (Home is not on screen) or Reduce Motion is on.
struct SunriseHero: View {
    var layout: SunriseLayout
    var label: String
    var isRunning = true
    /// The future-self sheet: when it opened, so the sun can rise into place.
    var riseStart: Date?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !isRunning || reduceMotion)) { timeline in
            SunriseCanvas(layout: layout, frame: frame(at: timeline.date))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isImage)
    }

    private func frame(at date: Date) -> SunriseFrame {
        guard !reduceMotion else { return .still }
        let rise = riseStart.map { SunriseMotion.rise(after: date.timeIntervalSince($0)) } ?? 0
        return .at(date.timeIntervalSinceReferenceDate, peeks: layout.peeks, rise: rise)
    }
}

// MARK: Previews (frozen, so every phase can be inspected)

#Preview("Intro pages") {
    ScrollView {
        VStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { page in
                SunriseCanvas(layout: .intro(page: page), frame: .frozen(phase: CGFloat(page) * 14))
            }
        }
    }
    .background(LGColor.background)
}

#Preview("Future self · rising") {
    VStack(spacing: 8) {
        ForEach([SunriseMotion.riseDistance, 17, 0], id: \.self) { rise in
            SunriseCanvas(layout: .futureSelf, frame: .frozen(phase: 9, rise: rise))
                .background(LinearGradient(gradient: LGColor.futureSky, startPoint: .top, endPoint: .bottom))
        }
    }
}
