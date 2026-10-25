import SwiftUI
import Charts

struct GrowthTab: View {
    let craft: Craft
    let sessions: [Session]
    let estimates: [YearEstimate]
    let weekStart: WeekStart

    /// "What if I practise more?" — never saved.
    @State private var extra = 0.0

    private func summary(now: Date, extra: Double) -> ProgressSummary {
        ProgressSummary.make(estimates: estimates.map(\.rate), sessions: sessions.map(\.record),
                             onboardingDate: craft.createdAt, weekStart: weekStart, now: now, extra: extra)
    }

    var body: some View {
        let now = Date()
        let s = summary(now: now, extra: extra)
        let past = GrowthSeries.past(estimates: estimates.map(\.rate), sessions: sessions.map(\.record),
                                     onboardingDate: craft.createdAt, startYear: craft.startYear, now: now)
        let data = GrowthSeries.chartData(forecast: s.forecast, past: past, now: now)

        VStack(spacing: 14) {
            forecastCard(s: s, data: data, now: now)
            weeklyCard(s)
            whatIfCard(s: s, now: now)
        }
    }

    // MARK: Forecast

    private func forecastCard(s: ProgressSummary, data: GrowthChartData, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Mastery forecast").lgText(.caption, color: LGColor.inkMuted)
                Text(ForecastText.headline(s.forecast.mid, now: now))
                    .lgText(LGTextStyle(size: 24, weight: .bold, relativeTo: .title2, tracking: -0.48))
                Text("Likely between \(ForecastText.year(s.forecast.high, now: now)) and \(ForecastText.year(s.forecast.low, now: now))")
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

            HStack(spacing: 14) {
                legend("Your hours") { RoundedRectangle(cornerRadius: 2).fill(LGColor.ink).frame(width: 14, height: 3) }
                legend("Forecast") {
                    Line().stroke(LGColor.forecast, style: StrokeStyle(lineWidth: 3, dash: [4, 3])).frame(width: 14, height: 3)
                }
                legend("Likely range") { RoundedRectangle(cornerRadius: 3).fill(LGColor.forecastBand.opacity(0.3)).frame(width: 12, height: 10) }
            }
            .padding(.horizontal, 4)
            .accessibilityHidden(true)
        }
        .padding(.horizontal, 14).padding(.top, 16).padding(.bottom, 12)
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
                    Text("Mastery · 10,000 h").lgText(LGTextStyle(size: 10, weight: .regular, relativeTo: .caption2), color: LGColor.inkMuted)
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

    private func legend<Mark: View>(_ title: String, @ViewBuilder mark: () -> Mark) -> some View {
        HStack(spacing: 6) {
            mark()
            Text(title).lgText(LGTextStyle(size: 12, weight: .regular, relativeTo: .caption), color: LGColor.inkMuted)
        }
    }

    // MARK: Weekly rate

    private func weeklyCard(_ s: ProgressSummary) -> some View {
        let rates = s.yearlyRates
        let maxRate = max(14, rates.map(\.hoursPerWeek).max() ?? 0)
        let currentYear = Calendar.current.component(.year, from: Date())
        return VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Weekly rate by year").lgText(.rowStrong)
                Spacer()
                Text(GrowthText.trend(s.trend)).lgText(.caption, color: LGColor.inkMuted)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(rates, id: \.year) { rate in
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 5)
                                .fill(rate.year == currentYear ? LGColor.currentBar : LGColor.chipBorder)
                                .frame(height: CGFloat(rate.hoursPerWeek / maxRate * 46) + 4)
                            Text("’" + String(format: "%02d", rate.year % 100))
                                .lgText(LGTextStyle(size: 10, weight: .regular, relativeTo: .caption2), color: LGColor.inkMuted)
                        }
                        .frame(minWidth: rates.count <= 8 ? nil : 28)
                        .frame(maxWidth: rates.count <= 8 ? .infinity : 28)
                    }
                }
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .bottom)
                .frame(height: 64, alignment: .bottom)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(weeklyLabel(rates))
        }
        .padding(.horizontal, 18).padding(.vertical, 14)
        .lgCard()
    }

    private func weeklyLabel(_ rates: [YearRate]) -> String {
        guard let first = rates.first, let last = rates.last else { return "No yearly rates yet" }
        return "Average hours per week: \(Int(first.hoursPerWeek.rounded())) in \(first.year), \(Int(last.hoursPerWeek.rounded())) in \(last.year)"
    }

    // MARK: What if

    private func whatIfCard(s: ProgressSummary, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("What if I practise more?").lgText(.rowStrong)
                Spacer()
                Text("+\(Int(extra)) h/wk").lgText(.rowStrong)
            }
            Slider(value: $extra, in: 0...10, step: 1)
                .tint(LGColor.ink)
                .accessibilityLabel("Extra hours per week")
                .accessibilityValue("\(Int(extra))")
            Text(ForecastText.whatIf(extra: extra, total: s.total, pace: s.pace, trend: s.trend, now: now))
                .lgText(.caption, color: LGColor.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 18).padding(.vertical, 14)
        .lgCard()
    }
}

private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p
    }
}
