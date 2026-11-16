import SwiftUI

/// Weather in the scene (update 49, `design/redesign/SunMoods.dc.html`): one thin, pale layer drawn between the scene
/// and Home's text, in white and pale tones only. Positions are seeded, so they look natural and never jump. Slow
/// movement; still with Reduce Motion; 70% strength in the dark look. Decorative: the scene's label says the words.
struct WeatherLayerView: View {
    let layer: WeatherLayer
    /// The sun's centre and radius in this view's space, so clouds and mist keep clear of it.
    let sun: CGPoint
    let sunRadius: CGFloat
    /// How far the sun's rays reach from its centre: clouds keep 1.3 × this away (update 52).
    var sunRayRadius: CGFloat? = nil
    /// Where the water starts.
    let horizonY: CGFloat

    /// False while Home is covered (the Timer, Settings): the weather stands still, like the sun.
    var isRunning = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.displayScale) private var displayScale
    private var dark: Bool { colorScheme == .dark }

    /// How often each layer is redrawn. Clouds drift about half a point a second, so twice a second looks the same
    /// as thirty times (and each cloud's soft edge is a blur, the costly part). Mist moves a few points a second.
    /// Rain, wind gusts and snow fall fast and keep 30.
    static func frameInterval(_ layer: WeatherLayer) -> Double {
        switch layer {
        case .cloud: 1.0 / 2
        case .mist: 1.0 / 15
        case .rain, .wind, .snow: 1.0 / 30
        }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: Self.frameInterval(layer),
                                paused: reduceMotion || !isRunning || scenePhase != .active)) { timeline in
            let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            if layer == .cloud {
                GeometryReader { geo in
                    let scene = CGSize(width: geo.size.width, height: horizonY)
                    let seed = Self.cloudSeed(timeline.date)
                    let pictures = CloudPictures.shared.pictures(seed: seed, scene: scene, dark: dark, scale: displayScale)
                    Canvas { context, _ in drawClouds(&context, scene: scene, seed: seed, pictures: pictures, t: t) }
                }
            } else {
                Canvas { context, size in
                    switch layer {
                    case .cloud: break
                    case .rain: drawRain(&context, size: size, t: t)
                    case .wind: drawWind(&context, size: size, t: t)
                    case .mist: drawMist(&context, size: size, t: t)
                    case .snow: drawSnow(&context, size: size, t: t)
                    }
                }
            }
        }
        .opacity(colorScheme == .dark ? 0.7 : 1)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: Cloud

    /// The day's seed. A debug build can step it with `-debug.cloudDayOffset N`, to see other days' skies.
    private static func cloudSeed(_ date: Date) -> UInt32 {
        var day = date
        #if DEBUG
        let offset = UserDefaults.standard.integer(forKey: "debug.cloudDayOffset")
        day = Calendar.current.date(byAdding: .day, value: offset, to: date) ?? date
        #endif
        return CloudSky.seed(for: day)
    }

    /// Far clouds, then near ones, then wisps: each a picture drawn once a day, here only placed and drifted.
    private func drawClouds(_ context: inout GraphicsContext, scene: CGSize, seed: UInt32, pictures: CloudPictures.Set, t: Double) {
        let sky = CloudSky.make(seed: seed, size: scene, sun: sun, rayRadius: sunRayRadius ?? sunRadius * 1.5)
        let pad = CloudPictures.pad
        for cloud in sky.clouds {
            guard let image = pictures.clouds[cloud.index] else { continue }
            let dx = CloudSky.drift(cloud.shape.depth, t: t)
            context.opacity = cloud.shape.depth.opacity
            context.draw(image, in: cloud.frame.offsetBy(dx: dx, dy: 0).insetBy(dx: -pad, dy: -pad))
        }
        context.opacity = 1
        for (k, wisp) in sky.wisps.enumerated() {
            guard let image = pictures.wisps[k] else { continue }
            context.draw(image, in: wisp.frame.insetBy(dx: -pad, dy: -pad))
        }
    }

    // MARK: Rain

    private func drawRain(_ context: inout GraphicsContext, size: CGSize, t: Double) {
        // A 10% cooler scene: a faint navy veil, fading out at the top and below the water so it has no edges.
        let veil = Gradient(stops: [.init(color: LGColor.navy.opacity(0), location: 0),
                                    .init(color: LGColor.navy.opacity(0.1), location: 0.18),
                                    .init(color: LGColor.navy.opacity(0.1), location: horizonY / size.height),
                                    .init(color: LGColor.navy.opacity(0), location: 1)])
        context.fill(Path(CGRect(origin: .zero, size: size)),
                     with: .linearGradient(veil, startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
        var rng = SceneWeather.Seeded(0x4A1)
        for _ in 0..<70 {
            let x0 = rng.next() * Double(size.width + 40), y0 = rng.next() * Double(horizonY)
            let speed = 160 + rng.next() * 60
            let y = (y0 + t * speed).truncatingRemainder(dividingBy: Double(horizonY + 10)) - 10
            let x = x0 - (y - y0) * 0.25
            var line = Path()
            line.move(to: CGPoint(x: x, y: y))
            line.addLine(to: CGPoint(x: x - 3.5, y: y + 14))
            context.stroke(line, with: .color(.white.opacity(0.55)), lineWidth: 1)
        }
        // A few thin rings on the water.
        for i in 0..<5 {
            var r = SceneWeather.Seeded(UInt64(0x51 + i))
            let cx = r.next() * Double(size.width), cy = Double(horizonY) + 8 + r.next() * 30
            let phase = ((t / 2.4) + r.next()).truncatingRemainder(dividingBy: 1)
            let w = 6 + phase * 22
            context.stroke(Path(ellipseIn: CGRect(x: cx - w / 2, y: cy - w / 8, width: w, height: w / 4)),
                           with: .color(.white.opacity(0.6 * (1 - phase))), lineWidth: 0.8)
        }
    }

    // MARK: Wind

    private func drawWind(_ context: inout GraphicsContext, size: CGSize, t: Double) {
        // One long thin cloud, high.
        let drift = CGFloat((t / 400).truncatingRemainder(dividingBy: 1))
        let w = size.width * 0.7
        let rect = CGRect(x: -w * 0.3 + drift * (size.width + w * 0.3) - w * 0.2, y: max(14, min(sun.y - sunRadius - 26, horizonY * 0.14)),
                          width: w, height: 10)
        if !SceneWeather.overlaps(rect, sun: sun, radius: sunRadius * 1.2) {
            context.drawLayer { layer in
                layer.addFilter(.blur(radius: 3))
                layer.fill(Path(ellipseIn: rect), with: .color(dark ? LGColor.moonCloud.opacity(0.38) : .white.opacity(0.6)))
            }
        }
        // A few faint gust lines passing low.
        var rng = SceneWeather.Seeded(0x917)
        for _ in 0..<4 {
            let y = Double(horizonY) - 18 - rng.next() * 40
            let speed = 70 + rng.next() * 40
            let len = 40 + rng.next() * 50
            let x = (rng.next() * Double(size.width) + t * speed).truncatingRemainder(dividingBy: Double(size.width) + len) - len
            var line = Path()
            line.move(to: CGPoint(x: x, y: y))
            line.addQuadCurve(to: CGPoint(x: x + len, y: y), control: CGPoint(x: x + len / 2, y: y - 4))
            context.stroke(line, with: .color(.white.opacity(0.45)), style: StrokeStyle(lineWidth: 1, lineCap: .round))
        }
    }

    // MARK: Mist

    private func drawMist(_ context: inout GraphicsContext, size: CGSize, t: Double) {
        // Densest just above the water, and never up over the sun's face.
        let top = max(horizonY - 70, sun.y + sunRadius * 0.45)
        let veil = CGRect(x: 0, y: top, width: size.width, height: horizonY - top)
        context.fill(Path(veil), with: .linearGradient(Gradient(colors: [.white.opacity(0), .white.opacity(0.5)]),
                                                       startPoint: CGPoint(x: 0, y: veil.minY), endPoint: CGPoint(x: 0, y: horizonY)))
        // Two slow bands.
        for i in 0..<2 {
            let y = horizonY - 16 - CGFloat(i) * 18
            guard y > top else { continue }
            let shift = CGFloat((t / Double(70 + i * 30)).truncatingRemainder(dividingBy: 1)) * size.width
            for k in -1...1 {
                let rect = CGRect(x: shift + CGFloat(k) * size.width - size.width * 0.2, y: y, width: size.width * 0.7, height: 8)
                context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.32)))
            }
        }
    }

    // MARK: Snow

    private func drawSnow(_ context: inout GraphicsContext, size: CGSize, t: Double) {
        var rng = SceneWeather.Seeded(0x5A0)
        let sizes: [CGFloat] = [2, 3, 4, 5.5]
        for i in 0..<60 {
            let d = sizes[i % 4]
            let x0 = rng.next() * Double(size.width), y0 = rng.next() * Double(horizonY)
            let speed = 14 + Double(d) * 4
            let y = (y0 + t * speed).truncatingRemainder(dividingBy: Double(horizonY + 6)) - 6
            let x = x0 + sin(t * 0.6 + rng.next() * 6) * 8
            context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: d, height: d)), with: .color(.white.opacity(0.85)))
        }
    }
}

