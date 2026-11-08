import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

/// Runs the opening sunrise (spec section 21). `AppRoot` owns one of these; the view reads it.
/// Home reports where its sun will be (`sunTarget`, in screen coordinates) so the opening sun can glide into place.
@MainActor @Observable
final class OpeningCenter {
    /// The opening that is playing now, or nil.
    private(set) var running: (plan: OpeningPlan, start: Date)?
    /// Where the sun sits on Today's arc on Home, in screen coordinates.
    var sunTarget: CGRect?
    /// Bumped when the opening is gone, so Home can take VoiceOver focus.
    private(set) var finishedCount = 0

    /// Call once at the first frame. `coldStart` is true only the first time in this process.
    func begin(_ plan: OpeningPlan) {
        guard plan.style != .skip else { return }
        running = (plan, Date())
    }

    private static var coldStartUsed = false

    /// True only the first time in this process: a cold start. Other windows and returns from the background are not.
    static func consumeColdStart() -> Bool {
        defer { coldStartUsed = true }
        return !coldStartUsed
    }

    /// Debug: plays the full opening again without restarting.
    func replay(landing: OpeningLanding = .home) {
        running = (OpeningPlan(style: .full, landing: landing), Date())
    }

    func finish() {
        guard running != nil else { return }
        running = nil
        finishedCount += 1
    }
}

extension Notification.Name {
    /// Posted when the app was opened from a notification: no opening plays.
    static let openingShouldSkip = Notification.Name("openingShouldSkip")
}

/// The few system questions the opening asks.
enum OpeningAccessibility {
    @MainActor static var voiceOverRunning: Bool {
        #if canImport(UIKit)
        UIAccessibility.isVoiceOverRunning
        #else
        NSWorkspace.shared.isVoiceOverEnabled
        #endif
    }

    /// The system's look (the app itself stays light for now), read when the app opens.
    @MainActor static var systemIsDark: Bool {
        #if canImport(UIKit)
        UIScreen.main.traitCollection.userInterfaceStyle == .dark
        #else
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        #endif
    }

    /// After the opening is gone, VoiceOver starts again from the top of the screen (Home's first element).
    @MainActor static func moveFocusToContent() {
        #if canImport(UIKit)
        UIAccessibility.post(notification: .screenChanged, argument: nil)
        #endif
    }
}

/// The night frame, the sunrise and the glide to Home, drawn from the pure timeline in `Logic/OpeningSunrise.swift`.
/// Its first frame is the same picture as the launch screen storyboard (same proportions), so the hand-over can't be seen.
struct OpeningSunriseView: View {
    var plan: OpeningPlan
    var start: Date
    /// Home's sun, in screen coordinates (nil: nothing to glide to, e.g. Welcome).
    var target: CGRect?
    /// A fixed moment, for previews and tests. Nil = live.
    var frozenAt: Double?
    var onTap: () -> Void = {}

    var body: some View {
        if let frozenAt {
            scene(t: frozenAt)
        } else {
            TimelineView(.animation) { context in
                scene(t: context.date.timeIntervalSince(start))
            }
        }
    }

