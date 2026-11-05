import SwiftUI

// The sun rising out of the sea: one set of components for Home (as a gauge), the intro pages and the future-self sheet.
//
// Layer order, back to front: glow → sun → sea fill → pale wave → navy wave line → fade.
// The sea is one closed, fully opaque shape whose top edge is the navy wave path, and the sun is also masked to
// the area above that path, so no part of it can show below the waterline at any phase, size or scale.

/// The colours of the sea: the fill, the pale second wave and the line on top. Day is Home's; Evening is the year
/// card's navy look. The water never has anything gold in it, whatever the palette.
struct SeaPalette: Equatable {
    var fill: Color
    var secondWave: Color
    var line: Color

    static let day = SeaPalette(fill: LGColor.seaFill, secondWave: LGColor.seaWave, line: LGColor.ink)
    static let evening = SeaPalette(fill: Color(hex: 0x2B3A73), secondWave: Color(hex: 0x4A5A96), line: Color(hex: 0x9FB0E0))
}

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
    /// How far right of the middle the sun and its glow sit (Home leaves room for the scale).
    var sunOffsetX: CGFloat = 0
    /// Home and the future-self sheet: the sun opens its eyes for a peek every 7 s.
    var peeks = false
    var litRays = 12
    var face: SunFace = .happy
    /// The colour the bottom of the sea fades into.
    var fade: Color = LGColor.background
    var fadeHeight: CGFloat = 34
    var sea: SeaPalette = .day

    static let homeSeaHeight: CGFloat = 64

    /// Home: the sun as a gauge. Its centre runs linearly from the horizon (0) to the top tick (1) and stays at the
    /// top above 1, with the celebrate face (eyes already open, so no peeking).
    static func gauge(fraction: Double, face: SunFace = .happy, metrics: GaugeMetrics = .standard) -> SunriseLayout {
        SunriseLayout(
            height: metrics.height, waterY: metrics.waterY, sunSize: metrics.sunSize,
            sunTop: metrics.centreY(fraction: fraction) - metrics.sunSize / 2,
            glowSize: 260 * metrics.sunSize / GaugeGeometry.sunSize, glowStrength: 0.28, glowDy: 0,
            sunOffsetX: metrics.sunOffsetX, peeks: face != .celebrate, face: face)
    }

    /// The sun anywhere in the hero: `centre` is where the middle of the sun is, measured from the hero's top left.
    /// Home uses it while the sun glides between its place on the scale and its place on Today's arc.
    static func placed(centre: CGPoint, width: CGFloat, sunSize: CGFloat, face: SunFace = .happy,
                       metrics: GaugeMetrics = .standard) -> SunriseLayout {
        SunriseLayout(
            height: metrics.height, waterY: metrics.waterY, sunSize: sunSize,
            sunTop: centre.y - sunSize / 2,
            glowSize: 260 * sunSize / GaugeGeometry.sunSize, glowStrength: 0.28, glowDy: 0,
            sunOffsetX: centre.x - width / 2, peeks: face != .celebrate, face: face)
    }

    /// Pages 0, 1, 2 of "How the game works": the sun high, just rising, and with 8 of 12 rays lit.
    static func intro(page: Int) -> SunriseLayout {
        let tops: [CGFloat] = [70, 150, 96]
        let index = min(max(page, 0), 2)
        return SunriseLayout(height: 300, waterY: 244, sunSize: 170, sunTop: tops[index], litRays: index == 2 ? 8 : 12)
    }

    /// The year card: a 160 pt sun in a 222 pt hero, 360 pt wide. The sea ends flat; there is no fade.
    static func yearCard(sea: SeaPalette, glowStrength: Double) -> SunriseLayout {
        SunriseLayout(height: 222, waterY: 186, sunSize: 160, sunTop: 50, glowSize: 230, glowStrength: glowStrength,
                      fadeHeight: 0, sea: sea)
    }

    static let futureSelf = SunriseLayout(
        height: 190, waterY: 190 - homeSeaHeight + 12, sunSize: 150, sunTop: 0,
        glowSize: 240, glowStrength: 0.35, glowDy: 19, peeks: true, fade: .white)
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
    /// How far below its resting place the sun still is (the future-self sheet).
    var rise: CGFloat = 0

    static let still = SunriseFrame()

    static func at(_ t: TimeInterval, peeks: Bool, rise: CGFloat = 0) -> SunriseFrame {
        SunriseFrame(
            phaseRight: SunriseMotion.wavePhaseRight(t), phaseLeft: SunriseMotion.wavePhaseLeft(t),
            breathe: SunriseMotion.breathe(t), rotation: SunriseMotion.rotationDegrees(t),
            eyesOpen: peeks ? SunriseMotion.eyesOpen(t) : 0,
            glowOpacity: SunriseMotion.glowOpacity(t), glowScale: SunriseMotion.glowScale(t),
            rise: rise)
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
    /// The giggle that is running (the live hero), or a frozen moment of one (previews and tests).
    var giggleRun: GiggleRun?
    var gigglePose: GigglePose = .rest

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
                        sun(size: size)
                            .frame(width: size, height: size)
                            .scaleEffect(1 + 0.03 * frame.breathe)
                            .offset(x: w / 2 - size / 2 + layout.sunOffsetX, y: layout.sunTop + frame.rise - 3 * frame.breathe)
                    }
                    .mask { AboveWater(waterY: layout.waterY, phase: frame.phaseRight).fill(Color.black) }

                SeaFill(waterY: layout.waterY, phase: frame.phaseRight).fill(layout.sea.fill)
                WaveLine(y: layout.waterY + 18, phase: frame.phaseLeft + 10)
                    .stroke(layout.sea.secondWave, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                WaveLine(y: layout.waterY, phase: frame.phaseRight)
                    .stroke(layout.sea.line, style: StrokeStyle(lineWidth: 2, lineCap: .round))

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

    /// The sun, through the giggle when there is one. Only the sun moves: the sea and its mask are drawn after it.
    @ViewBuilder
    private func sun(size: CGFloat) -> some View {
        if giggleRun != nil {
            GigglingSun(run: giggleRun) { pose in sunView(pose) }
        } else {
            sunView(gigglePose)
        }
    }

    private func sunView(_ pose: GigglePose) -> SunView {
        SunView(face: layout.face, litRays: layout.litRays, raysRotation: .degrees(frame.rotation),
                rayColor: LGColor.sunRays, eyesOpen: pose.face == nil ? frame.eyesOpen : 0, giggle: pose)
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
}

/// The live hero. It re-draws about 30 times a second while it is running and stands still when `isRunning` is
/// false (Home is not on screen) or Reduce Motion is on.
struct SunriseHero: View {
    var layout: SunriseLayout
    /// What VoiceOver reads first: the sun's place in words.
    var label: String
    /// Then the numbers. Changes are announced without moving focus.
    var value = ""
    /// When set (This week), swiping up or down on the sun reads one day of the week at a time.
    var dayReadings: [String] = []
    var isRunning = true
    /// The future-self sheet: when it opened, so the sun can rise into place.
    var riseStart: Date?
    /// False where the sun must stay still when tapped.
    var giggles = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.giggleSoundOn) private var soundOn
    @State private var giggle = GiggleController()
    @State private var dayIndex: Int?

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !isRunning || reduceMotion)) { timeline in
            let current = frame(at: timeline.date)
            SunriseCanvas(layout: layout, frame: current, giggleRun: giggle.run)
                .overlay { if giggles { tapTarget(frame: current) } }
        }
        // A tab change must never cross-fade the picture (sun ghosting through a see-through sea). The sun's glide
        // comes from the parent re-placing it every frame; the sea has nothing to animate and stays put.
        .transaction { $0.animation = nil }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(dayIndex.flatMap { dayReadings.indices.contains($0) ? dayReadings[$0] : nil } ?? value)
        .accessibilityAddTraits(.isImage)
        .lgAdjustable(!dayReadings.isEmpty) { direction in
            switch direction {
            case .increment: dayIndex = min((dayIndex ?? -1) + 1, dayReadings.count - 1)
            case .decrement: dayIndex = max((dayIndex ?? dayReadings.count) - 1, 0)
            @unknown default: break
            }
        }
        .accessibilityAction(named: Text("Tickle the sun")) { if giggles { tickle() } }
        .task(id: soundOn) { if giggles { giggle.prepare(soundOn: soundOn) } }
    }

    private func tickle() {
        giggle.tap(soundOn: soundOn, reduceMotion: reduceMotion)
    }

    /// The whole sun, and at least 44 pt, but never below the waterline.
    private func tapTarget(frame: SunriseFrame) -> some View {
        GeometryReader { geo in
            let side = max(layout.sunSize, 44)
            let centreX = geo.size.width / 2 + layout.sunOffsetX
            let centreY = layout.sunTop + layout.sunSize / 2 + frame.rise
            let top = centreY - side / 2
            let bottom = min(centreY + side / 2, layout.waterY)
            Color.clear
                .contentShape(Rectangle())
                .frame(width: side, height: max(0, bottom - top))
                .position(x: centreX, y: top + max(0, bottom - top) / 2)
                .onTapGesture { tickle() }
        }
    }

    private func frame(at date: Date) -> SunriseFrame {
        guard !reduceMotion else { return .still }
        let rise = riseStart.map { SunriseMotion.rise(after: date.timeIntervalSince($0)) } ?? 0
        return .at(date.timeIntervalSinceReferenceDate, peeks: layout.peeks, rise: rise)
    }
}

