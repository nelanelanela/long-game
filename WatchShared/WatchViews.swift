import SwiftUI
import WidgetKit

// The Apple Watch's pictures: dark and simple, the same sun. They are plain SwiftUI, in a folder both the watch app and
// the iPhone app build, so they can be drawn in tests and previews as well as on the wrist.
//
// The design (design/Watch.dc.html) is for a screen 192 pt wide; the scene scales with the real width.

private enum WatchDesign {
    /// The scene: 192 × 110, the water 88 pt down. The sun's centre is on the water at 0 and 36 pt down at 100%.
    static let sceneRatio: CGFloat = 192 / 110
    static let waterY: CGFloat = 88
    static let topY: CGFloat = 36
    static let sunSize: CGFloat = 64
    static let sunCentreX: CGFloat = 110
    static let scaleX: CGFloat = 14

    static let number = LGTextStyle(size: 26, weight: .bold, relativeTo: .title2, tracking: -0.78)
    static let caption = LGTextStyle(size: 11, weight: .regular, relativeTo: .caption2)
    static let captionStrong = LGTextStyle(size: 11, weight: .semibold, relativeTo: .caption2)
    static let title = LGTextStyle(size: 12, weight: .semibold, relativeTo: .caption)
    static let button = LGTextStyle(size: 13, weight: .semibold, relativeTo: .footnote)
    static let clock = LGTextStyle(size: 38, weight: .light, relativeTo: .largeTitle, tracking: -1.1)
    static let added = LGTextStyle(size: 28, weight: .bold, relativeTo: .title2)
    static let muted = Color.white.opacity(0.65)
}

// MARK: Pieces

/// The sun over the dark sea with a small scale line at the left and a gold tick at the sun's height.
struct WatchScene: View {
    let fraction: Double
    /// At the top the sun opens its eyes.
    let celebrate: Bool

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let s = w / 192
            let sun = WatchDesign.sunSize * s
            let waterY = WatchDesign.waterY * s
            let centre = (WatchDesign.waterY - CGFloat(GaugeGeometry.clamped(fraction)) * (WatchDesign.waterY - WatchDesign.topY)) * s
            let arch = WavePath.defaultArch * w / 390
            let bow = WavePath.defaultBow * s
            ZStack(alignment: .topLeading) {
                Color.clear
                    .frame(width: w, height: geo.size.height)
                    .overlay(alignment: .topLeading) {
                        SunView(face: celebrate ? .celebrate : .happy, rayColor: LGColor.sunRays)
                            .frame(width: sun, height: sun)
                            .offset(x: WatchDesign.sunCentreX * s - sun / 2, y: centre - sun / 2)
                    }
                    .mask { AboveWater(waterY: waterY, phase: 0, arch: arch, bow: bow).fill(Color.black) }
                SeaFill(waterY: waterY, phase: 0, arch: arch, bow: bow).fill(LGColor.watchSea)
                WaveLine(y: waterY, phase: 0, arch: arch, bow: bow)
                    .stroke(LGColor.watchWave, style: StrokeStyle(lineWidth: 2.4 * s, lineCap: .round))
                // The scale: a thin line from the top tick to the water, and a gold tick at the sun's height.
                Path { p in
                    p.move(to: CGPoint(x: WatchDesign.scaleX * s, y: 32 * s))
                    p.addLine(to: CGPoint(x: WatchDesign.scaleX * s, y: waterY))
                }
                .stroke(Color.white.opacity(0.3), lineWidth: 1.5 * s)
                Path { p in
                    p.move(to: CGPoint(x: WatchDesign.scaleX * s, y: centre))
                    p.addLine(to: CGPoint(x: (WatchDesign.scaleX + 6) * s, y: centre))
                }
                .stroke(LGColor.mote, lineWidth: 2 * s)
            }
            .frame(width: w, height: geo.size.height, alignment: .topLeading)
            .clipped()
        }
        .aspectRatio(WatchDesign.sceneRatio, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// A 34 pt pill button: gold (Start, Done), glass (Pause) or white (Finish).
struct WatchPill: View {
    enum Kind { case gold, glass, white }

    let title: LocalizedStringKey
    let kind: Kind
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .lgText(WatchDesign.button, color: kind == .glass ? .white : LGColor.ink)
                .lineLimit(1).minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, minHeight: 34)
                .background(background, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var background: Color {
        switch kind {
        case .gold: LGColor.sunBody
        case .glass: Color.white.opacity(0.16)
        case .white: .white
        }
    }
}

// MARK: Screens

/// One of the two pages: the sun, a small scale, the big number and a line under it. This week also has Start.
struct WatchHomePage: View {
    let tab: HomeTab
    let state: WatchHomeState
    var onStart: (() -> Void)?

    private var gauge: HomeGauge { state.widget.gauge(for: tab) }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch tab {
                case .week: Text("This week")
                case .longGame: Text("The long game")
                }
            }
            .lgText(WatchDesign.title, color: LGColor.mote)
            .padding(.top, 2)

            WatchScene(fraction: gauge.fraction, celebrate: gauge.reachedTop)
                .padding(.top, 2)

            VStack(spacing: 0) {
                Text(verbatim: gauge.pill).lgNumber(WatchDesign.number, color: .white)
                Text(verbatim: tab == .week ? state.weekCaption : state.longGameCaption)
                    .lgText(WatchDesign.caption, color: WatchDesign.muted)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            .padding(.top, 2)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: gauge.description))

            Spacer(minLength: 4)

            if tab == .week, let onStart {
                WatchPill(title: "Start", kind: .gold, action: onStart)
                    .accessibilityHint("Starts a practice session")
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 4)
    }
}

