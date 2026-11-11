// Draws the three pictures the launch screen uses: the night sky (with stars and moon) and the sleeping sun as 2x/3x bitmaps, and the night land and sea as a vector PDF.
// Run from the project folder:  swift Tools/MakeLaunchAssets.swift
// Shapes and colours come from design/redesign/Sky.dc.html, Land.dc.html and Launch.dc.html (same numbers as SkyView and LandView). Y runs downward here, like the design.
import CoreGraphics
import ImageIO
import Foundation

let outDir = "LongGame/Resources/Assets.xcassets"

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    // Explicitly sRGB, so the PDF keeps the exact hex values (a plain RGB colour would be shifted by the viewer).
    CGColor(colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
            components: [CGFloat((hex >> 16) & 255) / 255, CGFloat((hex >> 8) & 255) / 255, CGFloat(hex & 255) / 255, a])!
}

func makePDF(_ path: String, width: CGFloat, height: CGFloat, draw: (CGContext) -> Void) {
    var box = CGRect(x: 0, y: 0, width: width, height: height)
    guard let ctx = CGContext(URL(fileURLWithPath: path) as CFURL, mediaBox: &box, nil) else { fatalError("Cannot write \(path)") }
    ctx.beginPDFPage(nil)
    ctx.translateBy(x: 0, y: height)
    ctx.scaleBy(x: 1, y: -1)
    draw(ctx)
    ctx.endPDFPage()
    ctx.closePDF()
    print("wrote", path)
}

func dir(_ name: String) -> String {
    let p = "\(outDir)/\(name).imageset"
    try? FileManager.default.createDirectory(atPath: p, withIntermediateDirectories: true)
    return p
}

// The night sky: 402 x 524.4, everything above the horizon (the horizon is the bottom edge, 60% of an 874 pt screen).
// Drawn for a 402 x 874 phone (iPhone 17, iPhone 18 Pro), so on those the still picture is exactly the opening
// sunrise's first frame, stars included (each sky size has its own stars). Other phones stretch it to fit.
// It is a bitmap at 2x and 3x, not a PDF: the glow is a transparent gradient, and a PDF would flatten or band it
// (stacked translucent circles came out olive green on the phone). One real gradient in one pass stays warm.
let skyW: CGFloat = 402, screenH: CGFloat = 874, skyH: CGFloat = screenH * 0.6
func linear(_ c: CGContext, _ stops: [(CGFloat, UInt32)], from: CGPoint, to: CGPoint) {
    let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!, colors: stops.map { rgb($0.1) } as CFArray,
                       locations: stops.map { $0.0 })!
    c.drawLinearGradient(g, start: from, end: to, options: [])
}

func makePNG(_ path: String, width: CGFloat, height: CGFloat, scale: CGFloat, draw: (CGContext) -> Void) {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let w = Int(width * scale), h = Int(height * scale)
    guard let c = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { fatalError("Cannot draw \(path)") }
    c.translateBy(x: 0, y: CGFloat(h))
    c.scaleBy(x: scale, y: -scale)
    draw(c)
    guard let image = c.makeImage(),
          let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, "public.png" as CFString, 1, nil) else { fatalError("Cannot write \(path)") }
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
    print("wrote", path)
}

func drawNightSky(_ c: CGContext) {
    // Stops as in Sky.dc.html, which places them on the whole screen (horizon p = 60%): 0, 0.55p, 0.85p, p − 3%, p.
    linear(c, [(0, 0x060A1E), (0.55, 0x0F1A3D), (0.85, 0x22305C), ((0.6 - 0.03) / 0.6, 0x6B5A5E), (1, 0xC8915A)],
           from: .zero, to: CGPoint(x: 0, y: skyH))
    // The warm glow rising from the horizon (the CSS gradient ends at 0.62 of the farthest corner).
    // Launch.dc.html draws the sky over the whole screen, so the glow is sized from the screen's height.
    let glowSize = max(skyW, screenH) * 1.1
    let glowRadius = 0.62 * glowSize / 2 * 2.0.squareRoot()
    let glow = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                          colors: [rgb(0xF2A07A, 0.55), rgb(0xF2A07A, 0.22), rgb(0xF2A07A, 0)] as CFArray,
                          locations: [0, 0.30 / 0.62, 1])!
    c.drawRadialGradient(glow, startCenter: CGPoint(x: skyW / 2, y: skyH), startRadius: 0,
                         endCenter: CGPoint(x: skyW / 2, y: skyH), endRadius: glowRadius, options: [])
    // Stars: the same natural star field SkyView draws for the opening sunrise's first frame, a full 402 x 874
    // screen with the horizon at 60% (all of them sit above 0.9 of the horizon, so inside this bitmap).
    for s in launchStars(width: skyW, height: screenH, horizon: 0.6) {
        c.setFillColor(rgb(s.warm ? 0xFFF4D6 : 0xFFFFFF, s.opacity))
        c.fillEllipse(in: CGRect(x: s.x - s.r, y: s.y - s.r, width: 2 * s.r, height: 2 * s.r))
    }
    // The crescent moon: Sky.dc.html's own SVG path, at (0.74, 0.12) of the whole 874 pt screen (not of this
    // 524 pt sky), lit along its lower right. The same shape as SkyMoon in Scene.swift.
    c.addPath(moonPath(centre: CGPoint(x: skyW * 0.74, y: screenH * 0.12)))
    c.setFillColor(rgb(0xF4E9D2, 0.9))
    c.fillPath()
}

