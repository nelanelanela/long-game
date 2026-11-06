import SwiftUI
import Charts
import Accessibility

/// The Growth chart, full screen: drag a finger along the line from the first hour to the finish and feel a light tap
/// at each milestone. Opened from the Growth card; closed with the ✕ or a swipe down.
struct GrowthScrubView: View {
    let craftName: String
    let past: [CumulativePoint]
    let data: GrowthChartData
    let forecast: Forecast
    let total: Double
    let onboardingDate: Date
    let now: Date
    /// Whether the hint "Drag along the line" was already put away by an earlier scrub.
    let hintSeen: Bool
    let onHintSeen: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var selection: Date?
    /// What the headline and the dot show; it lingers 1.5 s after the finger lifts.
    @State private var scrubDate: Date?
    @State private var tracker: GrowthScrub.Tracker
    @State private var activeMilestone: Int?
    @State private var ticks = 0
    @State private var ring: (index: Int, progress: Double)?
    @State private var holdTask: Task<Void, Never>?
    @State private var hasScrubbed = false
    @State private var stopIndex = 0
    // The draw-in.
    @State private var draw: DrawProgress
    @State private var sunScale: CGFloat
    @State private var fade: Double

    private let milestones: [ScrubMilestone]
    private let range: ClosedRange<Date>

    init(craftName: String, past: [CumulativePoint], data: GrowthChartData, forecast: Forecast, total: Double,
         onboardingDate: Date, now: Date, hintSeen: Bool, onHintSeen: @escaping () -> Void, drawn: Bool = false, startingAt: Date? = nil) {
        self.craftName = craftName
        self.past = past
        self.data = data
        self.forecast = forecast
        self.total = total
        self.onboardingDate = onboardingDate
        self.now = now
        self.hintSeen = hintSeen
        self.onHintSeen = onHintSeen
        let ms = GrowthScrub.milestoneDates(past: past, forecast: forecast.chosen, onboardingDate: onboardingDate, now: now)
        let span = GrowthScrub.range(past: past, forecast: forecast.chosen, now: now)
        milestones = ms
        range = span
        // Close enough to count as "still on it": 2% of the line.
        _tracker = State(initialValue: GrowthScrub.Tracker(milestones: ms, now: now, range: span,
                                                           tolerance: span.upperBound.timeIntervalSince(span.lowerBound) * 0.02))
        _scrubDate = State(initialValue: startingAt)
        _draw = State(initialValue: drawn ? .complete : .empty)
        _sunScale = State(initialValue: drawn ? 1 : 0)
        _fade = State(initialValue: drawn ? 1 : 0)
    }

    // MARK: What is shown

    private var snappedIndex: Int? { scrubDate.flatMap { tracker.milestone(near: $0) } }

    /// The dot sits on the curve, or exactly on the milestone it is close to.
    private var point: ScrubPoint? {
        guard let scrubDate else { return nil }
        let at = snappedIndex.map { milestones[$0].date } ?? scrubDate
        return GrowthScrub.curvePoint(at: at, past: past, forecast: forecast.chosen, onboardingDate: onboardingDate, now: now)
    }

    private var readout: ScrubReadout? {
        point.map { ScrubText.readout(for: $0, milestone: snappedIndex.map { milestones[$0] }) }
    }

    private var idleHeadline: ScrubReadout {
        ScrubReadout(small: String(localized: "At your chosen pace, you'll finish around"),
                     big: ForecastText.headline(forecast.chosen, now: now),
                     accent: ForecastText.actualLine(forecast, now: now), chip: "", blurb: "", date: "", hours: "")
    }