/// The running timer: the focus sun with this hour's lit rays, the clock, the overall total and the next ray.
struct WatchTimerView: View {
    let craftName: String
    let elapsed: TimeInterval
    let paused: Bool
    /// The overall total before this session.
    let baseTotal: Double
    let onPauseOrResume: () -> Void
    let onFinish: () -> Void

    var body: some View {
        let sun = SunHour(elapsed: elapsed)
        VStack(spacing: 0) {
            Text(verbatim: craftName).lgText(WatchDesign.title, color: Color.white.opacity(0.7)).lineLimit(1)
            SunView(face: paused ? .sleepy : .focus, litRays: sun.litRays,
                    glowingRay: paused || sun.litRays >= 12 ? nil : sun.litRays,
                    raysOpacity: paused ? 0.4 : 1, rayColor: LGColor.sunRaysBright)
                .frame(width: 76, height: 76)
                .padding(.top, 2)
                .accessibilityHidden(true)
            VStack(spacing: 0) {
                Text(verbatim: DurationFormat.clock(seconds: elapsed)).lgNumber(WatchDesign.clock, color: .white)
                Text(verbatim: WatchModel.timerLine(baseTotal: baseTotal, elapsed: elapsed))
                    .lgText(WatchDesign.captionStrong, color: LGColor.mote)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("\(Labels.spoken(seconds: Int(elapsed), includeSeconds: true)) this session. \(sun.rayAnnouncement)."))
            Spacer(minLength: 4)
            HStack(spacing: 8) {
                WatchPill(title: paused ? "Resume" : "Pause", kind: .glass, action: onPauseOrResume)
                WatchPill(title: "Finish", kind: .white, action: onFinish)
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 4)
    }
}

/// After Finish: the happy sun, the time added and where this week stands.
struct WatchFinishedView: View {
    let added: String
    let caption: String
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text("Session saved").lgText(WatchDesign.button, color: .white).padding(.top, 2)
            SunView(face: .happy, rayColor: LGColor.sunRaysBright)
                .frame(width: 80, height: 80)
                .padding(.top, 4)
                .accessibilityHidden(true)
            VStack(spacing: 0) {
                Text(verbatim: added).lgNumber(WatchDesign.added, color: .white)
                Text(verbatim: caption).lgText(WatchDesign.caption, color: WatchDesign.muted).lineLimit(1).minimumScaleFactor(0.7)
            }
            .padding(.top, 4)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Session saved. \(added) added. \(caption)."))
            Spacer(minLength: 4)
            WatchPill(title: "Done", kind: .gold, action: onDone)
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 4)
    }
}

/// The watch has no onboarding: until the phone has been set up it says so.
struct WatchSetupView: View {
    var body: some View {
        VStack(spacing: 8) {
            SunView(face: .sleepy, rayColor: LGColor.sunRaysBright)
                .frame(width: 64, height: 64)
                .accessibilityHidden(true)
            Text("Set up Long Game on your iPhone first.")
                .lgText(WatchDesign.button, color: .white)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 12)
        .accessibilityElement(children: .combine)
    }
}

// MARK: Complications

/// A ring that fills with this week's hours, the sun inside.
struct WatchCircularView: View {
    let state: WidgetState

    var body: some View {
        Gauge(value: state.week.fraction) {
            Text("Hours this week")
        } currentValueLabel: {
            Image(systemName: "sun.max.fill")
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .tint(LGColor.sunBody)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("This week, \(WeeklyTarget.number(state.weekHours)) of \(WeeklyTarget.number(state.weekTarget)) hours"))
    }
}

/// The sun, "6.5 / 12 h this week" and a bar.
struct WatchRectangularView: View {
    let state: WidgetState

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "sun.max.fill")
                .font(.title3)
                .foregroundStyle(LGColor.sunBody)
                .widgetAccentable()
            VStack(alignment: .leading, spacing: 4) {
                Text("\(WeeklyTarget.number(state.weekHours)) / \(WeeklyTarget.number(state.weekTarget)) h this week")
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1).minimumScaleFactor(0.7)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(LGColor.sunBody.opacity(0.25))
                        Capsule().fill(LGColor.sunBody)
                            .frame(width: max(4, geo.size.width * GaugeGeometry.clamped(state.week.fraction)))
                    }
                }
                .frame(height: 4)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("This week, \(WeeklyTarget.number(state.weekHours)) of \(WeeklyTarget.number(state.weekTarget)) hours"))
    }
}

/// "6.5h", for the corner and the inline slot.
struct WatchHoursText: View {
    let state: WidgetState

    var body: some View {
        Text(verbatim: DurationFormat.hours(state.weekHours).replacingOccurrences(of: " ", with: ""))
            .accessibilityLabel(Text("\(WeeklyTarget.number(state.weekHours)) hours this week"))
    }
}
