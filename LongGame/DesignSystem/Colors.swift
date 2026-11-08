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
    static let background = Color(hex: 0xFAF7F1)
    static let surface = Color.white
    static let ink = Color(hex: 0x16244A)
    static let inkMuted = Color(hex: 0x5E6782)
    static let divider = Color(hex: 0xF0ECE5)
    static let chipBorder = Color(hex: 0xE4DFD6)
    static let danger = Color(hex: 0xB3341A)
    static let chipFill = Color(hex: 0xF3EFE8)
    /// The small clock tile for a session without a photo.
    static let clockTile = Color(hex: 0xF1EDE6)
    static let segmentTrack = Color(hex: 0xEFE2CF)

    // We Have Sun redesign (update prompt 32, part 1)
    /// The wash behind Home's top titles; setup steps use `peachWashSetup`.
    static let peachWash = Color(hex: 0xFFF0D6)
    static let peachWashSetup = Color(hex: 0xFFF1DA)
    static let tabTrack = Color(hex: 0xEFE2CF)
    static let amber = Color(hex: 0xF0922A)
    static let ember = Color(hex: 0xB4561A)
    static let night = Color(hex: 0x0B1029)
    /// Sea gradient, day: `sea` at the top through `seaDeep` to the background at the bottom.
    static let sea = Color(hex: 0xCFD8EF)
    static let seaDeep = Color(hex: 0xE3E8F4)
    /// Sea gradient, night.
    static let seaNight: [Color] = [Color(hex: 0x1A2148), Color(hex: 0x111737), Color(hex: 0x0B1029)]
    static let dune = Color(hex: 0xDCCDB8)
    static let duneFar = Color(hex: 0xEBD6BC)
    static let duneNight = Color(hex: 0x232442)
    static let duneFarNight = Color(hex: 0x5A4A5E)
    static let contour = Color(hex: 0x9FB0E0)
    static let contourNight = Color(hex: 0x3D4D93)
    /// The Timer sun's big number at the start of the day, before it turns ember.
    static let timerGold = Color(hex: 0xFFD66B)
    /// The iPad/Mac sidebar and its quiet capsule button (#EFEBE4), and the chosen row's wash.
    static let sidebar = Color(hex: 0xEFEBE4)
    static let sidebarSelection = Color(hex: 0x16244A).opacity(0.10)
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
    /// The dotted line at the actual pace.
    static let actualPace = Color(hex: 0x9AA1B5)
    /// The name "Your chosen pace" in the Growth key (a darker orange for words, as the spec asks).
    static let chosenPaceName = Color(hex: 0xC2531A)
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
    /// The iCloud symbol on the Keep your game safe card and the Welcome back illustration.
    static let icloud = Color(hex: 0x3D8BFD)
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

    // Opening sunrise (spec section 21). Each trio is night → dusk → morning; the sky goes top, middle, bottom.
    static let openingNight = 0x16244A as UInt32
    static let openingSkyTop: (UInt32, UInt32, UInt32) = (0x16244A, 0x2A2F6B, 0xFFE3B0)
    static let openingSkyMiddle: (UInt32, UInt32, UInt32) = (0x16244A, 0x6E3D74, 0xFFF1DA)
    static let openingSkyBottom: (UInt32, UInt32, UInt32) = (0x16244A, 0xF2A07A, 0xFAF8F4)
    static let openingSeaFill: (UInt32, UInt32, UInt32) = (0x22306A, 0x2B3A73, 0xD3DEF4)
    static let openingSeaWave: (UInt32, UInt32, UInt32) = (0x2E3C7A, 0x4A5A96, 0xBCC9E9)
    static let openingSeaLine: (UInt32, UInt32, UInt32) = (0x3E4C8A, 0x9FB0E0, 0x16244A)
}
