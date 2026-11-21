import SwiftUI

extension Color {
    /// One colour for the light look and one for the dark (update 45). The light value is exactly the old colour, so
    /// the light look doesn't change. The Watch is always dark-styled and keeps the light value.
    init(light: UInt32, dark: UInt32, lightOpacity: Double = 1, darkOpacity: Double = 1) {
        #if os(iOS)
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark, opacity: darkOpacity) : UIColor(hex: light, opacity: lightOpacity)
        })
        #elseif os(macOS)
        self.init(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(hex: dark, opacity: darkOpacity) : NSColor(hex: light, opacity: lightOpacity)
        })
        #else
        self.init(hex: light, opacity: lightOpacity)
        #endif
    }

    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

#if os(iOS)
extension UIColor {
    convenience init(hex: UInt32, opacity: Double) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: opacity)
    }
}
#elseif os(macOS)
extension NSColor {
    convenience init(hex: UInt32, opacity: Double) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: opacity)
    }
}
#endif

/// Design tokens from the Visual system section of the spec. Since update 45 most have a dark value
/// (`design/redesign/DarkMode.dc.html`); the sun, the scenes, the calendar's level colours and the session pictures
/// use fixed colours and look the same in both.
enum LGColor {
    /// The paper colour and the navy as fixed colours, for things that never change with the look: the sun's face,
    /// the scenes' day land and dawn sky, the cards made for sharing.
    static let paper = Color(hex: 0xFAF7F1)
    static let navy = Color(hex: 0x16244A)

    static let background = Color(light: 0xFAF7F1, dark: 0x0B1029)
    /// Cards.
    static let surface = Color(light: 0xFFFFFF, dark: 0x172044)
    /// Text.
    static let ink = Color(light: 0x16244A, dark: 0xF4EFE6)
    static let inkMuted = Color(light: 0x5E6782, dark: 0xA9B1C9)
    /// The primary button: navy with white words, gold with navy words in the dark look.
    static let primaryFill = Color(light: 0x16244A, dark: 0xFFD66B)
    static let primaryLabel = Color(light: 0xFFFFFF, dark: 0x16244A)
    /// The small toasts ("40 m added"): navy, or a lighter night blue in the dark look; white words in both.
    static let toastFill = Color(light: 0x16244A, dark: 0x2B3566)
    /// A chosen option drawn as a filled pill (Keep / Use on the Finish sheet, Light / Dark in Settings).
    static let selectedFill = Color(light: 0x16244A, dark: 0xFFD66B)
    static let selectedLabel = Color(light: 0xFFFFFF, dark: 0x16244A)
    /// The dashed outlines (a day's plan in the day bars, the empty photo square).
    static let dashedOutline = Color(light: 0xCFC6B6, dark: 0x3A4470)
    /// The thin inner line cards get in the dark look instead of a shadow.
    static let cardEdge = Color.white.opacity(0.08)
    static let divider = Color(light: 0xF0ECE5, dark: 0x222B52)
    static let chipBorder = Color(light: 0xE4DFD6, dark: 0x2E3866)
    static let danger = Color(light: 0xB3341A, dark: 0xFF8A73)
    static let chipFill = Color(light: 0xF3EFE8, dark: 0x1E2750)
    /// The small clock tile for a session without a photo.
    static let clockTile = Color(light: 0xF1EDE6, dark: 0x1E2750)
    /// The sleeping sun's "z" on the launch screen.
    static let sleepZ = Color(hex: 0x8FA2E0)
    static let segmentTrack = Color(light: 0xEFE2CF, dark: 0x262F57)
    /// The chosen tab's pill: white in the light look, a solid warm light in the dark look and on dark skies (with
    /// navy words), so it never melts into the track.
    static let segmentChosen = Color(light: 0xFFFFFF, dark: 0xF4EEE4)