/// Each cloud and wisp of the day drawn once, blur and all, so the 2-a-second redraw only moves pictures (update 52).
@MainActor
final class CloudPictures {
    static let shared = CloudPictures()
    /// Room around each picture for its soft edge.
    static let pad: CGFloat = 4

    struct Set {
        var clouds: [Int: Image] = [:]
        var wisps: [Int: Image] = [:]
    }

    private struct Key: Equatable { var seed: UInt32; var scene: CGSize; var dark: Bool; var scale: CGFloat }
    private var key: Key?
    private var made = Set()

    func pictures(seed: UInt32, scene: CGSize, dark: Bool, scale: CGFloat) -> Set {
        let key = Key(seed: seed, scene: scene, dark: dark, scale: scale)
        if key == self.key { return made }
        // The shapes don't depend on the sun (it only moves them), so a sky with the sun far away has every one.
        let sky = CloudSky.make(seed: seed, size: scene, sun: CGPoint(x: -10_000, y: -10_000), rayRadius: 0)
        var set = Set()
        for cloud in sky.clouds { set.clouds[cloud.index] = render(cloud.shape, dark: dark, scale: scale) }
        for (k, wisp) in sky.wisps.enumerated() { set.wisps[k] = render(wisp, dark: dark, scale: scale) }
        self.key = key
        made = set
        return set
    }

