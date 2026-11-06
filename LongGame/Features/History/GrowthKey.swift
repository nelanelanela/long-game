import SwiftUI

/// The key for the two forecast lines, under the Growth card's chart and between the headline and the chart on the
/// full-screen version. The lines themselves carry no text (they can sit close together).
/// One VoiceOver element. At accessibility text sizes the numbers wrap under the name.
struct GrowthKey: View {
    enum Style { case card, full }

    let forecast: Forecast
    let now: Date
    var style: Style = .card

    @Environment(\.dynamicTypeSize) private var typeSize

    private var size: CGFloat { style == .full ? 13 : 12 }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            row(sample: .chosen, name: "Your chosen pace", nameColor: LGColor.chosenPaceName,
                numbers: GrowthKeyText.chosenNumbers(forecast, now: now))
            row(sample: .actual, name: "Your actual pace", nameColor: LGColor.inkMuted,
                numbers: GrowthKeyText.actualNumbers(forecast, now: now))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(GrowthKeyText.spoken(forecast, now: now))
    }

    private enum Sample { case chosen, actual }

    @ViewBuilder
    private func row(sample: Sample, name: LocalizedStringKey, nameColor: Color, numbers: String) -> some View {
        let nameText = Text(name).lgText(LGTextStyle(size: size, weight: .semibold, relativeTo: .caption), color: nameColor)
        let numberText = Text(verbatim: numbers)
            .lgText(LGTextStyle(size: size, weight: .regular, relativeTo: .caption), color: LGColor.inkMuted)
            .monospacedDigit()
        if typeSize.isAccessibilitySize {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                swatch(sample)
                VStack(alignment: .leading, spacing: 2) {
                    nameText
                    numberText
                }
                Spacer(minLength: 0)
            }
        } else {
            HStack(alignment: .center, spacing: 10) {
                swatch(sample)
                nameText
                Spacer(minLength: 8)
                numberText
            }
        }
    }

    /// A 26 pt sample drawn with the same stroke as the line on the chart.
    private func swatch(_ sample: Sample) -> some View {
        Canvas { context, canvas in
            var path = Path()
            path.move(to: CGPoint(x: 1.25, y: canvas.height / 2))
            path.addLine(to: CGPoint(x: canvas.width - 1.25, y: canvas.height / 2))
            switch sample {
            case .chosen:
                context.stroke(path, with: .color(LGColor.forecast),
                               style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [6, 5]))
            case .actual:
                context.stroke(path, with: .color(LGColor.actualPace),
                               style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [1, 6]))
            }
        }
        .frame(width: 26, height: 12)
        .accessibilityHidden(true)
    }
}

#if DEBUG
@MainActor private enum KeyPreviewData {
    static let now = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 4))!
    static func forecast(actual: Double, chosen: Double) -> Forecast {
        ForecastEngine.forecast(total: 3_294, chosenPace: chosen, actualPace: actual)
    }
    static func card(actual: Double, chosen: Double) -> some View {
        let f = forecast(actual: actual, chosen: chosen)
        let past = [CumulativePoint(date: Calendar.current.date(from: DateComponents(year: 2018, month: 1, day: 1))!, hours: 0),
                    CumulativePoint(date: now, hours: 3_294)]
        let data = GrowthSeries.chartData(forecast: f, past: past, now: now)
        return VStack(alignment: .leading, spacing: 10) {
            GrowthChartView(data: data, total: 3_294, now: now).frame(height: 210)
            Divider()
            GrowthKey(forecast: f, now: now)
        }
        .padding(16).lgCard().padding()
    }
}

#Preview("Key · lines almost overlap") { KeyPreviewData.card(actual: 11.5, chosen: 12) }
#Preview("Key · far apart") { KeyPreviewData.card(actual: 4, chosen: 12) }
#Preview("Key · almost overlap · AX5") { KeyPreviewData.card(actual: 11.5, chosen: 12).dynamicTypeSize(.accessibility5) }
#Preview("Key · far apart · AX5") { KeyPreviewData.card(actual: 4, chosen: 12).dynamicTypeSize(.accessibility5) }
#endif
