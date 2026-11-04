import SwiftUI

// The widgets' pictures. They live here, in the folder both the app and the extension build, so they can be drawn in
// tests and previews as well as on the Home Screen. No animation (widgets can't): the sun is drawn at its current
// height with the opaque sea in front of it, exactly as on Home.
//
// The design (design/Widgets.dc.html) is for a widget 170 pt tall. Every size below is in those design points and is
// scaled by `height / 170`, so the layout fits whatever size the phone gives the widget.

private enum Design {
    static let height: CGFloat = 170
    static let mediumSceneWidth: CGFloat = 150

    static let number = LGTextStyle(size: 24, weight: .bold, relativeTo: .title2, tracking: -0.72)
    static let caption = LGTextStyle(size: 12, weight: .regular, relativeTo: .caption)
    static let captionStrong = LGTextStyle(size: 12, weight: .semibold, relativeTo: .caption)
    static let title = LGTextStyle(size: 14, weight: .bold, relativeTo: .subheadline)
}

struct SceneSpec {
    var height: CGFloat
    var sunSize: CGFloat
    var waterY: CGFloat
    /// The sun's centre at 0 and at 100% (the top tick).
    var zeroY: CGFloat
    var topY: CGFloat

    /// Small: the scene is the top 112 pt; the sun is 62 pt wide, 6 pt below the water at 0 and 32 pt from the top at 100%.
    static let small = SceneSpec(height: 112, sunSize: 62, waterY: 82, zeroY: 88, topY: 32)
    /// Medium: the scene is the whole left column, 150 pt wide.
    static let medium = SceneSpec(height: 170, sunSize: 80, waterY: 140, zeroY: 148, topY: 40)
}

/// The sun rising out of the sea, still. The sun is masked to the area above the wave path and the sea is one opaque
/// shape whose top edge is that same path, so no part of the sun can show below the waterline.
struct WidgetScene: View {
    let fraction: Double
    /// At the top the sun opens its eyes.
    let celebrate: Bool
    let spec: SceneSpec
    /// Real widget height ÷ 170.
    let scale: CGFloat

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = spec.height * scale
            let sun = spec.sunSize * scale
            // The design's wave is 390 wide squeezed into the scene's width; its height is not squeezed.
            let arch = WavePath.defaultArch * w / 390
            let bow = WavePath.defaultBow * scale
            let waterY = spec.waterY * scale
            let centre = (spec.zeroY - CGFloat(GaugeGeometry.clamped(fraction)) * (spec.zeroY - spec.topY)) * scale
            ZStack(alignment: .topLeading) {
                Color.clear
                    .frame(width: w, height: h)
                    .overlay(alignment: .topLeading) {
                        SunView(face: celebrate ? .celebrate : .happy, rayColor: LGColor.sunRays)
                            .frame(width: sun, height: sun)
                            .offset(x: (w - sun) / 2, y: centre - sun / 2)
                    }
                    .mask { AboveWater(waterY: waterY, phase: 0, arch: arch, bow: bow).fill(Color.black) }
                SeaFill(waterY: waterY, phase: 0, arch: arch, bow: bow).fill(LGColor.seaFill)
                WaveLine(y: waterY + 14 * scale, phase: 10 * w / 390, arch: arch, bow: bow)
                    .stroke(LGColor.seaWave, style: StrokeStyle(lineWidth: 2.2 * scale, lineCap: .round))
                WaveLine(y: waterY, phase: 0, arch: arch, bow: bow)
                    .stroke(LGColor.ink, style: StrokeStyle(lineWidth: 2.2 * scale, lineCap: .round))
            }
            .frame(width: w, height: h, alignment: .topLeading)
            .clipped()
        }
        .frame(height: spec.height * scale)
        .accessibilityHidden(true)
    }
}

// MARK: Home Screen

/// Small: the sun over the sea at the right height, with "6.5 h / of 12 h this week" or "3,294 h / of 10,000 · 33%".
struct SmallSunWidgetView: View {
    let state: WidgetState
    let tab: HomeTab

