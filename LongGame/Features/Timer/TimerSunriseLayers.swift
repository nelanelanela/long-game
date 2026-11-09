import SwiftUI

// The Timer's scenery (update prompt 32, part 6). The sky and the land are two separate layers so the sun can sit
// between them: the sea is always in front of the sun, and the layer under any fade is always opaque.

/// The text colours at today's progress `p`: white at night, navy by day, and the big number from gold to ember.
struct TimerPalette: Equatable {
    var ink: Color
    var muted: Color
    var gold: Color
    /// The quiet line once the stretch is covered (#FFE08A to ember).
    var covered: Color
    var isLight: Bool
    /// The soft fill of the quiet buttons.
    var buttonFill: Color
    var buttonLine: Color
    var track: Color
    var beforeBar: Color
    var chip: Color

    init(p: Double) {
        let l = TimerSunrise.lightness(p: p)
        isLight = l > 0.5
        ink = Color(hex: TimerSunrise.inkHex(p: p))
        muted = isLight ? LGColor.inkMuted : Color.white.opacity(0.72)
        gold = Color(hex: TimerSunrise.goldHex(p: p))
        covered = Color(hex: mixHex(0xFFE08A, TimerSunrise.ember, l))
        buttonFill = isLight ? Color(hex: 0x16244A, opacity: 0.06) : Color.white.opacity(0.14)
        buttonLine = isLight ? Color(hex: 0x16244A, opacity: 0.14) : Color.white.opacity(0.18)
        track = isLight ? Color(hex: 0xE4DFD6) : Color.white.opacity(0.18)
        beforeBar = isLight ? Color(hex: 0xE8C98A) : Color(hex: 0xFFD66B, opacity: 0.5)
        chip = isLight ? Color(hex: 0x16244A, opacity: 0.08) : Color.white.opacity(0.14)
    }
}

/// Day, dawn and night skies cross-fading with today's progress, and the glow behind the sun.
struct TimerSunriseSky: View {
    var p: Double
    var paused: Bool
    var horizonY: CGFloat
    /// The sun's centre, for the glow.
    var sunCentre: CGPoint

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let horizon = min(max(horizonY / h, 0.3), 1)
            ZStack(alignment: .topLeading) {
                LGColor.night
                // Full day, under the others: pale blue to warm cream, down to the horizon.
                LinearGradient(stops: [.init(color: Color(hex: 0xA9C1EA), location: 0),
                                       .init(color: Color(hex: 0xD7E2F3), location: 0.48),
                                       .init(color: Color(hex: 0xFFE7C2), location: 1)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(width: w, height: horizonY)
                    .opacity(TimerSunrise.dayOpacity(p: p))
                // A little more of the same cream below the horizon, so the sway of the shoreline never shows the
                // night base behind it.
                Color(hex: 0xFFE7C2)
                    .frame(width: w, height: 40)
                    .offset(y: horizonY - 1)
                    .opacity(TimerSunrise.dayOpacity(p: p))
                SkyView(tone: .dawn, horizon: horizon, moon: false)
                    .frame(width: w, height: h)
                    .opacity(TimerSunrise.dawnOpacity(p: p))
                SkyView(tone: .night, horizon: horizon, moon: true)
                    .frame(width: w, height: h)
                    .opacity(TimerSunrise.nightOpacity(p: p))
                // The glow is cut off at the horizon, so nothing gold ever shows below it.
                // Peach at night, warming to gold by day: translucent gold over navy goes olive green on a phone.
                let glowHex = mixHex(0xF2A07A, 0xFFD68C, TimerSunrise.lightness(p: p))
                RadialGradient(stops: [.init(color: Color(hex: glowHex, opacity: 0.55), location: 0),
                                       .init(color: Color(hex: glowHex, opacity: 0.18), location: 0.34 / 0.64),
                                       .init(color: Color(hex: glowHex, opacity: 0), location: 1)],
                               center: .center, startRadius: 0, endRadius: 520 * 0.64 / 2 * 2.0.squareRoot())
                    .frame(width: 520, height: 520)
                    .position(x: sunCentre.x, y: sunCentre.y)
                    .opacity(TimerSunrise.glowOpacity(p: p, paused: paused))
                    .frame(width: w, height: horizonY, alignment: .topLeading)
                    .clipped()
                    .frame(width: w, height: h, alignment: .topLeading)
            }
            .frame(width: w, height: h)
            // Paused: the whole sky goes quieter.
            .saturation(paused ? TimerSunrise.pausedSaturation : 1)
            .colorMultiply(paused ? Color(white: TimerSunrise.pausedBrightness) : .white)
            .lgAnimation(.easeOut(duration: 0.5), value: paused)
        }
        .accessibilityHidden(true)
    }
}

