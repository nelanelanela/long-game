// Draws the three vector PDFs the launch screen uses: the stars, the sleeping sun and the night sea.
// Run from the project folder:  swift Tools/MakeLaunchAssets.swift
// Shapes and colours come from design/Launch.dc.html (the first board). Y runs downward here, like the design.
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

// Stars: a 390 x 422 sky (the top half of the 390 x 844 design). Left, top, size, opacity.
let stars: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
    (48, 120, 2, 0.5), (92, 210, 1.5, 0.35), (150, 90, 2, 0.45), (232, 160, 1.5, 0.3), (300, 110, 2, 0.5),
    (340, 240, 1.5, 0.35), (70, 320, 1.5, 0.3), (270, 300, 2, 0.4), (190, 250, 1.5, 0.25),
]
makePDF("\(dir("LaunchStars"))/LaunchStars.pdf", width: 390, height: 422) { c in
    for (l, t, s, o) in stars {
        c.setFillColor(rgb(0xFFFFFF, o))
        c.fillEllipse(in: CGRect(x: l, y: t, width: s, height: s))
    }
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

// The night sea band: 1440 wide so it spans the widest iPad, 50 tall. The waterline is at y = 10.
// Waves are 20 pt arches bowing 7 pt, the same as WavePath in the app.
let seaW: CGFloat = 1440, seaH: CGFloat = 50
func wave(_ c: CGContext, y: CGFloat) {
    var x: CGFloat = 0
    var up = true
    c.move(to: CGPoint(x: x, y: y))
    while x < seaW {
        c.addQuadCurve(to: CGPoint(x: x + 20, y: y), control: CGPoint(x: x + 10, y: y + (up ? -7 : 7)))
        x += 20
        up.toggle()
    }
}
makePDF("\(dir("LaunchSea"))/LaunchSea.pdf", width: seaW, height: seaH) { c in
    wave(c, y: 10)
    c.addLine(to: CGPoint(x: seaW, y: seaH))
    c.addLine(to: CGPoint(x: 0, y: seaH))
    c.closePath()
    c.setFillColor(rgb(0x22306A))
    c.fillPath()
    c.setLineWidth(2)
    c.setLineCap(.round)
    c.setStrokeColor(rgb(0x2E3C7A))
    wave(c, y: 30)
    c.strokePath()
    c.setStrokeColor(rgb(0x3E4C8A))
    wave(c, y: 10)
    c.strokePath()
}