    var body: some View {
        GeometryReader { geo in
            let s = geo.size.height / Design.height
            let gauge = state.gauge(for: tab)
            ZStack(alignment: .bottomLeading) {
                WidgetScene(fraction: gauge.fraction, celebrate: gauge.reachedTop, spec: .small, scale: s)
                    .frame(maxHeight: .infinity, alignment: .top)
                VStack(alignment: .leading, spacing: 1) {
                    Text(verbatim: gauge.pill)
                        .lgText(Design.number)
                        .lineLimit(1).minimumScaleFactor(0.6)
                    caption
                        .lgText(Design.caption, color: LGColor.inkMuted)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
                .padding(.horizontal, 14 * s)
                .padding(.bottom, 12 * s)
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }

    private var caption: Text {
        switch tab {
        case .week, .today: Text("of \(DurationFormat.hours(state.weekTarget)) this week")
        case .longGame: Text("of 10,000 · \(state.longGamePercent)%")
        }
    }

    private var label: Text {
        switch tab {
        case .week, .today: Text("This week, \(WeeklyTarget.number(state.weekHours)) of \(WeeklyTarget.number(state.weekTarget)) hours")
        case .longGame: Text("The long game, \(DurationFormat.grouped(Totals.wholeHours(total: state.total))) of 10,000 hours, \(state.longGamePercent)%")
        }
    }
}

/// Medium: this week's sun on the left; on the right the craft, today's time and two bars, gold for this week against
/// the target and navy for the long game against 10,000 hours.
struct MediumSunWidgetView: View {
    let state: WidgetState

    var body: some View {
        GeometryReader { geo in
            let s = geo.size.height / Design.height
            HStack(spacing: 0) {
                WidgetScene(fraction: state.week.fraction, celebrate: state.week.reachedTop, spec: .medium, scale: s)
                    .frame(width: Design.mediumSceneWidth * s)
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(verbatim: state.craftName)
                            .lgText(Design.title)
                            .lineLimit(1)
                        Spacer(minLength: 6)
                        Text("Today \(DurationFormat.short(seconds: state.todaySeconds))")
                            .lgText(Design.caption, color: LGColor.inkMuted)
                            .lineLimit(1).minimumScaleFactor(0.7)
                    }
                    Spacer(minLength: 4)
                    bar("This week", "\(WeeklyTarget.number(state.weekHours)) / \(WeeklyTarget.number(state.weekTarget)) h",
                        fraction: state.week.fraction, color: LGColor.sunRays)
                    Spacer(minLength: 4)
                    bar("The long game", "\(DurationFormat.grouped(Totals.wholeHours(total: state.total))) / 10,000 h",
                        fraction: state.longGame.fraction, color: LGColor.ink)
                        .widgetLink(to: .longGame)
                }
                .padding(.top, 16 * s).padding(.bottom, 14 * s).padding(.leading, 4 * s).padding(.trailing, 18 * s)
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(state.craftName). Today \(DurationFormat.short(seconds: state.todaySeconds)). This week \(WeeklyTarget.number(state.weekHours)) of \(WeeklyTarget.number(state.weekTarget)) hours. The long game \(DurationFormat.grouped(Totals.wholeHours(total: state.total))) of 10,000 hours."))
    }

    private func bar(_ title: LocalizedStringKey, _ value: String, fraction: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).lgText(Design.captionStrong).lineLimit(1).minimumScaleFactor(0.7)
                Spacer(minLength: 4)
                Text(verbatim: value).lgText(Design.caption, color: LGColor.inkMuted).lineLimit(1).minimumScaleFactor(0.7)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(LGColor.track)
                    Capsule().fill(color).frame(width: max(6, geo.size.width * GaugeGeometry.clamped(fraction)))
                }
            }
            .frame(height: 6)
        }
    }
}

private extension View {
    /// Tapping this part opens Home on the other tab (a widget's own link covers the rest).
    @ViewBuilder
    func widgetLink(to tab: HomeTab) -> some View {
        Link(destination: WidgetLink.url(for: tab)) { self }
    }
}

/// Before the app has been set up (or the shared data isn't there yet).
struct SetupWidgetView: View {
    var body: some View {
        GeometryReader { geo in
            let s = geo.size.height / Design.height
            ZStack(alignment: .bottomLeading) {
                WidgetScene(fraction: 0, celebrate: false, spec: .small, scale: s)
                    .frame(maxHeight: .infinity, alignment: .top)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Set up Long Game").lgText(LGTextStyle(size: 16, weight: .bold, relativeTo: .headline, tracking: -0.3))
                        .lineLimit(2).minimumScaleFactor(0.7)
                    Text("Open the app to begin.").lgText(Design.caption, color: LGColor.inkMuted)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
                .padding(.horizontal, 14 * s).padding(.bottom, 12 * s)
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
    }
}

// MARK: Lock Screen

/// A ring that fills with this week's hours against the target, the sun inside. Follows the Lock Screen tint.
struct CircularSunWidgetView: View {
    let state: WidgetState

    var body: some View {
        Gauge(value: state.week.fraction) {
            Text("Hours this week")
        } currentValueLabel: {
            Image(systemName: "sun.max.fill")
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("This week, \(WeeklyTarget.number(state.weekHours)) of \(WeeklyTarget.number(state.weekTarget)) hours"))
    }
}

/// "6.5 of 12 h this week", a bar, and the long-game total.
struct RectangularSunWidgetView: View {
    let state: WidgetState

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Label {
                Text("\(WeeklyTarget.number(state.weekHours)) of \(WeeklyTarget.number(state.weekTarget)) h this week")
                    .fontWeight(.semibold)
            } icon: {
                Image(systemName: "sun.max.fill")
            }
            .font(.footnote)
            .lineLimit(1).minimumScaleFactor(0.8)
            // A drawn bar (not ProgressView), so it follows the Lock Screen tint and looks the same everywhere.
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.primary.opacity(0.25))
                    Capsule().fill(.primary)
                        .frame(width: max(5, geo.size.width * GaugeGeometry.clamped(state.week.fraction)))
                        .widgetAccentable()
                }
            }
            .frame(height: 5)
            Text("\(DurationFormat.grouped(Totals.wholeHours(total: state.total))) h · \(state.longGamePercent)% of the long game")
                .font(.caption2)
                .lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("This week, \(WeeklyTarget.number(state.weekHours)) of \(WeeklyTarget.number(state.weekTarget)) hours. The long game, \(DurationFormat.grouped(Totals.wholeHours(total: state.total))) hours, \(state.longGamePercent)%."))
    }
}

/// "☀ 6.5 of 12 h"
struct InlineSunWidgetView: View {
    let state: WidgetState

    var body: some View {
        Label("\(WeeklyTarget.number(state.weekHours)) of \(WeeklyTarget.number(state.weekTarget)) h", systemImage: "sun.max.fill")
    }
}