// MARK: Previews (frozen, so every phase can be inspected)

#Preview("Giggle · every phase") {
    // The sequence at its key moments, frozen. The sea stays in front at every frame.
    let moments: [(String, Double)] = [("0 tap", 0), ("0.05 gasp", 0.05), ("0.10", 0.10), ("0.18 squash", 0.18), ("0.26 stretch", 0.26),
                                       ("0.42 squash", 0.42), ("0.58", 0.58), ("0.74", 0.74), ("0.90 contented", 0.90),
                                       ("1.05 hiccup", 1.05), ("1.15", 1.15), ("1.24", 1.24)]
    ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 170))], spacing: 8) {
            ForEach(moments, id: \.0) { name, t in
                VStack {
                    SunriseCanvas(layout: .intro(page: 1), frame: .frozen(phase: 6),
                                  gigglePose: GiggleMotion.pose(at: t, kind: .small, reduceMotion: false) ?? .rest)
                        .scaleEffect(0.5, anchor: .top).frame(height: 150)
                    Text(name).font(.caption)
                }
            }
        }
        .padding()
    }
    .background(LGColor.background)
}

#Preview("Giggle · big laugh and Reduce Motion") {
    HStack {
        ForEach([(GiggleKind.big, 0.6, false), (.big, 1.5, false), (.small, 0.4, true), (.wink, 0.2, false)], id: \.1) { kind, t, reduce in
            SunriseCanvas(layout: .intro(page: 1), frame: .frozen(phase: 6),
                          gigglePose: GiggleMotion.pose(at: t, kind: kind, reduceMotion: reduce) ?? .rest)
                .scaleEffect(0.3, anchor: .top).frame(width: 100, height: 100)
        }
    }
    .padding()
    .background(LGColor.background)
}

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

extension View {
    /// Adds an adjustable action (swipe up or down) only when `enabled`, so other elements are not announced as adjustable.
    @ViewBuilder
    func lgAdjustable(_ enabled: Bool, _ action: @escaping (AccessibilityAdjustmentDirection) -> Void) -> some View {
        if enabled { accessibilityAdjustableAction(action) } else { self }
    }
}