    // We Have Sun redesign (update prompt 32, part 1)
    /// The wash behind Home's top titles; setup steps use `peachWashSetup`.
    static let peachWash = Color(light: 0xFFF0D6, dark: 0x2A2440)
    static let peachWashSetup = Color(light: 0xFFF1DA, dark: 0x2A2440)
    /// The inside edge of the white bubble round the bell on "A gentle nudge".
    static let bellBubble = Color(light: 0xFFF4E4, dark: 0x2A2440)
    static let tabTrack = Color(light: 0xEFE2CF, dark: 0x262F57)
    static let amber = Color(hex: 0xF0922A)
    /// Accent words.
    static let ember = Color(light: 0xB4561A, dark: 0xFFB877)
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
    /// "Delete all photos from …": the soft red wash and its text.
    static let deleteWash = Color(light: 0xFDF0EC, dark: 0x3A1E2E)
    static let deleteInk = Color(light: 0xC0392B, dark: 0xFF8A73)
    static let timerGold = Color(hex: 0xFFD66B)
    /// The gold day bar's top colour (it fades to amber).
    static let dayBarTop = Color(hex: 0xFFD45A)
    /// Last week's faint bar behind This week's day bars: navy at 8%.
    static let lastWeekBar = Color(light: 0x16244A, dark: 0xFFFFFF, lightOpacity: 0.08, darkOpacity: 0.10)
    /// Settings' peach icon tiles (Write to us).
    static let peachTile = Color(light: 0xFFF1DA, dark: 0x2A2440)
    /// The anniversary pill under Home's number.
    static let anniversaryPill = Color(light: 0xFFF1DA, dark: 0x2A2440)
    /// Words on the anniversary pill and the memory card: ember a touch darker in light, so it reads at 4.9:1 on the
    /// peach (ember itself measures 4.4:1 there). Decided for 1.0.
    /// The small tag behind the gauge's scale words on the dusk and night skies: navy at 60%.
    static let gaugeLabelTag = Color(hex: 0x16244A).opacity(0.6)
    static let anniversaryText = Color(light: 0xA9501A, dark: 0xFFB877)
    /// Clouds in the weather layer on the night sky: a pale moonlit blue (update 49).
    static let moonCloud = Color(hex: 0xC9D2EC)
    /// The shading over a cloud in the day look, top to bottom (update 52): white, warm white, a cool lilac grey, and
    /// the underside lit by the low sun (warm far away, cooler near). The values live in `CloudSky.shading`.
    static func cloudShading(_ depth: CloudDepth) -> Gradient {
        Gradient(stops: CloudSky.shading(depth).map { .init(color: Color(hex: $0.hex), location: $0.at) })
    }
    /// The milestone card's small gold line over the dawn sky.
    /// History's calendar: a day before the game began, a pale dot that doesn't read as a missed day.
    static let beforeGameDot = Color(light: 0xEFEBE4, dark: 0x1E2750)
    static let milestoneGold = Color(hex: 0xFFE08A)
    /// Share this moment: translucent white in light, a faint lift in dark.
    static let shareMomentFill = Color(light: 0xFFFFFF, dark: 0xFFFFFF, lightOpacity: 0.7, darkOpacity: 0.08)
    /// The navy pill with gold words (Then and now's "… later", a letter's "You wrote this …"): lifted on the night
    /// background so it still reads as a pill.
    static let storyPill = Color(light: 0x16244A, dark: 0x2E3C78)
    /// The faint rules on a letter's paper and the envelope's flap.
    static let paperRule = Color(light: 0xE4E6EC, dark: 0x2C3560)
    /// A letter's paper and the sealed envelope (update 49).
    static let letterPaper = Color(light: 0xFFFDF8, dark: 0x1C2446)
    /// The Finish sheet's "A long one" card.
    static let longSessionCard = Color(light: 0xFFF1DA, dark: 0x2A2440)
    /// The Undo pill inside Home's navy toast: a slightly lighter navy.
    static let toastUndoPill = Color.white.opacity(0.14)
    /// The iPad/Mac sidebar and its quiet capsule button (#EFEBE4), and the chosen row's wash.
    static let sidebar = Color(light: 0xEFEBE4, dark: 0x10163A)
    static let sidebarSelection = Color(light: 0x16244A, dark: 0xFFFFFF, lightOpacity: 0.10, darkOpacity: 0.10)
    // The setup scene and time strip (update 53, SetupScene.dc.html)
    /// A chip not yet filled in: a thin outline (#D9D2C6), also the time strip's dashed future on step 3.
    static let setupChipPending = Color(light: 0xD9D2C6, dark: 0x3A4470)
    /// The dashed finish line across the top of the setup scene.
    static let setupFinishLine = Color(hex: 0xE0A93A)
    /// The chip being changed on this screen, and its gold ring.
    static let setupChipEditing = Color(light: 0xFFF0C8, dark: 0x3A3350)
    static let setupChipRing = Color(hex: 0xF0B43A)
    /// The finish line chip's gold gradient (left to right).
    static let setupFinishTop = Color(hex: 0xFFD66B)
    static let setupFinishBottom = Color(hex: 0xF0A93A)
    /// The lit part of the time strip, and the link card's dot: the step dots' gold (#FFC93C → #F0922A).
    static let setupLitStart = Color(hex: 0xFFC93C)
    static let setupLitEnd = Color(hex: 0xF0922A)
    /// The time strip's quiet part.
    static let setupStripQuiet = Color(light: 0xE4DFD6, dark: 0x2E3866)
    // Hour steppers
    static let stepperButton = Color(light: 0xF3F0EA, dark: 0x262F57)
    static let stepperButtonLimit = Color(light: 0xF6F4EF, dark: 0x1E2750)
    static let stepperGlyphLimit = Color(light: 0xC9C3B8, dark: 0x4A5482)
    static let stepperHighlight = Color(light: 0xFFF0C8, dark: 0x3A3350)
    /// The shaded edge of a round − / + button (its face runs from white to this).
    static let stepperFace = Color(light: 0xF1ECE3, dark: 0x1E2750)
    /// The light top of that face (white in the light look).
    static let stepperFaceTop = Color(light: 0xFFFFFF, dark: 0x2B3566)

