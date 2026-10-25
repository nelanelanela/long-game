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

    // Sun
    static let sunBody = Color(hex: 0xFFC93C)
    static let sunRays = Color(hex: 0xFFB627)
    static let sunRaysBright = Color(hex: 0xFFD15C)
    static let sunCheeks = Color(hex: 0xF7A1B5)
    static let mote = Color(hex: 0xFFE08A)

    // Calendar and forecast
    static let rest = Color(hex: 0xD3DCF2)
    static let practice: [Color] = [Color(hex: 0xFFE48C), Color(hex: 0xFFC53D), Color(hex: 0xFF9A3C), Color(hex: 0xEE6420)]
    static let forecast = Color(hex: 0xEE6420)
    static let forecastBand = Color(hex: 0xFF9A3C)
    static let currentBar = Color(hex: 0xFFB347)

    // Home sunrise card
    static let homeSkyTop = Color(hex: 0xFFF6EC)
    static let homeSkyBottom = Color(hex: 0xFDE6EA)
    static let seaFill = Color(hex: 0xDCE5F7)
    static let seaLine = Color(hex: 0x8FA6E0)

    // Welcome sunrise sky
    static let welcomeSky = Gradient(stops: [
        .init(color: Color(hex: 0x16244A), location: 0),
        .init(color: Color(hex: 0x2C3466), location: 0.34),
        .init(color: Color(hex: 0x8C5A8E), location: 0.58),
        .init(color: Color(hex: 0xE98FA3), location: 0.76),
        .init(color: Color(hex: 0xF7B46A), location: 1),
    ])
}
