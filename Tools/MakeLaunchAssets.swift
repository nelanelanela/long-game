// Draws the three vector PDFs the launch screen uses: the night sky (with stars and moon), the sleeping sun and the night land and sea.
// Run from the project folder:  swift Tools/MakeLaunchAssets.swift
// Shapes and colours come from design/redesign/Sky.dc.html, Land.dc.html and Launch.dc.html (same numbers as SkyView and LandView). Y runs downward here, like the design.
import CoreGraphics
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

// The night sky: 390 x 506, everything above the horizon (the horizon is the bottom edge, 60% of an 844 pt screen).
let skyW: CGFloat = 390, skyH: CGFloat = 506
func linear(_ c: CGContext, _ stops: [(CGFloat, UInt32)], from: CGPoint, to: CGPoint) {
    let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!, colors: stops.map { rgb($0.1) } as CFArray,
                       locations: stops.map { $0.0 })!
    c.drawLinearGradient(g, start: from, end: to, options: [])
}
makePDF("\(dir("LaunchNightSky"))/LaunchNightSky.pdf", width: skyW, height: skyH) { c in
    linear(c, [(0, 0x060A1E), (0.55, 0x0F1A3D), (0.85, 0x22305C), (0.97, 0x6B5A5E), (1, 0xC8915A)],
           from: .zero, to: CGPoint(x: 0, y: skyH))
    // The warm glow rising from the horizon.
    let glowSize = max(skyW, skyH) * 1.1
    let glow = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                          colors: [rgb(0xFFD696, 0.55), rgb(0xFFBE6E, 0.22), rgb(0xFFBE6E, 0)] as CFArray,
                          locations: [0, 0.30 / 0.62, 1])!
    c.drawRadialGradient(glow, startCenter: CGPoint(x: skyW / 2, y: skyH), startRadius: 0,
                         endCenter: CGPoint(x: skyW / 2, y: skyH), endRadius: glowSize / 2, options: [])
    // Stars: the same 34 as SkyView.
    for i in 0..<34 {
        let x = CGFloat((i * 61 + 13) % 100) / 100 * skyW
        let y = CGFloat((i * 37 + 7) % 100) / 100 * skyH * 0.82
        let r: CGFloat = i % 7 == 0 ? 1.2 : 0.7
        c.setFillColor(i % 7 == 0 ? rgb(0xFFF4D6, 0.75) : rgb(0xFFFFFF, 0.75))
        c.fillEllipse(in: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r))
    }
    // The crescent moon: a circle with a smaller one taken out.
    let mr: CGFloat = 14
    let mc = CGPoint(x: skyW * 0.74 - 0.38 * mr, y: skyH * 0.12 - 0.58 * mr)
    let ic = CGPoint(x: mc.x + 0.45 * mr, y: mc.y + 0.5 * mr)
    c.saveGState()
    c.addEllipse(in: CGRect(x: mc.x - mr, y: mc.y - mr, width: 2 * mr, height: 2 * mr))
    c.clip()
    c.addRect(CGRect(x: 0, y: 0, width: skyW, height: skyH))
    c.addEllipse(in: CGRect(x: ic.x - 0.95 * mr, y: ic.y - 0.95 * mr, width: 1.9 * mr, height: 1.9 * mr))
    c.setFillColor(rgb(0xF4E9D2, 0.9))
    c.fillPath(using: .evenOdd)
    c.restoreGState()
}

// The sleeping sun: 200 x 200 box, body radius 56, closed eyes and mouth, cheeks, no rays.
makePDF("\(dir("LaunchSun"))/LaunchSun.pdf", width: 200, height: 200) { c in
    c.setFillColor(rgb(0xFFC93C))
    c.fillEllipse(in: CGRect(x: 44, y: 44, width: 112, height: 112))
    c.setFillColor(rgb(0xF7A1B5))
    c.fillEllipse(in: CGRect(x: 65, y: 106, width: 14, height: 14))
    c.fillEllipse(in: CGRect(x: 121, y: 106, width: 14, height: 14))
    c.setStrokeColor(rgb(0x16244A))
    c.setLineWidth(5)
    c.setLineCap(.round)
    for (a, ctl, b) in [((76, 100), (84, 107), (92, 100)), ((108, 100), (116, 107), (124, 100)), ((90, 116), (100, 122), (110, 116))] as [((CGFloat, CGFloat), (CGFloat, CGFloat), (CGFloat, CGFloat))] {
        c.move(to: CGPoint(x: a.0, y: a.1))
        c.addQuadCurve(to: CGPoint(x: b.0, y: b.1), control: CGPoint(x: ctl.0, y: ctl.1))
        c.strokePath()
    }
}

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
        linear(c, [(0, 0x5A4A5E), (1, 0x2E2A45)], from: CGPoint(x: 0, y: box.minY), to: CGPoint(x: 0, y: box.maxY))
        c.restoreGState()
    }
    farDune({
        c.move(to: CGPoint(x: 0, y: 30))
        c.addCurve(to: CGPoint(x: 70, y: 9), control1: CGPoint(x: 18, y: 18), control2: CGPoint(x: 44, y: 8))
        c.addCurve(to: CGPoint(x: 142, y: 30), control1: CGPoint(x: 96, y: 10), control2: CGPoint(x: 118, y: 20))
        c.addCurve(to: CGPoint(x: 214, y: 46), control1: CGPoint(x: 166, y: 39), control2: CGPoint(x: 190, y: 44))
        c.addLine(to: CGPoint(x: 0, y: 46))
    }, 0.75, 0, 0)
    farDune({
        c.move(to: CGPoint(x: 300, y: 46))
        c.addCurve(to: CGPoint(x: 352, y: 36), control1: CGPoint(x: 318, y: 40), control2: CGPoint(x: 336, y: 36))
        c.addCurve(to: CGPoint(x: 390, y: 41), control1: CGPoint(x: 366, y: 36), control2: CGPoint(x: 380, y: 38))
        c.addLine(to: CGPoint(x: 390, y: 46))
    }, 0.6, 0, 0)
    c.setFillColor(rgb(0x232442))
    c.move(to: CGPoint(x: 0, y: 38))
    c.addCurve(to: CGPoint(x: 82, y: 36), control1: CGPoint(x: 24, y: 33), control2: CGPoint(x: 52, y: 32))
    c.addCurve(to: CGPoint(x: 150, y: 47), control1: CGPoint(x: 108, y: 39), control2: CGPoint(x: 128, y: 44))
    c.addLine(to: CGPoint(x: 0, y: 47)); c.closePath(); c.fillPath()
    c.move(to: CGPoint(x: 262, y: 47))
    c.addCurve(to: CGPoint(x: 362, y: 33), control1: CGPoint(x: 292, y: 43), control2: CGPoint(x: 330, y: 39))
    c.addCurve(to: CGPoint(x: 390, y: 30), control1: CGPoint(x: 374, y: 31), control2: CGPoint(x: 384, y: 30))
    c.addLine(to: CGPoint(x: 390, y: 47)); c.closePath(); c.fillPath()
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
