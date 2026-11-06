// Draws the eleven "10,000 ring" app icons (see docs/SPEC.md, "App icon") from the same sun geometry as SunView
// (200 × 200 space), and writes the asset sets with their Dark and Tinted versions.
// Run from the project folder:
//   swift Tools/MakeIcon.swift LongGame/Resources/Assets.xcassets
// The stages and numbers match Logic/IconStage.swift.
import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let root = CommandLine.arguments.dropFirst().first ?? "LongGame/Resources/Assets.xcassets"

enum Look { case normal, tinted }

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

let space = CGColorSpace(name: CGColorSpace.sRGB)!

/// "10,000" or "1,000" with a thousands comma.
func grouped(_ n: Int) -> String {
    n >= 1000 ? "\(n / 1000),\(String(format: "%03d", n % 1000))" : "\(n)"
}

/// The one drawing function: the icon for a total of `hours` (0 = the start icon), in a normal or tinted look.
/// `hours` should be 0 or a multiple of 1000 up to 10000.
func drawIcon(hours: Int, look: Look = .normal) -> CGImage {
    let tinted = look == .tinted
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    // y-down drawing space, like the SVG
    ctx.translateBy(x: 0, y: CGFloat(size))
    ctx.scaleBy(x: 1, y: -1)

    let ink = tinted ? color(0x000000) : color(0x16244A)
    let gold = tinted ? color(0xFFFFFF) : color(0xFFD15C)
    let body = tinted ? color(0xFFFFFF) : color(0xFFC93C)
    let cheeks = tinted ? color(0xCCCCCC) : color(0xF7A1B5)
    let track = color(0xFFFFFF, tinted ? 0.20 : 0.14)

    // Background: a flat square. iOS adds the rounded mask.
    ctx.setFillColor(ink)
    ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))

    // Track
    let c = CGPoint(x: 512, y: 512), radius: CGFloat = 360, stroke: CGFloat = 56
    ctx.setLineWidth(stroke)
    ctx.setStrokeColor(track)
    ctx.strokeEllipse(in: CGRect(x: c.x - radius, y: c.y - radius, width: radius * 2, height: radius * 2))

    // Arc: from 12 o'clock, clockwise (y is down, so clockwise is increasing angle)
    let fill = CGFloat(hours) / 10_000
    let startAngle = -CGFloat.pi / 2
    let endAngle = startAngle + 2 * .pi * fill
    if fill > 0 {
        ctx.setStrokeColor(gold)
        ctx.setLineCap(.round)
        if fill >= 1 {
            ctx.strokeEllipse(in: CGRect(x: c.x - radius, y: c.y - radius, width: radius * 2, height: radius * 2))
        } else {
            ctx.addArc(center: c, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
            ctx.strokePath()
        }
    }

    // Sun: at the tip of the arc; at 12 o'clock for the start icon and for 10,000.
    let celebrate = hours >= 10_000
    let k: CGFloat = celebrate ? 1.3 : 1.1
    let haloRadius: CGFloat = celebrate ? 132 : 112
    let sunAngle = (fill == 0 || fill >= 1) ? startAngle : endAngle
    let sun = CGPoint(x: c.x + radius * cos(sunAngle), y: c.y + radius * sin(sunAngle))
    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: sun.x + (x - 100) * k, y: sun.y + (y - 100) * k) }

    ctx.setFillColor(ink)
    ctx.fillEllipse(in: CGRect(x: sun.x - haloRadius, y: sun.y - haloRadius, width: haloRadius * 2, height: haloRadius * 2))

    ctx.setStrokeColor(gold)
    ctx.setLineWidth(9 * k)
    ctx.setLineCap(.round)
    for i in 0..<12 {
        let a = (CGFloat(i) * 30 - 90) * .pi / 180
        let outer: CGFloat = i % 2 == 1 ? 92 : 82
        ctx.move(to: p(100 + 66 * cos(a), 100 + 66 * sin(a)))
        ctx.addLine(to: p(100 + outer * cos(a), 100 + outer * sin(a)))
        ctx.strokePath()
    }
    ctx.setFillColor(body)
    ctx.fillEllipse(in: CGRect(x: p(44, 44).x, y: p(44, 44).y, width: 112 * k, height: 112 * k))
    ctx.setFillColor(cheeks)
    for x in [72.0, 128.0] {
        ctx.fillEllipse(in: CGRect(x: p(CGFloat(x) - 7, 106).x, y: p(CGFloat(x) - 7, 106).y, width: 14 * k, height: 14 * k))
    }

    ctx.setStrokeColor(ink)
    ctx.setLineCap(.round)
    func quad(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ bend: CGFloat, _ width: CGFloat) {
        ctx.setLineWidth(width * k)
        ctx.move(to: p(x, y))
        ctx.addQuadCurve(to: p(x + w, y), control: p(x + w / 2, y + bend))
        ctx.strokePath()
    }
    if celebrate {
        // Celebrate face: dot eyes (stroke 10) and the smile M84 110 q16 18 32 0
        ctx.setLineWidth(10 * k)
        for x in [84.0, 116.0] {
            ctx.move(to: p(CGFloat(x), 96)); ctx.addLine(to: p(CGFloat(x), 96)); ctx.strokePath()
        }
        quad(84, 110, 32, 18, 10)   // q16 18 32 0: the control point sits 18 below the start
    } else {
        // Happy face
        quad(76, 98, 16, -9, 4.5)
        quad(108, 98, 16, -9, 4.5)
        quad(88, 114, 24, 11, 4.5)
    }

    // Number: SF Pro Bold 176, tracking −6, white, as outlines, centred both ways.
    let number = grouped(hours == 0 ? 10_000 : hours)
    let font = CTFontCreateUIFontForLanguage(.emphasizedSystem, 176, nil)!
    var glyphPaths: [(CGPath, CGFloat)] = []
    var x: CGFloat = 0
    for ch in number.utf16 {
        var unit = ch
        var glyph = CGGlyph()
        CTFontGetGlyphsForCharacters(font, &unit, &glyph, 1)
        var advance = CGSize.zero
        CTFontGetAdvancesForGlyphs(font, .horizontal, &glyph, &advance, 1)
        if let path = CTFontCreatePathForGlyph(font, glyph, nil) { glyphPaths.append((path, x)) }
        x += advance.width - 6
    }
    let outline = CGMutablePath()
    for (path, dx) in glyphPaths {
        // font paths are y-up; the context is y-down, so flip each glyph
        outline.addPath(path, transform: CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: dx, ty: 0))
    }
    let box = outline.boundingBoxOfPath
    var move = CGAffineTransform(translationX: c.x - box.midX, y: c.y - box.midY)
    ctx.setFillColor(color(0xFFFFFF))
    ctx.addPath(outline.copy(using: &move)!)
    ctx.fillPath()

    return ctx.makeImage()!
}

func write(_ image: CGImage, to path: String) {
    let url = URL(fileURLWithPath: path)
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
}

let stages: [(name: String, hours: Int)] = [("AppIcon", 0)] + (1...10).map { ("AppIcon-\($0 * 1000)", $0 * 1000) }

let contents = """
{
  "images" : [
    { "filename" : "ICON.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" },
    { "appearances" : [ { "appearance" : "luminosity", "value" : "dark" } ],
      "filename" : "ICON.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" },
    { "appearances" : [ { "appearance" : "luminosity", "value" : "tinted" } ],
      "filename" : "ICON-tinted.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
"""

for stage in stages {
    let dir = "\(root)/\(stage.name).appiconset"
    try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    write(drawIcon(hours: stage.hours), to: "\(dir)/\(stage.name).png")
    write(drawIcon(hours: stage.hours, look: .tinted), to: "\(dir)/\(stage.name)-tinted.png")
    try? contents.replacingOccurrences(of: "ICON", with: stage.name)
        .write(toFile: "\(dir)/Contents.json", atomically: true, encoding: .utf8)
    print("Wrote \(dir)")
}
