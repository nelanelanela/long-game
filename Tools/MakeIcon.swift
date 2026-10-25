// Draws the app icon from the same sun geometry as SunView (200 × 200 space).
// Run:  swift Tools/MakeIcon.swift LongGame/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let out = CommandLine.arguments.dropFirst().first ?? "AppIcon.png"

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!

// y-down drawing space, like the SVG
ctx.translateBy(x: 0, y: CGFloat(size))
ctx.scaleBy(x: 1, y: -1)

// Sunrise sky (the Welcome gradient)
let sky = CGGradient(colorsSpace: space, colors: [color(0x16244A), color(0x2C3466), color(0x8C5A8E), color(0xE98FA3), color(0xF7B46A)] as CFArray,
                     locations: [0, 0.34, 0.58, 0.76, 1])!
ctx.drawLinearGradient(sky, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: CGFloat(size)), options: [])

// Sun, scaled so the rays fill about 70% of the icon
let k = CGFloat(size) / 200 * 0.76
let cx = CGFloat(size) / 2, cy = CGFloat(size) * 0.56
func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: cx + (x - 100) * k, y: cy + (y - 100) * k) }

// glow
let glow = CGGradient(colorsSpace: space, colors: [color(0xFFD678, 0.55), color(0xFFD678, 0)] as CFArray, locations: [0, 1])!
ctx.drawRadialGradient(glow, startCenter: CGPoint(x: cx, y: cy), startRadius: 0, endCenter: CGPoint(x: cx, y: cy), endRadius: 105 * k, options: [])

// rays
ctx.setStrokeColor(color(0xFFD15C))
ctx.setLineWidth(9 * k)
ctx.setLineCap(.round)
for i in 0..<12 {
    let a = (CGFloat(i) * 30 - 90) * .pi / 180
    let outer: CGFloat = i % 2 == 1 ? 92 : 82
    ctx.move(to: p(100 + 66 * cos(a), 100 + 66 * sin(a)))
    ctx.addLine(to: p(100 + outer * cos(a), 100 + outer * sin(a)))
    ctx.strokePath()
}

// body and cheeks
ctx.setFillColor(color(0xFFC93C))
ctx.fillEllipse(in: CGRect(x: p(44, 44).x, y: p(44, 44).y, width: 112 * k, height: 112 * k))
ctx.setFillColor(color(0xF7A1B5))
for x in [72.0, 128.0] {
    ctx.fillEllipse(in: CGRect(x: p(CGFloat(x) - 7, 106).x, y: p(CGFloat(x) - 7, 106).y, width: 14 * k, height: 14 * k))
}

// face: happy eyes and smile
ctx.setStrokeColor(color(0x16244A))
ctx.setLineWidth(4.5 * k)
func quad(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ bend: CGFloat) {
    ctx.move(to: p(x, y))
    ctx.addQuadCurve(to: p(x + w, y), control: p(x + w / 2, y + bend))
    ctx.strokePath()
}
quad(76, 98, 16, -9)
quad(108, 98, 16, -9)
quad(88, 114, 24, 11)

let image = ctx.makeImage()!
let url = URL(fileURLWithPath: out)
let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, image, nil)
CGImageDestinationFinalize(dest)
print("Wrote \(out)")
