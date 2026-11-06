import SwiftUI
import Charts

/// The Growth chart: the card's chart and the full-screen scrub chart are one piece of code. The card shows the
/// past line, the grey area under it, the dashed line at the chosen pace with its sun, the dotted line at the recent
/// pace, the finish line and Today.
/// The full-screen style adds the milestone dots, more labels on the hours axis and the scrub line and dot.
struct GrowthChartView: View {
    enum Style { case card, full }

    let data: GrowthChartData
    let total: Double
    let now: Date
    var style: Style = .card

    // Full screen only.
    var milestones: [ScrubMilestone] = []
    /// Where the scrub line and dot are, snapped to the curve.
    var scrubPoint: ScrubPoint?
    var selection: Binding<Date?>?
    /// The sun at the finish pops in: its scale during the draw-in.
    var sunScale: CGFloat = 1
    /// How much of each line is drawn (all of it, except while the full-screen chart opens).
    var draw: DrawProgress = .complete
    /// A gold ring that grows around a milestone's dot for 0.4 s.
    var ring: (index: Int, progress: Double)?
    /// The floating label next to the dot, placed by the chart's own coordinates.
    var floatingLabel: ScrubReadout?

    private var full: Bool { style == .full }

    var body: some View {
        let spanYears = data.xEnd.timeIntervalSince(data.xStart) / (365.25 * 86_400)
        let step = spanYears <= 8 ? 1 : spanYears <= 16 ? 2 : spanYears <= 30 ? 5 : 10
        Chart {
            let past = LineDraw.partial(data.past, fraction: draw.past)
            let chosen = LineDraw.partial(data.chosen, fraction: draw.chosen)
            let recent = LineDraw.partial(data.recent, fraction: draw.recent)
            ForEach(Array(past.enumerated()), id: \.offset) { _, p in
                AreaMark(x: .value("Date", p.date), y: .value("Hours", p.hours), series: .value("Series", "PastArea"))
                    .foregroundStyle(LGColor.ink.opacity(0.07))
            }
            ForEach(Array(past.enumerated()), id: \.offset) { _, p in
                LineMark(x: .value("Date", p.date), y: .value("Hours", p.hours), series: .value("Series", "Past"))
                    .foregroundStyle(LGColor.ink)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            }
            // The dotted grey line at the recent pace, labelled below it.
            ForEach(Array(recent.enumerated()), id: \.offset) { _, p in
                LineMark(x: .value("Date", p.date), y: .value("Hours", p.hours), series: .value("Series", "Recent"))
                    .foregroundStyle(LGColor.recentPace)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [1, 6]))
            }
            if draw.recent >= 1, let spot = Self.labelSpot(data.recent) {
                PointMark(x: .value("Date", spot.date), y: .value("Hours", spot.hours))
                    .symbolSize(0)
                    .annotation(position: .bottomTrailing, spacing: 3) {
                        Text("Recent pace").lgText(LGTextStyle(size: 10, weight: .regular, relativeTo: .caption2), color: LGColor.gaugeLabel)
                            .fixedSize()
                    }
            }
            // The dashed orange line at the chosen pace, labelled above it, with the sun at its finish.
            ForEach(Array(chosen.enumerated()), id: \.offset) { _, p in
                LineMark(x: .value("Date", p.date), y: .value("Hours", p.hours), series: .value("Series", "Chosen"))
                    .foregroundStyle(LGColor.forecast)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [7, 6]))
            }
            if draw.chosen >= 1, let spot = Self.labelSpot(data.chosen) {
                PointMark(x: .value("Date", spot.date), y: .value("Hours", spot.hours))
                    .symbolSize(0)
                    .annotation(position: .topLeading, spacing: 3) {
                        Text("Your pace").lgText(LGTextStyle(size: 10, weight: .semibold, relativeTo: .caption2), color: LGColor.forecastText)
                            .fixedSize()
                    }
            }
            RuleMark(y: .value("Goal", Totals.goalHours))
                .foregroundStyle(LGColor.ink.opacity(0.35))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))
                .annotation(position: .top, alignment: .leading, spacing: 2) {
                    Text("Finish line · 10,000 h").lgText(LGTextStyle(size: full ? 11 : 10, weight: .regular, relativeTo: .caption2), color: LGColor.inkMuted)
                }
            if full {
                // 1,000 · 2,500 · 5,000 · 7,500: filled navy when reached, white with an orange outline when ahead.
                ForEach(Array(milestones.enumerated()), id: \.offset) { _, m in
                    if !m.isFinish {
                        PointMark(x: .value("Date", m.date), y: .value("Hours", m.hours))
                            .symbol { milestoneDot(reached: m.isReached) }
                    }
                }
            }
            PointMark(x: .value("Date", now), y: .value("Hours", total))
                .symbol {
                    Circle().fill(.white).frame(width: 10, height: 10)
                        .overlay(Circle().stroke(LGColor.ink, lineWidth: 2.5))
                }
                .annotation(position: .topLeading, spacing: 2) {
                    Text("Today").lgText(LGTextStyle(size: 10, weight: .semibold, relativeTo: .caption2))
                }
            if let mastery = data.chosenDate {
                PointMark(x: .value("Date", mastery), y: .value("Hours", Totals.goalHours))
                    .symbol { SunView(rayColor: LGColor.sunRays).frame(width: full ? 36 : 28, height: full ? 36 : 28).scaleEffect(sunScale) }
            }
            if full, let p = scrubPoint {
                RuleMark(x: .value("Date", p.date))
                    .foregroundStyle(LGColor.ink)
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
                PointMark(x: .value("Date", p.date), y: .value("Hours", p.hours))
                    .symbol {
                        Circle().fill(.white).frame(width: 16, height: 16)
                            .overlay(Circle().stroke(LGColor.ink, lineWidth: 3))
                    }
            }
        }
        .chartYScale(domain: 0...10_500)
        .chartXScale(domain: data.xStart...data.xEnd)
        .chartYAxis {
            AxisMarks(values: full ? [0, 2_500, 5_000, 7_500, 10_000] : [0, 5_000, 10_000]) { value in
                AxisGridLine().foregroundStyle(LGColor.divider)
                AxisValueLabel {
                    if let v = value.as(Int.self) {
                        Text(Self.axisLabel(v))
                            .lgText(LGTextStyle(size: full ? 11 : 10, weight: .regular, relativeTo: .caption2), color: LGColor.inkMuted)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .year, count: step)) { _ in
                AxisValueLabel(format: .dateTime.year(), anchor: .top)
                    .foregroundStyle(LGColor.inkMuted)
            }
        }
        .modifier(ScrubSelection(binding: full ? selection : nil))
        .chartOverlay { proxy in
            if full { overlay(proxy) }
        }
    }

    /// Where a line's label sits: about 62% of the way along it.
    static func labelSpot(_ points: [CumulativePoint]) -> CumulativePoint? {
        guard let a = points.first, let b = points.last, a.date < b.date else { return nil }
        let t = 0.62
        return CumulativePoint(date: a.date.addingTimeInterval(b.date.timeIntervalSince(a.date) * t), hours: a.hours + (b.hours - a.hours) * t)
    }

    static func axisLabel(_ v: Int) -> String {
        switch v {
        case 0: "0"
        case 2_500: "2.5k"
        case 7_500: "7.5k"
        default: "\(v / 1000)k"
        }
    }

    private func milestoneDot(reached: Bool) -> some View {
        Circle()
            .fill(reached ? LGColor.ink : .white)
            .frame(width: 9, height: 9)
            .overlay(Circle().stroke(reached ? LGColor.ink : LGColor.forecast, lineWidth: 2))
    }

    // MARK: Ring and floating label

    private func overlay(_ proxy: ChartProxy) -> some View {
        GeometryReader { geo in
            if let plot = proxy.plotFrame.map({ geo[$0] }) {
                ZStack(alignment: .topLeading) {
                    if let ring, milestones.indices.contains(ring.index),
                       let x = proxy.position(forX: milestones[ring.index].date),
                       let y = proxy.position(forY: milestones[ring.index].hours) {
                        Circle()
                            .stroke(LGColor.sunBody, lineWidth: 3)
                            .frame(width: 18 + 26 * ring.progress, height: 18 + 26 * ring.progress)
                            .opacity(1 - ring.progress)
                            .position(x: plot.minX + x, y: plot.minY + y)
                    }
                    if let p = scrubPoint, let label = floatingLabel,
                       let x = proxy.position(forX: p.date), let y = proxy.position(forY: p.hours) {
                        floating(label, at: CGPoint(x: plot.minX + x, y: plot.minY + y), in: geo.size)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    /// The label sits beside the dot and flips to the other side near the edge, so it is never cut off or under the
    /// finger; it also stays inside the chart vertically.
    private func floating(_ label: ScrubReadout, at dot: CGPoint, in size: CGSize) -> some View {
        let width: CGFloat = 148, height: CGFloat = 78
        let onRight = dot.x < size.width * 0.5
        let x = onRight ? dot.x + 22 + width / 2 : dot.x - 22 - width / 2
        let y = min(max(dot.y - 44 - height / 2, height / 2), size.height - height / 2 - 24)
        return VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(verbatim: label.date).lgText(LGTextStyle(size: 13, weight: .semibold, relativeTo: .footnote)).lineLimit(1).minimumScaleFactor(0.7)
                Text(verbatim: label.chip)
                    .lgText(LGTextStyle(size: 10, weight: .semibold, relativeTo: .caption2), color: label.chip == "Played" ? LGColor.ink : LGColor.forecastText)
            }
            Text(verbatim: label.hours).lgText(LGTextStyle(size: 17, weight: .bold, relativeTo: .body)).monospacedDigit()
            if !label.blurb.isEmpty {
                Text(verbatim: label.blurb).lgText(LGTextStyle(size: 11, weight: .regular, relativeTo: .caption2), color: LGColor.inkMuted)
                    .lineLimit(2)
            }
        }
        .padding(10)
        .frame(width: width, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: LGColor.ink.opacity(0.14), radius: 10, y: 3)
        .position(x: x, y: y)
    }
}

/// Adds `chartXSelection` only when there is something to select (the full-screen chart).
private struct ScrubSelection: ViewModifier {
    var binding: Binding<Date?>?

    func body(content: Content) -> some View {
        if let binding {
            content.chartXSelection(value: binding)
        } else {
            content
        }
    }
}
