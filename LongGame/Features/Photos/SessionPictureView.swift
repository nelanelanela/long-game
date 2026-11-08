import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

// The session picture (update prompt 32, part 8), drawn in a SwiftUI Canvas from `SessionPictureLayout`.

/// The picture itself, in a 240 × 240 design space scaled to whatever size it is given.
struct SessionPictureCanvas: View {
    let layout: SessionPictureLayout

    var body: some View {
        Canvas { ctx, size in
            ctx.scaleBy(x: size.width / 240, y: size.height / 240)
            let p = layout.palette
            func colour(_ hex: UInt32, _ opacity: Double = 1) -> Color { Color(hex: hex, opacity: opacity) }
            func path(_ points: [CGPoint], closed: Bool) -> Path {
                var path = Path()
                guard let first = points.first else { return path }
                path.move(to: first)
                points.dropFirst().forEach { path.addLine(to: $0) }
                if closed {
                    path.addLine(to: CGPoint(x: 250, y: 240))
                    path.addLine(to: CGPoint(x: -10, y: 240))
                    path.closeSubpath()
                }
                return path
            }

            // Sky
            ctx.fill(Path(CGRect(x: 0, y: 0, width: 240, height: 240)),
                     with: .linearGradient(Gradient(colors: [colour(p.sky1), colour(p.sky2)]),
                                           startPoint: .zero, endPoint: CGPoint(x: 0, y: 240)))
            // Stars
            if p.stars > 0 {
                var stars = Path()
                for s in layout.stars {
                    stars.addEllipse(in: CGRect(x: s.x - s.r, y: s.y - s.r, width: 2 * s.r, height: 2 * s.r))
                }
                ctx.fill(stars, with: .color(colour(0xFFF4D6, p.stars)))
            }
            // Glow, then the sun
            let r = layout.sunRadius
            let centre = CGPoint(x: layout.sunX, y: layout.sunY)
            let glowR = r * 2.6
            ctx.fill(Path(ellipseIn: CGRect(x: centre.x - glowR, y: centre.y - glowR, width: 2 * glowR, height: 2 * glowR)),
                     with: .radialGradient(Gradient(colors: [colour(p.sun1, p.glow), colour(p.sun1, 0)]),
                                           center: centre, startRadius: 0, endRadius: glowR))
            ctx.fill(Path(ellipseIn: CGRect(x: centre.x - r, y: centre.y - r, width: 2 * r, height: 2 * r)),
                     with: .radialGradient(Gradient(colors: [colour(p.sun1), colour(p.sun2)]),
                                           center: CGPoint(x: centre.x - r + 2 * r * 0.4, y: centre.y - r + 2 * r * 0.35),
                                           startRadius: 0, endRadius: 2 * r * 0.7))
            // Dunes
            ctx.fill(path(layout.backDune, closed: true), with: .color(colour(p.back)))
            let frontTop = layout.frontDune.map(\.y).min() ?? 160
            ctx.fill(path(layout.frontDune, closed: true),
                     with: .linearGradient(Gradient(colors: [colour(p.dune1), colour(p.dune2)]),
                                           startPoint: CGPoint(x: 0, y: frontTop), endPoint: CGPoint(x: 0, y: 240)))
            // Flowing lines: a soft glow under a fine crisp line
            var lines = Path()
            for line in layout.lines { lines.addPath(path(line, closed: false)) }
            if p.glowLineOpacity > 0 {
                ctx.drawLayer { layer in
                    layer.addFilter(.blur(radius: 1.6))
                    layer.stroke(lines, with: .color(colour(p.line, p.glowLineOpacity)), lineWidth: 2.2)
                }
            }
            ctx.stroke(lines, with: .color(colour(p.line, p.lineOpacity)), style: StrokeStyle(lineWidth: 0.8, lineCap: .round))
        }
        .accessibilityHidden(true)
    }
}

/// What the picture says to VoiceOver: "Session picture, morning, 40 minutes".
enum SessionPictureText {
    static func spoken(start: Date, durationSec: Double, calendar: Calendar = .current) -> String {
        let hour = Double(SessionPictureSeed.startMinute(of: start, calendar: calendar)) / 60
        let part = SessionDaypart.at(startHour: hour).word
        let length = Labels.spoken(seconds: max(60, Int(durationSec / 60) * 60), includeSeconds: false)
        return String(localized: "Session picture, \(part), \(length)")
    }
}

/// The small square picture for a session without a photo. It is drawn from the session, kept as a small image in the
/// Caches folder so scrolling stays smooth, and drawn again whenever that file is missing.
struct SessionPictureThumb: View {
    let id: UUID
    let start: Date
    let durationSec: Double
    /// Where today's sunrise stood when the session ended.
    let progress: Double
    var side: CGFloat = 40
    var radius: CGFloat = 10

    @Environment(\.displayScale) private var scale
    @State private var cached: PlatformImage?

    private var minutes: Int { max(1, Int((durationSec / 60).rounded())) }
    private var startMinute: Int { SessionPictureSeed.startMinute(of: start) }
    private var layout: SessionPictureLayout {
        SessionPictureLayout.make(seed: SessionPictureSeed.make(id: id, startMinute: startMinute, minutes: minutes),
                                  startMinute: startMinute, minutes: minutes, progress: progress)
    }
    private var key: SessionPictureCache.Key {
        SessionPictureCache.Key(seed: SessionPictureSeed.make(id: id, startMinute: startMinute, minutes: minutes),
                                startMinute: startMinute, minutes: minutes, progress: progress, pixels: Int((side * scale).rounded()))
    }

    var body: some View {
        Group {
            if let image = cached ?? SessionPictureCache.memory(key) {
                Image(platformImage: image).resizable().interpolation(.high).scaledToFill()
            } else {
                SessionPictureCanvas(layout: layout)
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(SessionPictureText.spoken(start: start, durationSec: durationSec))
        .accessibilityAddTraits(.isImage)
        .accessibilityIgnoresInvertColors()
        .task(id: key) { cached = await SessionPictureCache.image(for: key, layout: layout, side: side, scale: scale) }
    }
}

/// Keeps the session pictures' progress numbers filled in: for existing sessions (the migration) and for entries made
/// by hand or after a break, from the day's order of sessions.
@MainActor
enum SessionPictures {
    static func fillMissing(sessions: [Session], settings: AppSettings?, periods: [TargetPeriod], context: ModelContext,
                            calendar: Calendar = .current) {
        let missing = sessions.filter { $0.sunriseProgressAtEnd == nil }
        guard !missing.isEmpty else { return }
        var days: [Date: [Session]] = [:]
        for s in sessions { days[calendar.startOfDay(for: s.start), default: []].append(s) }
        for session in missing {
            let day = days[calendar.startOfDay(for: session.start)] ?? [session]
            let entries = day.map { SessionSunrise.Entry(id: $0.id, start: $0.start, durationSec: $0.durationSec) }
            let target = StretchSource.plan(sessions: [], settings: settings, periods: periods, now: session.start,
                                            calendar: calendar).target
            session.sunriseProgressAtEnd = SessionSunrise.progressAtEnd(of: session.id, among: entries, target: target)
        }
        try? context.save()
    }
}