    // MARK: Body

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width > geo.size.height
            VStack(spacing: 0) {
                top
                if wide {
                    HStack(alignment: .top, spacing: 8) {
                        VStack(alignment: .leading, spacing: 10) {
                            headline
                            key
                        }
                        .frame(width: min(320, geo.size.width * 0.36))
                        chartArea
                    }
                } else {
                    headline
                    key.padding(.top, 10)
                    chartArea.padding(.top, 14)
                }
                hint
            }
            .padding(.top, 8)
        }
        .background(Color.white.ignoresSafeArea())
        .sensoryFeedback(trigger: activeMilestone) { _, new in new == nil ? nil : .impact(weight: .light) }
        .sensoryFeedback(.selection, trigger: ticks)
        .onChange(of: selection) { _, new in scrub(to: new) }
        .task { await drawIn() }
    }

    private var top: some View {
        HStack {
            Text("\(craftName) · the long game").lgText(.rowStrong)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(LGColor.ink)
                    .frame(width: 40, height: 40)
                    .background(LGColor.segmentTrack, in: Circle())
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Close chart")
        }
        .padding(.horizontal, 20)
        .frame(height: 44)
        .contentShape(Rectangle())
        .gesture(swipeDown)
    }

    /// A swipe down on the top of the screen closes the chart (the chart itself belongs to the scrubbing finger).
    private var swipeDown: some Gesture {
        DragGesture(minimumDistance: 30).onEnded { if $0.translation.height > 80 { dismiss() } }
    }

    private var headline: some View {
        let r = readout ?? idleHeadline
        return VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: r.small).lgText(LGTextStyle(size: 14, weight: .regular, relativeTo: .subheadline), color: LGColor.inkMuted)
            Text(verbatim: r.big)
                .lgText(LGTextStyle(size: 30, weight: .bold, relativeTo: .title, tracking: -0.6))
                .lineLimit(1).minimumScaleFactor(0.5)
            Text(verbatim: r.accent.isEmpty ? " " : r.accent)
                .lgText(.caption, color: r.accent.hasPrefix("Milestone") || r.accent == "The finish line" ? LGColor.forecast : LGColor.inkMuted)
        }
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
        .padding(.horizontal, 24).padding(.top, 18)
        .contentShape(Rectangle())
        .gesture(swipeDown)
        .accessibilityElement(children: .combine)
    }

    /// Names the two forecast lines, which carry no text of their own.
    @ViewBuilder
    private var key: some View {
        if total < Totals.goalHours {
            GrowthKey(forecast: forecast, now: now, style: .full).padding(.horizontal, 24)
        }
    }

    private var chartArea: some View {
        GrowthChartView(data: data, total: total, now: now, style: .full, milestones: milestones, scrubPoint: point,
                        selection: $selection, sunScale: sunScale, draw: draw, ring: ring, floatingLabel: readout)
            .opacity(reduceMotion ? fade : 1)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Growth chart")
            .accessibilityValue(readout?.spoken ?? GrowthText.chartLabel(total: total, forecast: forecast, now: now))
            .accessibilityHint("Swipe up or down to step through your milestones")
            .accessibilityAdjustableAction { direction in step(direction == .increment ? 1 : -1) }
            .accessibilityChartDescriptor(GrowthChartDescriptor(past: data.past, chosen: data.chosen, actual: data.actual, now: now))
    }

    /// The hint sits in a fixed-height slot, so the chart does not jump when it goes away.
    private var hint: some View {
        ZStack {
            if !hintSeen && !hasScrubbed {
                Text("Drag along the line")
                    .lgText(LGTextStyle(size: 13, weight: .medium, relativeTo: .footnote), color: LGColor.inkMuted)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(LGColor.segmentTrack, in: Capsule())
                    .transition(.opacity)
            }
        }
        .frame(height: 62)
    }

    // MARK: Scrubbing

    private func scrub(to new: Date?) {
        if let new {
            holdTask?.cancel()
            if !hasScrubbed {
                withAnimation(.easeOut(duration: 0.2)) { hasScrubbed = true }
                onHintSeen()
            }
            let event = tracker.move(to: new)
            activeMilestone = tracker.active
            switch event {
            case .milestone(let i):
                ring = (i, 0)
                withAnimation(.easeOut(duration: 0.4)) { ring = (i, 1) }
            case .tick:
                ticks += 1
            case nil:
                break
            }
            scrubDate = min(max(new, range.lowerBound), range.upperBound)
        } else {
            tracker.end()
            activeMilestone = nil
            holdTask = Task {
                try? await Task.sleep(for: .seconds(1.5))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.3)) { scrubDate = nil }
            }
        }
    }

    /// VoiceOver: swipe up or down to step Start → each milestone → Today → Finish line.
    private func step(_ delta: Int) {
        let stops = ScrubText.stops(milestones: milestones, range: range, now: now)
        stopIndex = min(max(stopIndex + delta, 0), stops.count - 1)
        holdTask?.cancel()
        scrubDate = stops[stopIndex].date
        if let r = readout { AccessibilityNotification.Announcement(r.spoken).post() }
    }

    // MARK: Draw-in

    /// The past line draws left to right (0.8 s, ease-out), then the dashed chosen-pace line (0.5 s), the dotted
    /// actual-pace line (0.3 s) and the sun pops onto the finish with a small bounce. Reduce Motion: a 0.2 s fade.
    private func drawIn() async {
        guard draw != .complete else { return }
        if reduceMotion {
            draw = .complete
            withAnimation(.easeOut(duration: 0.2)) { fade = 1; sunScale = 1 }
            return
        }
        let start = Date()
        while true {
            let t = Date().timeIntervalSince(start)
            if t >= DrawProgress.total { break }
            draw = DrawProgress.at(t)
            try? await Task.sleep(for: .milliseconds(16))
            if Task.isCancelled { return }
        }
        draw = .complete
        withAnimation(.spring(duration: 0.45, bounce: 0.5)) { sunScale = 1 }
    }
}

