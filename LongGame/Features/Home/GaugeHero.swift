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
    /// The hero's size: the phone's by default, smaller or wider for other windows.
    var metrics: GaugeMetrics = .standard
    /// The final values, for Reduce Motion (they are used instead of the interpolated ones).
    var final: Place?
    /// This week only: one line per day, read when VoiceOver users swipe up or down on the sun.
    var dayReadings: [String] = []

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
                // Today's arc and moon sit behind the sea and the sun, and fade with the tab.
                StretchArcLayer(geometry: arc, fraction: place.arcFraction)
                    .opacity(Double(mix))
                SunriseHero(layout: .placed(centre: centre, width: width, sunSize: size, face: face, metrics: metrics),
                            label: gauge.spoken.label, value: gauge.spoken.value,
                            dayReadings: gauge.tab == .week ? dayReadings : [], isRunning: isRunning)
                if gauge.tab.hasScale {
                    GaugeScale(ticks: gauge.ticks, metrics: metrics)
                        .id(gauge.tab)
                        .transition(.opacity)
                    GaugeMarker(pill: gauge.pill, tab: gauge.tab, fraction: place.fraction, metrics: metrics)
                        .transition(.opacity)
                }
            }
        }
        .frame(height: metrics.height)
    }
}

/// The scale: a thin line with a tick and a label for each step, on the left.
struct GaugeScale: View {
    let ticks: [GaugeTick]
    var metrics: GaugeMetrics = .standard

    var body: some View {
        ZStack(alignment: .topLeading) {
            Path { p in
                p.move(to: CGPoint(x: metrics.scaleX, y: metrics.topY - metrics.scaleOvershoot))
                p.addLine(to: CGPoint(x: metrics.scaleX, y: metrics.zeroY))
            }
            .stroke(LGColor.gaugeLine, lineWidth: 1.5)

            ForEach(ticks, id: \.fraction) { tick in
                let y = metrics.centreY(fraction: tick.fraction)
                Path { p in
                    p.move(to: CGPoint(x: metrics.scaleX - 4, y: y))
                    p.addLine(to: CGPoint(x: metrics.scaleX + 4, y: y))
                }
                .stroke(LGColor.gaugeLine, lineWidth: 1.5)

                // A zero-height strip at the tick's height, so the label is centred on it at any text size.
                Color.clear.frame(width: 36, height: 0)
                    .overlay(alignment: .trailing) {
                        Text(tick.label)
                            .lgText(.tiny, color: LGColor.gaugeLabel)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .offset(x: 4, y: y)
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

    var body: some View {
        let y = metrics.centreY(fraction: fraction)
        GeometryReader { geo in
            let sunX = geo.size.width / 2 + metrics.sunOffsetX
            ZStack(alignment: .topLeading) {
                Path { p in
                    p.move(to: CGPoint(x: metrics.dashStartX, y: y))
                    p.addLine(to: CGPoint(x: sunX - metrics.sunSize * 0.365, y: y))
                }
                .stroke(LGColor.finishDash, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))

                Color.clear.frame(width: 1, height: 0)
                    .overlay(alignment: .leading) {
                        Text(pill)
                            .id(tab)
                            .transition(.opacity)
                            .lgText(LGTextStyle(size: 12, weight: .semibold, relativeTo: .caption), color: .white)
                            .monospacedDigit()
                            .lineLimit(1)
                            .fixedSize()
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(LGColor.ink, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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