/// The dunes and the sea in front of the sun. The night land and the navy fill under them never fade; the day land
/// and the background-coloured fill fade in on top.
struct TimerSunriseLand: View {
    var p: Double
    var horizonY: CGFloat

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let k = w / 390
            let landHeight = 120 * k
            // The land's shoreline is 46 down in its 120 tall box.
            let landTop = horizonY + 1 - 46 * k
            let fillTop = landTop + landHeight
            let day = TimerSunrise.landDayOpacity(p: p)
            ZStack(alignment: .topLeading) {
                LGColor.night.frame(width: w, height: max(0, h - fillTop)).offset(y: fillTop)
                LandView(tone: .night).frame(width: w, height: landHeight).offset(y: landTop)
                LGColor.background.frame(width: w, height: max(0, h - fillTop)).offset(y: fillTop).opacity(day)
                LandView(tone: .day).frame(width: w, height: landHeight).offset(y: landTop).opacity(day)
            }
            .frame(width: w, height: h, alignment: .topLeading)
        }
        .accessibilityHidden(true)
    }
}

/// Pause / Resume and Finish, as the board draws them. Resume is gold; Finish is white at night and navy by day.
struct TimerPillStyle: ButtonStyle {
    enum Look { case quiet, gold, solid }
    var look: Look
    var palette: TimerPalette

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .lgText(.button, color: foreground)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                if look == .quiet {
                    RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(palette.buttonLine, lineWidth: 1)
                }
            }
            .shadow(color: look == .solid ? Color(hex: 0xFFD66B, opacity: 0.3) : .clear, radius: 15)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var foreground: Color {
        switch look {
        case .quiet: palette.ink
        case .gold: LGColor.ink
        case .solid: palette.isLight ? .white : LGColor.ink
        }
    }

    private var background: AnyShapeStyle {
        switch look {
        case .quiet: AnyShapeStyle(palette.buttonFill)
        case .gold: AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xFFE7A0), Color(hex: 0xFFC94A)], startPoint: .top, endPoint: .bottom))
        case .solid: AnyShapeStyle(palette.isLight ? LGColor.ink : Color.white)
        }
    }
}

#Preview("Timer scenery · 0, 37, 75, 100 %") {
    ScrollView(.horizontal) {
        HStack(spacing: 12) {
            ForEach([0.02, 0.37, 0.75, 1.0], id: \.self) { p in
                let horizon: CGFloat = 470, rise: CGFloat = 245
                let centre = CGPoint(x: 195, y: TimerSunrise.sunCentreY(p: p, horizonY: horizon, rise: rise))
                ZStack {
                    TimerSunriseSky(p: p, paused: false, horizonY: horizon, sunCentre: centre)
                    SunView(idle: false, face: p < 1 ? .focus : .happy, rayColor: LGColor.sunRaysBright)
                        .frame(width: 200, height: 200).position(centre)
                    TimerSunriseLand(p: p, horizonY: horizon)
                }
                .frame(width: 390, height: 844)
            }
        }
    }
}