/// The Audio Graph: the past, and the chosen-pace and actual-pace lines, as lines of hours over the years.
struct GrowthChartDescriptor: AXChartDescriptorRepresentable {
    let past: [CumulativePoint]
    let chosen: [CumulativePoint]
    let actual: [CumulativePoint]
    let now: Date

    private static func year(_ date: Date) -> Double {
        2000 + date.timeIntervalSince(Date(timeIntervalSince1970: 946_684_800)) / (365.25 * 86_400)
    }

    func makeChartDescriptor() -> AXChartDescriptor {
        let all = past + chosen + actual
        let years = all.map { Self.year($0.date) }
        let x = AXNumericDataAxisDescriptor(title: String(localized: "Year"), range: (years.min() ?? 2000)...(years.max() ?? 2001),
                                            gridlinePositions: []) { String(Int($0.rounded())) }
        let y = AXNumericDataAxisDescriptor(title: String(localized: "Hours"), range: 0...Totals.goalHours,
                                            gridlinePositions: [2_500, 5_000, 7_500, 10_000]) { "\(Int($0.rounded())) hours" }
        func series(_ name: String, _ points: [CumulativePoint]) -> AXDataSeriesDescriptor {
            AXDataSeriesDescriptor(name: name, isContinuous: true,
                                   dataPoints: points.map { AXDataPoint(x: Self.year($0.date), y: $0.hours) })
        }
        return AXChartDescriptor(title: String(localized: "Hours played, and the two paces to 10,000 hours"), summary: nil,
                                 xAxis: x, yAxis: y, additionalAxes: [],
                                 series: [series(String(localized: "Played"), past),
                                          series(String(localized: "At your chosen pace"), chosen),
                                          series(String(localized: "At your actual pace"), actual)])
    }
}

// MARK: Previews (drawn already, so each frame can be inspected)

#if DEBUG
private enum ScrubPreviewData {
    static let now = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 4))!

    static func make(perMonth: Double = 60, startingAt: (Date, [ScrubMilestone], GrowthChartData) -> Date?) -> some View {
        let cal = Calendar.current
        func date(_ y: Int, _ m: Int) -> Date { cal.date(from: DateComponents(year: y, month: m, day: 1))! }
        let past = [CumulativePoint(date: date(2018, 1), hours: 0), CumulativePoint(date: date(2020, 1), hours: 900),
                    CumulativePoint(date: date(2023, 1), hours: 2_300), CumulativePoint(date: date(2025, 6), hours: 2_900),
                    CumulativePoint(date: now, hours: 3_294)]
        let rate = perMonth * 7 / ForecastEngine.daysPerMonth
        let forecast = ForecastEngine.forecast(total: 3_294, chosenPace: rate, actualPace: rate * 0.6)
        let mid = forecast.chosen
        let data = GrowthSeries.chartData(forecast: forecast, past: past, now: now)
        let onboarding = date(2024, 1)
        let ms = GrowthScrub.milestoneDates(past: past, forecast: mid, onboardingDate: onboarding, now: now)
        return GrowthScrubView(craftName: "Piano", past: past, data: data, forecast: forecast, total: 3_294,
                               onboardingDate: onboarding, now: now, hintSeen: false, onHintSeen: {}, drawn: true,
                               startingAt: startingAt(now, ms, data))
    }
}

#Preview("Portrait · idle") { ScrubPreviewData.make { _, _, _ in nil } }
#Preview("Portrait · past milestone (2,500 h)") { ScrubPreviewData.make { _, ms, _ in ms.first { $0.hours == 2_500 }?.date } }
#Preview("Portrait · Today") { ScrubPreviewData.make { now, _, _ in now } }
#Preview("Portrait · future milestone (5,000 h)") { ScrubPreviewData.make { _, ms, _ in ms.first { $0.hours == 5_000 }?.date } }
#Preview("Portrait · not within 30 years") { ScrubPreviewData.make(perMonth: 15) { now, _, _ in now.addingTimeInterval(86_400 * 365 * 12) } }
#Preview("Landscape", traits: .landscapeLeft) { ScrubPreviewData.make { _, ms, _ in ms.first { $0.hours == 5_000 }?.date } }
#Preview("Wide window", traits: .fixedLayout(width: 1000, height: 700)) { ScrubPreviewData.make { now, _, _ in now } }
#endif
