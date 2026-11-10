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
    /// The system fades its launch picture out as the app's first frame arrives. The clock starts a moment later, so
    /// that hand-over happens on the still night frame (the same sun in the same place) and never on a sun that has
    /// already begun to rise.
    static let lead: TimeInterval = 0.4

    func begin(_ plan: OpeningPlan) {
        guard plan.style != .skip else { return }
        running = (plan, Date().addingTimeInterval(Self.lead))
    }

    private static var coldStartUsed = false

    /// True only the first time in this process: a cold start. Other windows and returns from the background are not.
    static func consumeColdStart() -> Bool {
        defer { coldStartUsed = true }
        return !coldStartUsed
    }

    /// Debug: plays the full opening again without restarting.
    func replay(landing: OpeningLanding = .home) {
        running = (OpeningPlan(style: .full, landing: landing), Date().addingTimeInterval(Self.lead))
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
            // The same proportions as the launch screen storyboard: the horizon at 60% of the height, the land box
            // 120 high in a 390-wide design (scaled with the width) with its shoreline 46 down from its top.
            let waterY = h * 0.6
            let k = w / 390
            let landTop = waterY - 46 * k
            let landHeight = 120 * k
            let sunSize: CGFloat = 150
            // Launch.dc.html: the sun's centre sits exactly on the shoreline, so only its top half shows.
            let nightCentre = CGPoint(x: w / 2, y: waterY)
            let morningCentre = CGPoint(x: w / 2, y: waterY - h * (120.0 / 844))
            // The sun rises with the sky: night spot → dawn spot.
            let rise = CGFloat(f.sky)
            let base = CGPoint(x: nightCentre.x + (morningCentre.x - nightCentre.x) * rise,
                               y: nightCentre.y + (morningCentre.y - nightCentre.y) * rise)
            let glide = CGFloat(f.glide)
            let goal = target.map { CGPoint(x: $0.midX - origin.x, y: $0.midY - origin.y) } ?? base
            let goalSize = target?.width ?? sunSize
            let centre = CGPoint(x: base.x + (goal.x - base.x) * glide, y: base.y + (goal.y - base.y) * glide)
            let size = sunSize + (goalSize - sunSize) * glide
            let night = 1 - f.sky

            ZStack(alignment: .topLeading) {
                // Sky: dawn underneath (always opaque), the night sky on top fading out. No animated parts.
                ZStack {
                    SkyView(tone: .dawn, horizon: 1).frame(width: w, height: waterY)
                    SkyView(tone: .night, horizon: 1).frame(width: w, height: waterY).opacity(night)
                }
                .frame(width: w, height: waterY)
                .frame(width: w, height: h, alignment: .top)

                // The sun's soft gold halo (Sun.dc.html: radius 130 of 200, 32% at the centre, gone by 62%).
                let haloRadius = 130 * size / 200
                RadialGradient(stops: [.init(color: LGColor.sunBody.opacity(0.32), location: 0),
                                       .init(color: LGColor.sunBody.opacity(0), location: 0.62)],
                               center: .center, startRadius: 0, endRadius: haloRadius)
                    .frame(width: 2 * haloRadius, height: 2 * haloRadius)
                    .position(centre)
                    .opacity(f.sun * f.scenery)
                // Asleep, every ray is drawn faintly (22%, as on the board); they light up as the sun rises.
                SunView(idle: false, face: f.awake ? .happy : .asleep, litRays: 0,
                        unlitOpacity: 0.22 + 0.78 * f.rays, eyesOpen: f.eyesOpen ? 1 : 0)
                    .frame(width: size, height: size)
                    .position(centre)
                    .opacity(f.sun)

                // The sea is always in front of the sun and always opaque: the day land lies underneath and the
                // night land fades on top of it, never the other way round.
                ZStack(alignment: .topLeading) {
                    LGColor.background.frame(width: w, height: max(0, h - (landTop + landHeight)))
                        .offset(y: landTop + landHeight)
                    LandView(tone: .day, still: true).frame(width: w, height: landHeight).offset(y: landTop)
                    ZStack(alignment: .topLeading) {
                        LGColor.night.frame(width: w, height: max(0, h - (landTop + landHeight)))
                            .offset(y: landTop + landHeight)
                        LandView(tone: .night, still: true).frame(width: w, height: landHeight).offset(y: landTop)
                    }
                    .opacity(night)
                }
                .frame(width: w, height: h, alignment: .topLeading)
            }
            .frame(width: w, height: h, alignment: .topLeading)
            .opacity(f.scenery)
            .clipped()
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        // The whole opening is decoration: VoiceOver skips it.
        .accessibilityHidden(true)
    }
}

#Preview("Night frame") { OpeningSunriseView(plan: .init(style: .full, landing: .home), start: .now, target: nil, frozenAt: 0) }
#Preview("Dusk frame") { OpeningSunriseView(plan: .init(style: .full, landing: .home), start: .now, target: nil, frozenAt: 0.25) }
#Preview("Morning frame") { OpeningSunriseView(plan: .init(style: .full, landing: .home), start: .now, target: nil, frozenAt: 0.55) }