/// A copy of StarField.stars (LongGame/Logic/StarField.swift, from Sky.dc.html), so this script runs on its own.
/// Keep the two the same: seeded by the size, mulberry32, a Milky Way band, thinning towards the horizon.
func launchStars(width w: Double, height h: Double, horizon: Double) -> [(x: Double, y: Double, r: Double, opacity: Double, warm: Bool)] {
    func jsRound(_ v: Double) -> Double { (v + 0.5).rounded(.down) }
    var a = UInt32(truncatingIfNeeded: Int64(jsRound(w)) &* 73_856_093) ^ UInt32(truncatingIfNeeded: Int64(jsRound(h)) &* 19_349_663)
    func rnd() -> Double {
        a = a &+ 0x6D2B79F5
        var t = a
        t = (t ^ (t >> 15)) &* (t | 1)
        t ^= t &+ ((t ^ (t >> 7)) &* (t | 61))
        return Double(t ^ (t >> 14)) / 4_294_967_296
    }
    func gauss() -> Double { let p = rnd(), q = rnd(), r = rnd(); return (p + q + r - 1.5) / 1.5 }
    let top = h * horizon * 0.9
    let n = Int(min(170, max(14, jsRound(w * top / 1500))))
    let spread = min(w, top) * 0.1
    let radii = [0.45, 0.65, 0.9, 1.3], opacities = [0.45, 0.7, 0.9, 1.0]
    var out: [(x: Double, y: Double, r: Double, opacity: Double, warm: Bool)] = []
    var tries = 0
    while out.count < n && tries < n * 6 {
        tries += 1
        var x: Double, y: Double
        if rnd() < 0.32 {
            let t = rnd()
            x = w * (0.08 + 0.9 * t) + gauss() * spread
            y = top * (0.02 + 0.95 * t) + gauss() * spread
        } else {
            x = rnd() * w
            y = rnd() * top
        }
        if x < 0 || x > w || y < 0 || y > top { continue }
        if rnd() < (y / top) * (y / top) * 0.7 { continue }
        let u = rnd()
        let k = u < 0.62 ? 0 : u < 0.88 ? 1 : u < 0.97 ? 2 : 3
        let r = radii[k] * (0.85 + rnd() * 0.3)
        out.append((x, y, r, opacities[k], k == 3))
    }
    return out
}

/// `M x+0.6r y-0.8r  A r r 0 1 1 x-r y+0.2r  A 0.95r 0.95r 0 0 0 x+0.6r y-0.8r Z`, r = 14.
func moonPath(centre c: CGPoint, radius r: CGFloat = 14) -> CGPath {
    func arc(_ p: CGMutablePath, _ a: CGPoint, _ b: CGPoint, _ radius: CGFloat, large: Bool, sweep: Bool) {
        let hx = (a.x - b.x) / 2, hy = (a.y - b.y) / 2
        let d2 = hx * hx + hy * hy
        let r = max(radius, d2.squareRoot())
        let k = (large != sweep ? 1 : -1) * max(0, (r * r - d2) / d2).squareRoot()
        let o = CGPoint(x: k * hy + (a.x + b.x) / 2, y: -k * hx + (a.y + b.y) / 2)
        p.addArc(center: o, radius: r, startAngle: atan2(a.y - o.y, a.x - o.x), endAngle: atan2(b.y - o.y, b.x - o.x),
                 clockwise: !sweep)
    }
    let p = CGMutablePath()
    let a = CGPoint(x: c.x + 0.6 * r, y: c.y - 0.8 * r), b = CGPoint(x: c.x - r, y: c.y + 0.2 * r)
    p.move(to: a)
    arc(p, a, b, r, large: true, sweep: true)
    arc(p, b, a, 0.95 * r, large: false, sweep: false)
    p.closeSubpath()
    return p
}

