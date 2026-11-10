import SwiftUI

/// The Home hero: the sunrise scene. On This week and The long game it has a vertical scale on the left and a navy
/// pill at the sun's height, joined to the sun by a dashed gold line. On Today there is no scale: the sun moves
/// along a dotted arc to the moon. When the tab changes the sun glides to its new place (0.6 s); Home animates the
/// three numbers below and SwiftUI interpolates them frame by frame.
struct GaugeHero: View, Animatable {
    /// The shown tab's gauge: its scale and pill (none on Today) and what VoiceOver reads.
    var gauge: HomeGauge
    /// Equal to `gauge.fraction` on the scale tabs; the last scale tab's value while Today is shown.
    /// Interpolated while the tab change animates.
    var fraction: Double
    /// How far along Today's arc the sun is (0...1), and how much of the sun's place is the arc's (0 = on the scale).
    var arcFraction: Double = 0
    var arcMix: Double = 0
    var face: SunFace = .happy
    var isRunning = true
    /// False with Reduce Motion: the sun jumps to its new place and only the labels cross-fade.
    var glides = true
    /// True in the phone's single column: the tab's sky runs up behind the status bar, title and tabs, so there is
    /// one continuous sky with no seam (day on Today and This week, dawn on the empty day and The long game).
    var extendsSky = false
    /// Today with nothing played yet: the dark, starry dawn sky of the empty-day board (a day sky once the sun climbs).
    var dawnSky = false
    /// The hero's size: the phone's by default, smaller or wider for other windows.
    var metrics: GaugeMetrics = .standard
    /// The final values, for Reduce Motion (they are used instead of the interpolated ones).
    var final: Place?
    /// This week only: one line per day, read when VoiceOver users swipe up or down on the sun.
    var dayReadings: [String] = []
    /// The opening sunrise glides its sun to where Home's sun sits on Today's arc; Home tells it where that is.
    @Environment(OpeningCenter.self) private var opening: OpeningCenter?

    struct Place: Equatable {
        var fraction: Double
        var arcFraction: Double
        var arcMix: Double
    }

    nonisolated var animatableData: AnimatablePair<Double, AnimatablePair<Double, Double>> {
        get { AnimatablePair(fraction, AnimatablePair(arcFraction, arcMix)) }
        set {
            fraction = newValue.first
            arcFraction = newValue.second.first
            arcMix = newValue.second.second
        }
    }

    /// How far the sky reaches above the hero, to sit behind the status bar, title and tabs.
    static let skyExtension: CGFloat = 340

    /// The long game is the dark one: dawn sky, white scale and a white pill.
    private var onDark: Bool { gauge.tab == .longGame }

    private var shown: Place {
        if !glides, let final { return final }
        return Place(fraction: fraction, arcFraction: arcFraction, arcMix: arcMix)
    }

