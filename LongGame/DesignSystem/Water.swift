import SwiftUI

/// The water under the sun. The navy wave line, the sea fill and the mask that hides the sun are all built from
/// the same wave path (same phase, same offset), so nothing of the sun can ever show below the waterline.
enum WavePath {
    static let wavelength = SunriseMotion.wavelength
    /// The width of one arch, and how far each arch bows up or down. Widgets use narrower arches in a smaller sea.
    static let defaultArch: CGFloat = 20
    static let defaultBow: CGFloat = 7

    /// Adds one wave to `path`, from well left of `minX` to well right of `maxX`, along the line `y`.
    /// Returns the x it starts and ends at, so callers can close the shape the same way.
    @discardableResult
    static func add(to path: inout Path, minX: CGFloat, maxX: CGFloat, y: CGFloat, phase: CGFloat,
                    moveToStart: Bool, arch: CGFloat = defaultArch, bow: CGFloat = defaultBow) -> (start: CGFloat, end: CGFloat) {
        let wavelength = 2 * arch
        var ph = phase.truncatingRemainder(dividingBy: wavelength)
        if ph < 0 { ph += wavelength }
        let start = minX - 2 * wavelength + ph
        var x = start
        if moveToStart { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
        var up = true
        while x < maxX + wavelength {
            path.addQuadCurve(to: CGPoint(x: x + arch, y: y), control: CGPoint(x: x + arch / 2, y: y + (up ? -bow : bow)))
            x += arch
            up.toggle()
        }
        return (start, x)
    }
}

/// A single wave line, to stroke.
struct WaveLine: Shape {
    var y: CGFloat
    var phase: CGFloat
    var arch: CGFloat = WavePath.defaultArch
    var bow: CGFloat = WavePath.defaultBow

    func path(in rect: CGRect) -> Path {
        var p = Path()
        WavePath.add(to: &p, minX: rect.minX, maxX: rect.maxX, y: y, phase: phase, moveToStart: true, arch: arch, bow: bow)
        return p
    }
}

/// The sea: one closed shape whose top edge is exactly the navy wave path. Fill it with a fully opaque colour.
struct SeaFill: Shape {
    var waterY: CGFloat
    var phase: CGFloat
    var arch: CGFloat = WavePath.defaultArch
    var bow: CGFloat = WavePath.defaultBow

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let ends = WavePath.add(to: &p, minX: rect.minX, maxX: rect.maxX, y: waterY, phase: phase, moveToStart: true, arch: arch, bow: bow)
        p.addLine(to: CGPoint(x: ends.end, y: rect.maxY + 4))
        p.addLine(to: CGPoint(x: ends.start, y: rect.maxY + 4))
        p.closeSubpath()
        return p
    }
}

/// Everything above the wave path. Used as the sun's mask: only the part above the water can be seen.
struct AboveWater: Shape {
    var waterY: CGFloat
    var phase: CGFloat
    var arch: CGFloat = WavePath.defaultArch
    var bow: CGFloat = WavePath.defaultBow

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let ends = WavePath.add(to: &p, minX: rect.minX, maxX: rect.maxX, y: waterY, phase: phase, moveToStart: true, arch: arch, bow: bow)
        p.addLine(to: CGPoint(x: ends.end, y: rect.minY - 1_000))
        p.addLine(to: CGPoint(x: ends.start, y: rect.minY - 1_000))
        p.closeSubpath()
        return p
    }
}
