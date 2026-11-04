import SwiftUI
import Charts

struct GrowthTab: View {
    let craft: Craft
    let sessions: [Session]
    let estimates: [YearEstimate]
    let weekStart: WeekStart
    /// The weekly target, so the finish line matches Home (the mid line runs on it for its 12 months).
    var target: TargetRecord?

    /// "What if I practise more?" — never saved.
    @State private var extra = 0.0

    private func summary(now: Date, extra: Double) -> ProgressSummary {
        ProgressSummary.make(estimates: estimates.map(\.rate), sessions: sessions.map(\.record),
                             onboardingDate: craft.createdAt, weekStart: weekStart, now: now, extra: extra, target: target)
    }

    var body: some View {
        let now = Date()
        let s = summary(now: now, extra: extra)
        let past = GrowthSeries.past(estimates: estimates.map(\.rate), sessions: sessions.map(\.record),
                                     onboardingDate: craft.createdAt, startYear: craft.startYear, now: now)
        let data = GrowthSeries.chartData(forecast: s.forecast, past: past, now: now)

        VStack(spacing: 14) {
            forecastCard(s: s, data: data, now: now)
            whatIfCard(s: s, now: now)
            yearRow(now: now)
        }
    }

    /// A quiet row at the bottom, there all year: opens the year card (the year so far, or last year in early January).
    @ViewBuilder
    private func yearRow(now: Date) -> some View {
        let year = YearSummary.defaultYear(now: now)
        let summary = YearSummary.make(year: year, sessions: sessions.map(\.record), estimates: estimates.map(\.rate),
                                       onboardingDate: craft.createdAt, now: now, weekStart: weekStart)
        if summary.hasEnoughData {
            NavigationLink {
                YearScreen(craft: craft, sessions: sessions, estimates: estimates, weekStart: weekStart, year: year)
            } label: {
                YearEntryRow(year: year).padding(.horizontal, 18)
            }
            .buttonStyle(.plain)
            .lgCard()
        }
    }

    // MARK: Forecast

    private func forecastCard(s: ProgressSummary, data: GrowthChartData, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("You'll finish the game around").lgText(.caption, color: LGColor.inkMuted)
                Text(ForecastText.headline(s.forecast.mid, now: now))
                    .lgText(LGTextStyle(size: 24, weight: .bold, relativeTo: .title2, tracking: -0.48))
                Text(ForecastText.range(s.forecast, now: now))
                    .lgText(.caption, color: LGColor.inkMuted)
                if !s.hasEnoughData {
                    Text("Forecast improves as you log more")
                        .lgText(.caption, color: LGColor.inkMuted)
                }
            }
            .padding(.horizontal, 4)
            .accessibilityElement(children: .combine)

            chart(s: s, data: data, now: now)
                .frame(height: 210)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(GrowthText.chartLabel(total: s.total, forecast: s.forecast, now: now))

        }
        .padding(.horizontal, 14).padding(.vertical, 16)
        .lgCard()
    }

    private func chart(s: ProgressSummary, data: GrowthChartData, now: Date) -> some View {
        let spanYears = data.xEnd.timeIntervalSince(data.xStart) / (365.25 * 86_400)
        let step = spanYears <= 8 ? 1 : spanYears <= 16 ? 2 : spanYears <= 30 ? 5 : 10
        return Chart {
            ForEach(Array(data.band.enumerated()), id: \.offset) { _, p in
                AreaMark(x: .value("Date", p.date), yStart: .value("Low", p.low), yEnd: .value("High", p.high), series: .value("Series", "Band"))
                    .foregroundStyle(LGColor.forecastBand.opacity(0.16))
            }
            ForEach(Array(data.past.enumerated()), id: \.offset) { _, p in
                AreaMark(x: .value("Date", p.date), y: .value("Hours", p.hours), series: .value("Series", "PastArea"))
                    .foregroundStyle(LGColor.ink.opacity(0.07))
            }
            ForEach(Array(data.past.enumerated()), id: \.offset) { _, p in
                LineMark(x: .value("Date", p.date), y: .value("Hours", p.hours), series: .value("Series", "Past"))
                    .foregroundStyle(LGColor.ink)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            }
            ForEach(Array(data.mid.enumerated()), id: \.offset) { _, p in
                LineMark(x: .value("Date", p.date), y: .value("Hours", p.hours), series: .value("Series", "Forecast"))
                    .foregroundStyle(LGColor.forecast)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [6, 5]))
            }
            RuleMark(y: .value("Goal", Totals.goalHours))
                .foregroundStyle(LGColor.ink.opacity(0.35))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))
                .annotation(position: .top, alignment: .leading, spacing: 2) {
                    Text("Finish line · 10,000 h").lgText(LGTextStyle(size: 10, weight: .regular, relativeTo: .caption2), color: LGColor.inkMuted)
                }
            PointMark(x: .value("Date", now), y: .value("Hours", s.total))
                .symbol {
                    Circle().fill(.white).frame(width: 10, height: 10)
                        .overlay(Circle().stroke(LGColor.ink, lineWidth: 2.5))
                }
                .annotation(position: .topLeading, spacing: 2) {
                    Text("Today").lgText(LGTextStyle(size: 10, weight: .semibold, relativeTo: .caption2))
                }
            if let mastery = data.masteryDate {
                PointMark(x: .value("Date", mastery), y: .value("Hours", Totals.goalHours))
                    .symbol { SunView(rayColor: LGColor.sunRays).frame(width: 28, height: 28) }
            }
        }
        .chartYScale(domain: 0...10_500)
        .chartXScale(domain: data.xStart...data.xEnd)
        .chartYAxis {
            AxisMarks(values: [0, 5_000, 10_000]) { value in
                AxisGridLine().foregroundStyle(LGColor.divider)
                AxisValueLabel {
                    if let v = value.as(Int.self) {
                        Text(v == 0 ? "0" : "\(v / 1000)k")
                            .lgText(LGTextStyle(size: 10, weight: .regular, relativeTo: .caption2), color: LGColor.inkMuted)
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
    }

    // MARK: What if

    private func whatIfCard(s: ProgressSummary, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("What if I practise more?").lgText(.rowStrong)
                Spacer()
                Text(Labels.extraPerWeek(Int(extra))).lgText(.rowStrong)
            }
            Slider(value: $extra, in: 0...10, step: 1)
                .tint(LGColor.ink)
                .accessibilityLabel("Extra hours per week")
                .accessibilityValue("\(Int(extra))")
            Text(ForecastText.whatIf(extra: extra, total: s.total, pace: s.forecastPace, trend: max(0, s.trend),
                                     target: s.forecastTarget, now: now))
                .lgText(.caption, color: LGColor.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 18).padding(.vertical, 14)
        .lgCard()
    }
}
