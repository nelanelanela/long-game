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

        VStack(spacing: 14) {
            forecastCard(s: s, data: data, now: now)
            whatIfCard(s: s, now: now)
            yearRow(now: now)
        }
        .fullScreenCover(isPresented: $scrubbing) {
            GrowthScrubView(craftName: craft.name, past: past, data: data, forecast: s.forecast, total: s.total,
                            onboardingDate: craft.createdAt, now: now, hintSeen: settingsRows.first?.scrubHintSeen ?? false,
                            onHintSeen: markHintSeen)
                .scrubTransition(id: "growth-chart", in: chartSpace)
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
                YearEntryRow(year: year).padding(.horizontal, 18)
            }
            .buttonStyle(.plain)
            .lgCard()
        }
    }

    // MARK: Forecast

    private func forecastCard(s: ProgressSummary, data: GrowthChartData, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                if s.total >= Totals.goalHours {
                    Text(ForecastText.crossed(on: data.past.first { $0.hours >= Totals.goalHours }?.date ?? now))
                        .lgText(LGTextStyle(size: 20, weight: .bold, relativeTo: .title3, tracking: -0.4))
                } else {
                    Text("At your chosen pace, you'll finish around").lgText(.caption, color: LGColor.inkMuted)
                    Text(ForecastText.headline(s.forecast.chosen, now: now))
                        .lgText(LGTextStyle(size: 24, weight: .bold, relativeTo: .title2, tracking: -0.48))
                    Text(ForecastText.actualLine(s.forecast, now: now))
                        .lgText(.caption, color: LGColor.inkMuted)
                }
                if !s.hasEnoughData {
                    Text("Forecast improves as you log more")
                        .lgText(.caption, color: LGColor.inkMuted)
                }
            }
            .accessibilityElement(children: .combine)
                Spacer(minLength: 8)
                Button { scrubbing = true } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LGColor.ink)
                        .frame(width: 36, height: 36)
                        .background(LGColor.segmentTrack, in: Circle())
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Open chart full screen")
                .accessibilityInputLabels(["Open chart full screen", "Expand chart", "Full screen"])
                .padding(.top, -6).padding(.trailing, -6)
            }
            .padding(.horizontal, 4)

            GrowthChartView(data: data, total: s.total, now: now)
                .frame(height: 210)
                .contentShape(Rectangle())
                .onTapGesture { scrubbing = true }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(GrowthText.chartLabel(total: s.total, forecast: s.forecast, now: now))
                .accessibilityAction(named: "Open full screen") { scrubbing = true }
                .scrubTransitionSource(id: "growth-chart", in: chartSpace)

            if s.total < Totals.goalHours {
                Rectangle().fill(LGColor.hairline).frame(height: 1)
                GrowthKey(forecast: s.forecast, now: now)
                    .padding(.horizontal, 4)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 16)
        .lgCard()
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
            Text(ForecastText.whatIf(extra: extra, total: s.total, chosenPace: s.chosenPace, now: now))
                .lgText(.caption, color: LGColor.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 18).padding(.vertical, 14)
        .lgCard()
    }
}
