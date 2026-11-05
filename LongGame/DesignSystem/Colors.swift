import SwiftUI

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

/// Design tokens from the Visual system section of the spec.
enum LGColor {
    static let background = Color(hex: 0xFAF8F4)
    static let surface = Color.white
    static let ink = Color(hex: 0x16244A)
    static let inkMuted = Color(hex: 0x5E6782)
    static let divider = Color(hex: 0xF0ECE5)
    static let chipBorder = Color(hex: 0xE4DFD6)
    static let danger = Color(hex: 0xB3341A)
    static let chipFill = Color(hex: 0xF3EFE8)
    static let segmentTrack = Color(hex: 0xEFEBE4)
    // Hour steppers
    static let stepperButton = Color(hex: 0xF3F0EA)
    static let stepperButtonLimit = Color(hex: 0xF6F4EF)
    static let stepperGlyphLimit = Color(hex: 0xC9C3B8)
    static let stepperHighlight = Color(hex: 0xFFF3D6)

    // Sun
    static let sunBody = Color(hex: 0xFFC93C)
    static let sunRays = Color(hex: 0xFFB627)
    static let sunRaysBright = Color(hex: 0xFFD15C)
    static let sunCheeks = Color(hex: 0xF7A1B5)
    /// The laughing face's deeper cheeks.
    static let sunCheeksDeep = Color(hex: 0xF48FA8)
    static let mote = Color(hex: 0xFFE08A)

    // Calendar and forecast
    static let rest = Color(hex: 0xC5D0EC)
    static let practice: [Color] = [Color(hex: 0xFFE48C), Color(hex: 0xFFC53D), Color(hex: 0xFF9A3C), Color(hex: 0xEE6420)]
    static let forecast = Color(hex: 0xEE6420)
    /// The forecast orange darkened to 4.5:1 for words (the lines and band keep the brighter orange).
    static let forecastText = Color(hex: 0xB8470E)
    static let forecastBand = Color(hex: 0xFF9A3C)
    static let currentBar = Color(hex: 0xFFB347)

    // Sunrise hero (Home, intro pages, future-self sheet). The sea is fully opaque: nothing shows through it.
    static let seaFill = Color(hex: 0xD3DEF4)
    /// #B9C7E8 at 90% over the sea fill, pre-mixed so the pale wave needs no transparency.
    static let seaWave = Color(hex: 0xBCC9E9)
    static let hairline = Color(hex: 0xECE7DE)
    /// The Apple Watch's dark sea and its wave line (the watch is always dark).
    static let watchSea = Color(hex: 0x1F2E5C)
    static let watchWave = Color(hex: 0x8FA6E0)
    /// The sun gauge's scale line and ticks.
    static let gaugeLine = Color(hex: 0xC9C3B8)
    /// Scale labels and day letters (#8A93AB in the design, darkened to 4.5:1 contrast on the background).
    static let gaugeLabel = Color(hex: 0x68718C)
    /// "Finish line · 10,000 hours" on the first intro page (#A0712E in the design, darkened to 4.5:1 contrast).
    static let finishLabel = Color(hex: 0x8A5E1E)
    static let finishDash = Color(hex: 0xE0B04A)
    static let track = Color(hex: 0xEFEAE1)
    /// Today's arc: the dotted road, the moon at its end (#D9D2C4 and #C9D3EC), and the Timer strip's pale moon.
    static let arcDots = Color(hex: 0xD9D2C4)
    static let moon = Color(hex: 0xC9D3EC)
    static let moonOnDark = Color(hex: 0xE6ECF8)
    static let introDot = Color(hex: 0xDDD6CA)
    static let futureSky = Gradient(stops: [
        .init(color: .white, location: 0),
        .init(color: Color(hex: 0xFFF1DA), location: 0.7),
        .init(color: Color(hex: 0xFFE9C7), location: 1),
    ])

    // Welcome sunrise sky
    static let welcomeSky = Gradient(stops: [
        .init(color: Color(hex: 0x16244A), location: 0),
        .init(color: Color(hex: 0x2C3466), location: 0.34),
        .init(color: Color(hex: 0x8C5A8E), location: 0.58),
        .init(color: Color(hex: 0xE98FA3), location: 0.76),
        .init(color: Color(hex: 0xF7B46A), location: 1),
    ])
}