    var body: some View {
        let place = shown
        GeometryReader { geo in
            let width = geo.size.width
            let arc = ArcGeometry(width: width, metrics: metrics)
            let onScale = CGPoint(x: width / 2 + metrics.sunOffsetX, y: metrics.centreY(fraction: place.fraction))
            let onArc = arc.point(place.arcFraction)
            let mix = CGFloat(GaugeGeometry.clamped(place.arcMix))
            let centre = CGPoint(x: onScale.x + (onArc.x - onScale.x) * mix, y: onScale.y + (onArc.y - onScale.y) * mix)
            let size = metrics.sunSize + (arc.sunSize - metrics.sunSize) * mix

            ZStack(alignment: .topLeading) {
                // The sky runs on up behind the title and tabs (the page draws nothing of its own there): the day sky
                // on Today and This week, the dawn sky on the empty day and The long game. It is drawn here, under the
                // arc, so the dotted arc and its moon show on it.
                if extendsSky {
                    let ext = Self.skyExtension
                    SkyView(tone: onDark || dawnSky ? .dawn : .day, horizon: (ext + metrics.waterY) / (ext + metrics.height),
                            moon: onDark, glowX: min(max((width / 2 + metrics.sunOffsetX) / width, 0), 1))
                        .frame(width: width, height: ext + metrics.height)
                        .offset(y: -ext)
                } else if dawnSky && !onDark {
                    // Other windows: the empty day's dark dawn sky stays inside the hero.
                    SkyView(tone: .dawn, horizon: metrics.waterY / metrics.height, moon: false,
                            glowX: min(max((width / 2 + metrics.sunOffsetX) / width, 0), 1))
                        .frame(width: width, height: metrics.height)
                        .opacity(Double(mix))
                }
                // Today's arc sits behind the sea and the sun, and fades with the tab.
                StretchArcLayer(geometry: arc, fraction: place.arcFraction)
                    .opacity(Double(mix))
                SunriseHero(layout: .placed(centre: centre, width: width, sunSize: size, face: face, metrics: metrics,
                                            scene: onDark || dawnSky ? .dawn : .day, drawsSky: !extendsSky && !(dawnSky && !onDark),
                                            skyMoon: onDark),
                            label: gauge.spoken.label, value: gauge.spoken.value,
                            dayReadings: gauge.tab == .week ? dayReadings : [], isRunning: isRunning,
                            behindLand: AnyView(scale(fraction: place.fraction)))
                // Its moon sits on top of the land, as on the board, and fades with the tab too.
                StretchMoon(geometry: arc)
                    .opacity(Double(mix))
                // An invisible marker where the sun sits on Today's arc, for the opening sunrise to glide to.
                // Measured before it is positioned: `position` makes a view as big as its parent, which would report the
                // whole hero as the sun's place.
                Color.clear.frame(width: arc.sunSize, height: arc.sunSize)
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { rect in
                        if mix == 1 { opening?.sunTarget = rect }
                    }
                    .position(onArc)
                    .allowsHitTesting(false)
                // The pill and its dashed line stay in front of the land, so the value can always be read.
                if gauge.tab.hasScale {
                    GaugeMarker(pill: gauge.pill, tab: gauge.tab, fraction: place.fraction, metrics: metrics, onDark: onDark)
                        .transition(.opacity)
                }
            }
        }
        .frame(height: metrics.height)
    }

    /// The scale sits behind the land, as on the boards: its foot and the 0 tick disappear behind the dune. The
    /// sunrise picture turns animations off, so the scale brings back its own fade when the tab changes.
    private func scale(fraction: Double) -> some View {
        ZStack(alignment: .topLeading) {
            if gauge.tab.hasScale {
                GaugeScale(ticks: gauge.ticks, metrics: metrics, onDark: onDark, pillY: metrics.centreY(fraction: fraction))
                    .id(gauge.tab)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .animation(glides ? .easeInOut(duration: 0.3) : nil, value: gauge.tab)
    }
}

/// The scale: a thin line with a tick and a label for each step, on the left.
struct GaugeScale: View {
    let ticks: [GaugeTick]
    var metrics: GaugeMetrics = .standard
    var onDark = false
    /// Where the pill sits: a label it would cover is left out.
    var pillY: CGFloat?

    private var lineColour: Color { onDark ? .white.opacity(0.55) : LGColor.ink.opacity(0.5) }
    private var labelColour: Color { onDark ? .white.opacity(0.85) : LGColor.inkMuted }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Path { p in
                p.move(to: CGPoint(x: metrics.scaleX, y: metrics.topY - metrics.scaleOvershoot))
                p.addLine(to: CGPoint(x: metrics.scaleX, y: metrics.zeroY))
            }
            .stroke(lineColour, lineWidth: 1.2)

            ForEach(ticks, id: \.fraction) { tick in
                let y = metrics.centreY(fraction: tick.fraction)
                let covered = pillY.map { abs($0 - y) < 16 } ?? false
                Path { p in
                    p.move(to: CGPoint(x: metrics.scaleX - 4, y: y))
                    p.addLine(to: CGPoint(x: metrics.scaleX + 4, y: y))
                }
                .stroke(lineColour, lineWidth: 1.2)

                // A zero-height strip at the tick's height, so the label is centred on it at any text size.
                // The labels sit to the right of the line, as on the boards.
                Color.clear.frame(width: 44, height: 0)
                    .overlay(alignment: .leading) {
                        Text(tick.label)
                            .lgText(LGTextStyle(size: 11, weight: .semibold, relativeTo: .caption2), color: labelColour)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .opacity(covered ? 0 : 1)
                    }
                    .offset(x: metrics.scaleX + 10, y: y - 1)
            }
        }
        .accessibilityHidden(true)
    }
}

