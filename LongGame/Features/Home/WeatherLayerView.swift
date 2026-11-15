import SwiftUI

/// Weather in the scene (update 49, `design/redesign/SunMoods.dc.html`): one thin, pale layer drawn between the scene
/// and Home's text, in white and pale tones only. Positions are seeded, so they look natural and never jump. Slow
/// movement; still with Reduce Motion; 70% strength in the dark look. Decorative: the scene's label says the words.
struct WeatherLayerView: View {
    let layer: WeatherLayer
    /// The sun's centre and radius in this view's space, so clouds and mist keep clear of it.
    let sun: CGPoint
    let sunRadius: CGFloat
    /// Where the water starts.
    let horizonY: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    private var dark: Bool { colorScheme == .dark }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { timeline in
            let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                switch layer {
                case .cloud: drawClouds(&context, size: size, t: t)
                case .rain: drawRain(&context, size: size, t: t)
                case .wind: drawWind(&context, size: size, t: t)
                case .mist: drawMist(&context, size: size, t: t)
                case .snow: drawSnow(&context, size: size, t: t)
                }
            }
        }
        .opacity(colorScheme == .dark ? 0.7 : 1)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: Cloud

    private func cloudShape(_ rect: CGRect) -> Path {
        var p = Path()
        p.addEllipse(in: CGRect(x: rect.minX, y: rect.minY + rect.height * 0.35, width: rect.width, height: rect.height * 0.65))
        p.addEllipse(in: CGRect(x: rect.minX + rect.width * 0.18, y: rect.minY + rect.height * 0.05, width: rect.width * 0.42, height: rect.height * 0.8))
        p.addEllipse(in: CGRect(x: rect.minX + rect.width * 0.45, y: rect.minY, width: rect.width * 0.36, height: rect.height * 0.75))
        return p
    }

    private func drawClouds(_ context: inout GraphicsContext, size: CGSize, t: Double) {
        let drift = (t / 900).truncatingRemainder(dividingBy: 1)
        for rect in SceneWeather.clouds(in: CGSize(width: size.width, height: horizonY), sun: sun, sunRadius: sunRadius, drift: drift) {
            // Soft edges; in the dark look a moonlit pale blue, thinner, so they never read as grey blobs.
            context.drawLayer { layer in
                layer.addFilter(.blur(radius: 2.5))
                layer.fill(cloudShape(rect), with: .color(dark ? LGColor.moonCloud.opacity(0.42) : .white.opacity(0.72)))
            }
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