let skyDir = dir("LaunchNightSky")
try? FileManager.default.removeItem(atPath: "\(skyDir)/LaunchNightSky.pdf")
makePNG("\(skyDir)/LaunchNightSky@2x.png", width: skyW, height: skyH, scale: 2, draw: drawNightSky)
makePNG("\(skyDir)/LaunchNightSky@3x.png", width: skyW, height: skyH, scale: 3, draw: drawNightSky)
try? """
{
  "images" : [
    { "filename" : "LaunchNightSky@2x.png", "idiom" : "universal", "scale" : "2x" },
    { "filename" : "LaunchNightSky@3x.png", "idiom" : "universal", "scale" : "3x" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
""".write(toFile: "\(skyDir)/Contents.json", atomically: true, encoding: .utf8)

// The sleeping sun, as Launch.dc.html draws it (Sun.dc.html, face "sleepy", lit 0): 200 x 200 box, a soft gold halo,
// all 12 rays faint (22%), body radius 56, cheeks, low closed eyes, a small mouth and a blue-grey "z".
// A bitmap at 2x and 3x, like the sky, because the halo is a translucent gradient.
func drawSun(_ c: CGContext) {
    let halo = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                          colors: [rgb(0xFFC93C, 0.32), rgb(0xFFC93C, 0)] as CFArray, locations: [0, 1])!
    c.drawRadialGradient(halo, startCenter: CGPoint(x: 100, y: 100), startRadius: 0,
                         endCenter: CGPoint(x: 100, y: 100), endRadius: 130 * 0.62, options: [])
    c.setLineCap(.round)
    c.setStrokeColor(rgb(0xFFB627, 0.22))
    c.setLineWidth(9)
    for i in 0..<12 {
        let a = CGFloat(i * 30 - 90) * .pi / 180
        let r2: CGFloat = i % 2 == 0 ? 92 : 82
        c.move(to: CGPoint(x: 100 + 66 * cos(a), y: 100 + 66 * sin(a)))
        c.addLine(to: CGPoint(x: 100 + r2 * cos(a), y: 100 + r2 * sin(a)))
        c.strokePath()
    }
    c.setFillColor(rgb(0xFFC93C))
    c.fillEllipse(in: CGRect(x: 44, y: 44, width: 112, height: 112))
    c.setFillColor(rgb(0xF7A1B5))
    c.fillEllipse(in: CGRect(x: 65, y: 106, width: 14, height: 14))
    c.fillEllipse(in: CGRect(x: 121, y: 106, width: 14, height: 14))
    c.setStrokeColor(rgb(0x16244A))
    c.setLineWidth(4.5)
    // M77 101q7 4 14 0, M109 101q7 4 14 0, M95 118q5 2 10 0
    for (x, y, dx, dy, w) in [(77, 101, 7, 4, 14), (109, 101, 7, 4, 14), (95, 118, 5, 2, 10)] as [(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)] {
        c.move(to: CGPoint(x: x, y: y))
        c.addQuadCurve(to: CGPoint(x: x + w, y: y), control: CGPoint(x: x + dx, y: y + dy))
        c.strokePath()
    }
    // The "z" (22 pt semibold at baseline 150, 54), drawn as its three strokes.
    c.setStrokeColor(rgb(0x8FA2E0))
    c.setLineWidth(2.6)
    c.setLineJoin(.round)
    c.move(to: CGPoint(x: 151, y: 42.5)); c.addLine(to: CGPoint(x: 160.5, y: 42.5))
    c.addLine(to: CGPoint(x: 151, y: 53)); c.addLine(to: CGPoint(x: 161, y: 53))
    c.strokePath()
}
let sunDir = dir("LaunchSun")
try? FileManager.default.removeItem(atPath: "\(sunDir)/LaunchSun.pdf")
makePNG("\(sunDir)/LaunchSun@2x.png", width: 200, height: 200, scale: 2, draw: drawSun)
makePNG("\(sunDir)/LaunchSun@3x.png", width: 200, height: 200, scale: 3, draw: drawSun)
try? """
{
  "images" : [
    { "filename" : "LaunchSun@2x.png", "idiom" : "universal", "scale" : "2x" },
    { "filename" : "LaunchSun@3x.png", "idiom" : "universal", "scale" : "3x" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
""".write(toFile: "\(sunDir)/Contents.json", atomically: true, encoding: .utf8)