    private func picture(size: CGSize, scale: CGFloat, _ draw: @escaping (inout GraphicsContext) -> Void) -> Image? {
        let pad = Self.pad
        let view = Canvas { context, _ in
            context.translateBy(x: pad, y: pad)
            draw(&context)
        }
        .frame(width: size.width + pad * 2, height: size.height + pad * 2)
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        guard let image = renderer.cgImage else { return nil }
        return Image(decorative: image, scale: scale)
    }

    private func render(_ shape: CloudShape, dark: Bool, scale: CGFloat) -> Image? {
        picture(size: shape.size, scale: scale) { context in
            let pad = Self.pad, h = shape.size.height, w = shape.size.width
            context.drawLayer { cloud in
                // One shape (the union of the puffs and the base), so overlapping puffs show no seams.
                cloud.drawLayer { soft in
                    soft.addFilter(.blur(radius: shape.depth.blur))
                    let fill: GraphicsContext.Shading = dark
                        ? .color(LGColor.moonCloud)
                        : .linearGradient(LGColor.cloudShading(shape.depth), startPoint: .zero, endPoint: CGPoint(x: 0, y: h))
                    soft.fill(Path(shape.path), with: fill)
                }
                // The bottom 20% fades out; nothing below the box.
                let total = h + pad
                cloud.blendMode = .destinationIn
                cloud.fill(Path(CGRect(x: -pad, y: -pad, width: w + pad * 2, height: h + pad * 2)),
                           with: .linearGradient(Gradient(stops: [
                               .init(color: .white, location: 0),
                               .init(color: .white, location: (pad + h * CloudSky.fadeFrom) / total),
                               .init(color: .white.opacity(CloudSky.fadeTo), location: (pad + h) / total - 0.001),
                               .init(color: .white.opacity(0), location: (pad + h) / total)]),
                               startPoint: CGPoint(x: 0, y: -pad), endPoint: CGPoint(x: 0, y: h)))
            }
        }
    }

    private func render(_ wisp: Wisp, dark: Bool, scale: CGFloat) -> Image? {
        let frame = wisp.frame
        return picture(size: frame.size, scale: scale) { context in
            context.translateBy(x: -frame.minX, y: -frame.minY)
            let colour = dark ? LGColor.moonCloud : .white
            context.addFilter(.blur(radius: Wisp.blur))
            var line = Path()
            line.move(to: wisp.start)
            line.addQuadCurve(to: wisp.end, control: wisp.control)
            context.stroke(line, with: .color(colour.opacity(Wisp.opacity)),
                           style: StrokeStyle(lineWidth: Wisp.lineWidth, lineCap: .round))
            var under = Path()
            under.move(to: wisp.underStart)
            under.addLine(to: wisp.underEnd)
            context.stroke(under, with: .color(colour.opacity(Wisp.underOpacity)),
                           style: StrokeStyle(lineWidth: Wisp.underWidth, lineCap: .round))
        }
    }
}
