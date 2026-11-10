import SwiftUI
import Charts
import SwiftData

struct GrowthTab: View {
    let craft: Craft
    let sessions: [Session]
    let estimates: [YearEstimate]
    let weekStart: WeekStart
    /// The weekly pace, so the finish line matches Home (the dashed line runs on it).
    var target: TargetRecord?

    /// "What if I practise more?" — never saved.
    @State private var extra = 0.0
    /// The full-screen scrub chart.
    @State private var scrubbing = false
    @Namespace private var chartSpace
    @Query private var settingsRows: [AppSettings]
    @Environment(\.modelContext) private var context

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

        VStack(alignment: .leading, spacing: 0) {
            headline(s: s, data: data, now: now)
            forecastCard(s: s, data: data, now: now).padding(.top, 14)
            whatIf(s: s, now: now).padding(.top, 16)
            yearRow(now: now).padding(.top, 20)
        }
        .fullScreenCover(isPresented: $scrubbing) {
            GrowthScrubView(craftName: craft.name, past: past, data: data, forecast: s.forecast, total: s.total,
                            onboardingDate: craft.createdAt, now: now, hintSeen: settingsRows.first?.scrubHintSeen ?? false,
                            onHintSeen: markHintSeen)
                .scrubTransition(id: "growth-chart", in: chartSpace)
                .allowsRotation()
        }
    }

    /// After the first scrub ever, the hint "Drag along the line" is gone for good.
    private func markHintSeen() {
        guard let settings = settingsRows.first, !settings.scrubHintSeen else { return }
        settings.scrubHintSeen = true
        try? context.save()
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
                YearEntryRow(year: year, sunSize: 34)
            }
            .buttonStyle(.plain)
            .overlay(alignment: .top) { Rectangle().fill(LGColor.hairline).frame(height: 1) }
        }
    }

    // MARK: Forecast

    /// Above the chart, straight on the page: a quiet line, the finish date large, the actual pace under it.
    private func headline(s: ProgressSummary, data: GrowthChartData, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if s.total >= Totals.goalHours {
                Text(ForecastText.crossed(on: data.past.first { $0.hours >= Totals.goalHours }?.date ?? now))
                    .lgText(LGTextStyle(size: 24, weight: .bold, relativeTo: .title2, tracking: -0.5))
            } else {
                Text("At your chosen pace, you'll finish around").lgText(.note, color: LGColor.inkMuted)
                Text(ForecastText.headline(s.forecast.chosen, now: now))
                    .lgText(LGTextStyle(size: 34, weight: .bold, relativeTo: .largeTitle, tracking: -1))
                    .lineLimit(1).minimumScaleFactor(0.6)
                Text(ForecastText.actualLine(s.forecast, now: now))
                    .lgText(.note, color: LGColor.inkMuted)
            }
            if !s.hasEnoughData {
                Text("Forecast improves as you log more")
                    .lgText(.note, color: LGColor.inkMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func forecastCard(s: ProgressSummary, data: GrowthChartData, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            GrowthChartView(data: data, total: s.total, now: now)
                .frame(height: 210)
                // Room above the finish line, so the round button never covers the sun at its end.
                .padding(.top, 30)
                .contentShape(Rectangle())
                .onTapGesture { scrubbing = true }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(GrowthText.chartLabel(total: s.total, forecast: s.forecast, now: now))
                .accessibilityAction(named: "Open full screen") { scrubbing = true }
                .scrubTransitionSource(id: "growth-chart", in: chartSpace)

            if s.total < Totals.goalHours {
                Rectangle().fill(LGColor.divider).frame(height: 1).padding(.horizontal, 6)
                GrowthKey(forecast: s.forecast, now: now)
                    .padding(.horizontal, 6).padding(.top, 4)
            }
        }
        .padding(.horizontal, 10).padding(.top, 14).padding(.bottom, 12)
        .lgCard(radius: 22)
        // The round "open full screen" button sits on the card's top right corner.
        .overlay(alignment: .topTrailing) {
            Button { scrubbing = true } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LGColor.ink)
                    .frame(width: 36, height: 36)
                    .background(LGColor.stepperButton, in: Circle())
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Open chart full screen")
            .accessibilityInputLabels(["Open chart full screen", "Expand chart", "Full screen"])
            .padding(6)
        }
    }

    // MARK: What if

    /// Straight on the page, no card: the question, the extra hours, a gold slider and what it would change.
    private func whatIf(s: ProgressSummary, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("What if I practise more?").lgText(.rowStrong)
                Spacer()
                Text("+\(Int(extra)) h").lgText(.rowStrong).monospacedDigit()
            }
            Slider(value: $extra, in: 0...10, step: 1)
                .tint(LGColor.amber)
                .accessibilityLabel("Extra hours per week")
                .accessibilityValue("\(Int(extra))")
            Text(ForecastText.whatIf(extra: extra, total: s.total, chosenPace: s.chosenPace, now: now))
                .lgText(.caption, color: LGColor.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