// The night land and sea: Land.dc.html's 390 x 120 box (the shoreline is at y = 46 on the left edge).
func curve(_ c: CGContext, y: CGFloat, c1: CGFloat, c2: CGFloat, mid: CGFloat, c3: CGFloat, end: CGFloat, from: CGFloat = -20, to: CGFloat = 410) {
    c.move(to: CGPoint(x: from, y: y)); c.addLine(to: CGPoint(x: 0, y: y))
    c.addCurve(to: CGPoint(x: 195, y: mid), control1: CGPoint(x: 70, y: c1), control2: CGPoint(x: 130, y: c2))
    c.addCurve(to: CGPoint(x: 390, y: end), control1: CGPoint(x: 260, y: 2 * mid - c2), control2: CGPoint(x: 330, y: c3))
    c.addLine(to: CGPoint(x: to, y: end))
}
makePDF("\(dir("LaunchNightLand"))/LaunchNightLand.pdf", width: 390, height: 120) { c in
    func farDune(_ build: () -> Void, _ opacity: CGFloat, _ top: CGFloat, _ bottom: CGFloat) {
        c.saveGState(); build(); c.closePath(); c.clip()
        let box = c.boundingBoxOfClipPath
        c.setAlpha(opacity)
        linear(c, [(0, 0x5A4A5E), (1, 0x2E2A45)], from: CGPoint(x: 0, y: box.minY), to: CGPoint(x: 0, y: 46))
        c.restoreGState()
    }
    farDune({
        c.move(to: CGPoint(x: 0, y: 30))
        c.addCurve(to: CGPoint(x: 70, y: 9), control1: CGPoint(x: 18, y: 18), control2: CGPoint(x: 44, y: 8))
        c.addCurve(to: CGPoint(x: 142, y: 30), control1: CGPoint(x: 96, y: 10), control2: CGPoint(x: 118, y: 20))
        c.addCurve(to: CGPoint(x: 214, y: 46), control1: CGPoint(x: 166, y: 39), control2: CGPoint(x: 190, y: 44))
        c.addLine(to: CGPoint(x: 214, y: 75)); c.addLine(to: CGPoint(x: 0, y: 75))
    }, 1, 0, 0)
    farDune({
        c.move(to: CGPoint(x: 300, y: 46))
        c.addCurve(to: CGPoint(x: 352, y: 36), control1: CGPoint(x: 318, y: 40), control2: CGPoint(x: 336, y: 36))
        c.addCurve(to: CGPoint(x: 390, y: 41), control1: CGPoint(x: 366, y: 36), control2: CGPoint(x: 380, y: 38))
        c.addLine(to: CGPoint(x: 390, y: 75)); c.addLine(to: CGPoint(x: 300, y: 75))
    }, 1, 0, 0)
    c.setFillColor(rgb(0x232442))
    c.move(to: CGPoint(x: 0, y: 38))
    c.addCurve(to: CGPoint(x: 82, y: 36), control1: CGPoint(x: 24, y: 33), control2: CGPoint(x: 52, y: 32))
    c.addCurve(to: CGPoint(x: 150, y: 47), control1: CGPoint(x: 108, y: 39), control2: CGPoint(x: 128, y: 44))
    c.addLine(to: CGPoint(x: 150, y: 75)); c.addLine(to: CGPoint(x: 0, y: 75)); c.closePath(); c.fillPath()
    c.move(to: CGPoint(x: 262, y: 47))
    c.addCurve(to: CGPoint(x: 362, y: 33), control1: CGPoint(x: 292, y: 43), control2: CGPoint(x: 330, y: 39))
    c.addCurve(to: CGPoint(x: 390, y: 30), control1: CGPoint(x: 374, y: 31), control2: CGPoint(x: 384, y: 30))
    c.addLine(to: CGPoint(x: 390, y: 75)); c.addLine(to: CGPoint(x: 262, y: 75)); c.closePath(); c.fillPath()
    // The sea: opaque night gradient.
    c.saveGState()
    c.move(to: CGPoint(x: 0, y: 46))
    c.addCurve(to: CGPoint(x: 195, y: 45), control1: CGPoint(x: 70, y: 41), control2: CGPoint(x: 130, y: 42))
    c.addCurve(to: CGPoint(x: 390, y: 44), control1: CGPoint(x: 260, y: 48), control2: CGPoint(x: 330, y: 50))
    c.addLine(to: CGPoint(x: 390, y: 120)); c.addLine(to: CGPoint(x: 0, y: 120)); c.closePath(); c.clip()
    let box = c.boundingBoxOfClipPath
    linear(c, [(0, 0x1A2148), (0.55, 0x111737), (1, 0x0B1029)], from: CGPoint(x: 0, y: box.minY), to: CGPoint(x: 0, y: box.maxY))
    c.restoreGState()
    c.setLineCap(.round)
    let lines: [(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)] = [
        (55, 51, 52, 54, 58, 53, 0.9, 0.7), (64, 61, 62, 63, 66, 62, 0.8, 0.5),
        (74, 72, 72, 73, 75, 72, 0.7, 0.32), (85, 84, 84, 85, 86, 84, 0.6, 0.18)]
    for l in lines {
        curve(c, y: l.0, c1: l.1, c2: l.2, mid: l.3, c3: l.4, end: l.5)
        c.setStrokeColor(rgb(0x3D4D93, l.7)); c.setLineWidth(l.6); c.strokePath()
    }
    curve(c, y: 46, c1: 41, c2: 42, mid: 45, c3: 50, end: 44)
    c.setStrokeColor(rgb(0xC9A27A, 0.6)); c.setLineWidth(1.2); c.strokePath()
}