    private func scene(t: Double) -> some View {
        GeometryReader { geo in
            let f = OpeningTimeline.frame(at: t, style: plan.style, hasTarget: target != nil)
            let w = geo.size.width, h = geo.size.height
            let origin = geo.frame(in: .global).origin
            let waterY = h * 0.56
            let sunSize: CGFloat = 170
            let nightCentre = CGPoint(x: w / 2, y: waterY - 23)
            let morningCentre = CGPoint(x: w / 2, y: h * 0.373)
            // The sun's height follows the sky: night spot → morning spot.
            let rise = CGFloat(f.sky)
            let base = CGPoint(x: nightCentre.x + (morningCentre.x - nightCentre.x) * rise,
                               y: nightCentre.y + (morningCentre.y - nightCentre.y) * rise)
            let glide = CGFloat(f.glide)
            let goal = target.map { CGPoint(x: $0.midX - origin.x, y: $0.midY - origin.y) } ?? base
            let goalSize = target?.width ?? sunSize
            let centre = CGPoint(x: base.x + (goal.x - base.x) * glide, y: base.y + (goal.y - base.y) * glide)
            let size = sunSize + (goalSize - sunSize) * glide
            // The waves line up with the launch screen's 1440 pt strip, which is centred on the screen.
            let phase = (w / 2).truncatingRemainder(dividingBy: 2 * WavePath.defaultArch)

            ZStack(alignment: .topLeading) {
                Group {
                    sky(f.sky).frame(width: w, height: h)
                    stars(w: w, h: h).opacity(f.stars)
                    if f.glow > 0 {
                        Circle()
                            .fill(RadialGradient(colors: [LGColor.sunBody.opacity(0.35 * f.glow), LGColor.sunBody.opacity(0)],
                                                 center: .center, startRadius: 0, endRadius: sunSize * 1.7 * 0.44))
                            .frame(width: sunSize * 1.7, height: sunSize * 1.7)
                            .position(centre)
                    }
                }
                .opacity(f.scenery)

                sun(face: f.awake ? .happy : .asleep, rays: f.rays, size: size)
                    .frame(width: size, height: size)
                    .position(centre)
                    // Until the sun wakes, only the part above the water shows; the sea is drawn in front.
                    .mask {
                        if glide > 0 { Color.black } else { AboveWater(waterY: waterY, phase: phase).fill(Color.black) }
                    }
                    .opacity(f.sun)

                sea(f.sky, waterY: waterY, phase: phase, w: w, h: h).opacity(f.scenery)
            }
            .frame(width: w, height: h, alignment: .topLeading)
            .clipped()
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        // The whole opening is decoration: VoiceOver skips it.
        .accessibilityHidden(true)
    }

    private func sun(face: SunFace, rays: Double, size: CGFloat) -> some View {
        SunView(face: face, litRays: 12, raysOpacity: rays, raysScale: rays, unlitOpacity: 0)
    }

    private func color(_ trio: (UInt32, UInt32, UInt32), _ sky: Double) -> Color {
        Color(hex: openingMix(trio.0, trio.1, trio.2, sky: sky))
    }

    private func sky(_ s: Double) -> some View {
        LinearGradient(stops: [
            .init(color: color(LGColor.openingSkyTop, s), location: 0),
            .init(color: color(LGColor.openingSkyMiddle, s), location: 0.55),
            .init(color: color(LGColor.openingSkyBottom, s), location: 1),
        ], startPoint: .top, endPoint: .bottom)
    }

    private func sea(_ s: Double, waterY: CGFloat, phase: CGFloat, w: CGFloat, h: CGFloat) -> some View {
        ZStack {
            SeaFill(waterY: waterY, phase: phase).fill(color(LGColor.openingSeaFill, s))
            WaveLine(y: waterY + 20, phase: phase)
                .stroke(color(LGColor.openingSeaWave, s), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            WaveLine(y: waterY, phase: phase)
                .stroke(color(LGColor.openingSeaLine, s), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
        .frame(width: w, height: h)
    }

    /// The nine stars of the launch screen, in the top half. Positions are fractions of the 390 × 422 design sky.
    private static let starData: [(CGFloat, CGFloat, CGFloat, Double)] = [
        (48, 120, 2, 0.5), (92, 210, 1.5, 0.35), (150, 90, 2, 0.45), (232, 160, 1.5, 0.3), (300, 110, 2, 0.5),
        (340, 240, 1.5, 0.35), (70, 320, 1.5, 0.3), (270, 300, 2, 0.4), (190, 250, 1.5, 0.25),
    ]

    private func stars(w: CGFloat, h: CGFloat) -> some View {
        // The storyboard scales the star picture to fill the top half (scaleAspectFill, centred).
        let boxW = w, boxH = h * 0.5
        let scale = max(boxW / 390, boxH / 422)
        let dx = (boxW - 390 * scale) / 2, dy = (boxH - 422 * scale) / 2
        return Canvas { ctx, _ in
            for (l, t, s, o) in Self.starData {
                let r = CGRect(x: dx + l * scale, y: dy + t * scale, width: s * scale, height: s * scale)
                ctx.fill(Path(ellipseIn: r), with: .color(.white.opacity(o)))
            }
        }
        .frame(width: w, height: h, alignment: .topLeading)
    }
}

#Preview("Night frame") { OpeningSunriseView(plan: .init(style: .full, landing: .home), start: .now, target: nil, frozenAt: 0) }
#Preview("Dusk frame") { OpeningSunriseView(plan: .init(style: .full, landing: .home), start: .now, target: nil, frozenAt: 0.2) }
#Preview("Morning frame") { OpeningSunriseView(plan: .init(style: .full, landing: .home), start: .now, target: nil, frozenAt: 0.6) }