    // Sun
    static let sunBody = Color(hex: 0xFFC93C)
    static let sunRays = Color(hex: 0xFFB627)
    static let sunRaysBright = Color(hex: 0xFFD15C)
    static let sunCheeks = Color(hex: 0xF7A1B5)
    /// The laughing face's deeper cheeks.
    static let sunCheeksDeep = Color(hex: 0xF48FA8)
    static let mote = Color(hex: 0xFFE08A)

    // Calendar and forecast
    /// Rest days: the calendar's dot, the day bars' dot.
    static let rest = Color(light: 0xC5D0EC, dark: 0x3D4D93)
    static let practice: [Color] = [Color(hex: 0xFFE48C), Color(hex: 0xFFC53D), Color(hex: 0xFF9A3C), Color(hex: 0xE8561E)]
    static let forecast = Color(hex: 0xEE6420)
    /// The dashed line at the chosen pace on the Growth chart, and the warm area under the past line.
    static let chosenLine = Color(hex: 0xE07A22)
    static let growthArea = Color(hex: 0xFFC56A)
    /// The forecast orange darkened to 4.5:1 for words (the lines and band keep the brighter orange).
    static let forecastText = Color(light: 0xB8470E, dark: 0xFFB877)
    /// The dotted line at the actual pace.
    static let actualPace = Color(hex: 0x9AA1B5)
    /// The name "Your chosen pace" in the Growth key (a darker orange for words, as the spec asks).
    static let chosenPaceName = Color(light: 0xB4561A, dark: 0xFFB877)
    static let currentBar = Color(hex: 0xFFB347)

    // Sunrise hero (Home, intro pages, future-self sheet). The sea is fully opaque: nothing shows through it.
    static let seaFill = Color(hex: 0xD3DEF4)
    /// #B9C7E8 at 90% over the sea fill, pre-mixed so the pale wave needs no transparency.
    static let seaWave = Color(hex: 0xBCC9E9)
    static let hairline = Color(light: 0xECE7DE, dark: 0x222B52)
    /// The Apple Watch's dark sea and its wave line (the watch is always dark).
    static let watchSea = Color(hex: 0x1F2E5C)
    static let watchWave = Color(hex: 0x8FA6E0)
    /// The sun gauge's scale line and ticks.
    static let gaugeLine = Color(hex: 0xC9C3B8)
    /// Scale labels and day letters (#8A93AB in the design, darkened to 4.5:1 contrast on the background).
    static let gaugeLabel = Color(light: 0x68718C, dark: 0xA9B1C9)
    /// "Finish line · 10,000 hours" on the first intro page (#A0712E in the design, darkened to 4.5:1 contrast).
    static let finishLabel = Color(light: 0x8A5A1E, dark: 0xFFB877)
    static let finishDash = Color(hex: 0xE0A040)
    static let track = Color(light: 0xEFEAE1, dark: 0x262F57)
    /// Today's arc: the dotted road, the moon at its end (#D9D2C4 and #C9D3EC), and the Timer strip's pale moon.
    static let arcDots = Color(hex: 0xD9D2C4)
    static let moon = Color(hex: 0xC9D3EC)
    static let moonOnDark = Color(hex: 0xE6ECF8)
    /// The soft circle behind Today's moon (#DCE3F5 at 60 % on the board).
    static let moonHalo = Color(hex: 0xDCE3F5).opacity(0.6)
    static let introDot = Color(hex: 0xD9D2C4)
    /// The iCloud symbol on the Keep your game safe card and the Welcome back illustration.
    static let icloud = Color(hex: 0x2F7BF6)
    /// The pale blue tile behind the iCloud symbol on the Keep your game safe card.
    static let icloudTile = Color(hex: 0xEAF2FF)
    /// Settings › Your data: the pale blue tile behind the cloud on the Data & storage row, in both looks.
    static let dataTile = Color(light: 0xEAF2FF, dark: 0x1E2A5A)
    static let dataTileIcon = Color(light: 0x2F7BF6, dark: 0x8FB4FF)
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