/// The navy pill with the current value and the dashed gold line from the scale to the sun.
struct GaugeMarker: View {
    let pill: String
    let tab: HomeTab
    let fraction: Double
    var metrics: GaugeMetrics = .standard
    var onDark = false

    var body: some View {
        let y = metrics.centreY(fraction: fraction)
        GeometryReader { geo in
            let sunX = geo.size.width / 2 + metrics.sunOffsetX
            ZStack(alignment: .topLeading) {
                Path { p in
                    p.move(to: CGPoint(x: metrics.dashStartX, y: y))
                    p.addLine(to: CGPoint(x: sunX - metrics.sunSize * 0.365, y: y))
                }
                .stroke(onDark ? Color(hex: 0xFFC56A) : LGColor.finishDash, style: StrokeStyle(lineWidth: 1.5, dash: [3, 4]))

                Color.clear.frame(width: 1, height: 0)
                    .overlay(alignment: .leading) {
                        Text(pill)
                            .id(tab)
                            .transition(.opacity)
                            .lgText(LGTextStyle(size: 13, weight: .bold, relativeTo: .caption), color: onDark ? LGColor.ink : .white)
                            .monospacedDigit()
                            .lineLimit(1)
                            .fixedSize()
                            .padding(.horizontal, 9).padding(.vertical, 4)
                            .background(onDark ? Color.white : LGColor.ink, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .shadow(color: Color(hex: onDark ? 0x0B1029 : 0x16244A, opacity: onDark ? 0.3 : 0.25), radius: 6, y: 4)
                    }
                    .offset(x: metrics.pillX, y: y)
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: Previews (frozen, so the sea can be checked over the sun at every height)

#Preview("Gauge · every height, three wave phases") {
    ScrollView {
        VStack(spacing: 6) {
            ForEach([0.0, 0.04, 0.25, 0.54, 0.8, 1.0], id: \.self) { f in
                ForEach([CGFloat(0), 14, 28], id: \.self) { phase in
                    ZStack(alignment: .topLeading) {
                        SunriseCanvas(layout: .gauge(fraction: f, face: f >= 1 ? .celebrate : .happy), frame: .frozen(phase: phase))
                        GaugeScale(ticks: HomeGauge.week(hours: f * 12, target: 12).ticks)
                        GaugeMarker(pill: DurationFormat.hours(f * 12), tab: .week, fraction: f)
                    }
                    .frame(height: GaugeMetrics.standard.height)
                    .overlay(alignment: .topTrailing) {
                        Text("\(Int(f * 100))% · phase \(Int(phase))").font(.caption2).padding(4)
                    }
                }
            }
        }
    }
    .background(LGColor.background)
}

#Preview("Gauge · This week and The long game") {
    VStack(spacing: 12) {
        GaugeHero(gauge: .week(hours: 6.5, target: 12), fraction: 6.5 / 12)
        GaugeHero(gauge: .longGame(total: 3_294), fraction: 0.3294)
    }
    .background(LGColor.background)
}

#Preview("Gauge · at and above the top") {
    VStack(spacing: 12) {
        GaugeHero(gauge: .week(hours: 13.5, target: 12), fraction: 1, face: .celebrate)
        GaugeHero(gauge: .longGame(total: 10_250), fraction: 1, face: .celebrate)
    }
    .background(LGColor.background)
}

#Preview("Gauge · large Dynamic Type, narrow") {
    GaugeHero(gauge: .longGame(total: 7_500), fraction: 0.75)
        .environment(\.dynamicTypeSize, .xxxLarge)
        .frame(width: 320)
        .background(LGColor.background)
}
