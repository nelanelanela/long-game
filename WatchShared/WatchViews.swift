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
            let h = geo.size.height
            let landHeight = (h - waterY) / (1 - 46.0 / 120)
            let landTop = waterY - landHeight * 46 / 120
            ZStack(alignment: .topLeading) {
                SkyView(tone: .night, horizon: waterY / h, moon: false)
                    .frame(width: w, height: h)
                SunView(idle: false, face: celebrate ? .celebrate : .happy, rayColor: LGColor.sunRays)
                    .frame(width: sun, height: sun)
                    .offset(x: WatchDesign.sunCentreX * s - sun / 2, y: centre - sun / 2)
                // The night sea in front of the sun, opaque.
                LandView(tone: .night, still: true)
                    .frame(width: w, height: landHeight)
                    .offset(y: landTop)
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
                case .week, .today: Text("This week")
                case .longGame: Text("The long game")
                }
            }
            .lgText(WatchDesign.title, color: LGColor.mote)
            .padding(.top, 2)

            WatchScene(fraction: gauge.fraction, celebrate: gauge.reachedTop)
                .padding(.top, 2)

            VStack(spacing: 0) {
                Text(verbatim: gauge.pill).lgNumber(WatchDesign.number, color: .white)
                Text(verbatim: tab != .longGame ? state.weekCaption : state.longGameCaption)
                    .lgText(WatchDesign.caption, color: WatchDesign.muted)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            .padding(.top, 2)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: gauge.description))

            Spacer(minLength: 4)

            if tab != .longGame, let onStart {
                WatchPill(title: "Start", kind: .gold, action: onStart)
                    .accessibilityHint("Starts a practice session")
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 4)
    }
}

/// The Watch's sunrise: today's progress `p` moves the sun from the sea up through night, dawn and day. Pure numbers,
/// so the tests can check them.
enum WatchSunrise {
    /// The sun's centre as a fraction of the scene's height: on the water at 0, a third down at 1.
    static let waterFraction: CGFloat = 0.74
    static let topFraction: CGFloat = 0.28

    /// Reduce Motion (and Always On): the sun only moves once a minute, so use whole minutes of the session.
    static func steppedElapsed(_ elapsed: TimeInterval) -> TimeInterval { (elapsed / 60).rounded(.down) * 60 }

    static func progress(doneToday: TimeInterval, elapsed: TimeInterval, stretch: TimeInterval?, stepped: Bool) -> Double {
        TimerSunrise.progress(doneSaved: doneToday, running: stepped ? steppedElapsed(elapsed) : elapsed, target: stretch)
    }

    static func centreFraction(p: Double, paused: Bool) -> CGFloat {
        let base = waterFraction - (waterFraction - topFraction) * CGFloat(TimerSunrise.clamp(p))
        return base + (paused ? 0.05 : 0)
    }

    /// The sky dims when the wrist is down.
    static func dimming(alwaysOn: Bool) -> Double { alwaysOn ? 0.45 : 1 }
}

/// The running timer: the same sunrise as the phone's Timer, small. The sky and land fill the screen, today's total
/// and the clock sit on it, then a progress bar, Pause and Finish.
struct WatchTimerView: View {
    let craftName: String
    let elapsed: TimeInterval
    let paused: Bool
    /// The overall total before this session.
    let baseTotal: Double
    /// Time saved today before this session, and today's stretch (nil when no pace is chosen).
    var doneToday: TimeInterval = 0
    var stretch: TimeInterval?
    let onPauseOrResume: () -> Void
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isLuminanceReduced) private var alwaysOn

    var body: some View {
        let stepped = reduceMotion || alwaysOn
        let p = WatchSunrise.progress(doneToday: doneToday, elapsed: elapsed, stretch: stretch, stepped: stepped)
        let covered = p >= 1
        let palette = TimerPalette(p: p)
        ZStack {
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                let waterY = h * 0.62
                let centre = WatchSunrise.centreFraction(p: p, paused: paused || alwaysOn) * waterY / WatchSunrise.waterFraction
                let sun: CGFloat = 70
                ZStack(alignment: .topLeading) {
                    TimerSunriseSky(p: p, paused: paused, horizonY: waterY, sunCentre: CGPoint(x: w / 2, y: centre))
                    SunView(idle: false, face: alwaysOn || paused ? .sleepy : (covered ? .happy : .focus),
                            litRays: 12, raysOpacity: paused ? 0.4 : 1, rayColor: LGColor.sunRaysBright)
                        .frame(width: sun, height: sun)
                        .position(x: w / 2, y: centre)
                    TimerSunriseLand(p: p, horizonY: waterY)
                }
                .frame(width: w, height: h)
                .opacity(WatchSunrise.dimming(alwaysOn: alwaysOn))
            }
            .ignoresSafeArea()
            .accessibilityHidden(true)

            VStack(spacing: 0) {
                HStack {
                    Text(verbatim: craftName).lgText(WatchDesign.title, color: palette.muted).lineLimit(1)
                    Spacer(minLength: 4)
                    Text(Date.now, format: .dateTime.hour().minute())
                        .lgText(WatchDesign.caption, color: palette.muted)
                }
                Spacer(minLength: 0)
                VStack(spacing: 0) {
                    Text(verbatim: alwaysOn ? DurationFormat.hoursMinutes(seconds: elapsed) : DurationFormat.clock(seconds: elapsed))
                        .lgNumber(WatchDesign.clock, color: palette.ink)
                    Text(verbatim: WatchModel.todayLine(doneToday: doneToday + elapsed, stretch: stretch))
                        .lgText(WatchDesign.captionStrong, color: covered ? palette.covered : palette.gold)
                        .lineLimit(1).minimumScaleFactor(0.7)
                    Capsule().fill(palette.track).frame(height: 4)
                        .overlay(alignment: .leading) {
                            GeometryReader { g in
                                Capsule().fill(palette.gold).frame(width: max(4, g.size.width * p))
                            }
                        }
                        .padding(.horizontal, 20).padding(.top, 4)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("\(Labels.spoken(seconds: Int(elapsed), includeSeconds: !alwaysOn)) this session. \(WatchModel.todayLine(doneToday: doneToday + elapsed, stretch: stretch))."))
                if !alwaysOn {
                    HStack(spacing: 8) {
                        WatchPill(title: paused ? "Resume" : "Pause", kind: .glass, action: onPauseOrResume)
                        WatchPill(title: "Finish", kind: .white, action: onFinish)
                    }
                    .padding(.top, 6)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 4)
        }
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
            SunView(idle: false, face: .happy, rayColor: LGColor.sunRaysBright)
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
            SunView(idle: false, face: .sleepy, rayColor: LGColor.sunRaysBright)
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
