import SwiftUI

/// "Meet your future self": the sun rising into place over the animated sea, a short note about what 10,000 hours
/// can mean, and a track from today's total to the forecast finish date. Opens from the Home row, and once on its own
/// the first time Home appears after onboarding.
struct FutureSelfSheet: View {
    let total: Double
    /// The mid scenario, for the finish date at the end of the track.
    let forecast: ScenarioResult
    var now = Date()

    @Environment(\.dismiss) private var dismiss
    @State private var openedAt = Date()

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SunriseHero(layout: .futureSelf, label: String(localized: "The sun fully risen above the sea"),
                            riseStart: openedAt)
                    .background(LinearGradient(gradient: LGColor.futureSky, startPoint: .top, endPoint: .bottom))
                    .padding(.top, 25)

                VStack(spacing: 10) {
                    Text("Meet your future self")
                        .lgText(LGTextStyle(size: 26, weight: .bold, relativeTo: .title, tracking: -0.52))
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                    paragraph("Long Game is a projection of you into the future. Every hour you add brings that person a little closer.")
                    paragraph("Dreaming of turning your passion into a career? 10,000 hours is where that starts to become realistic, whenever you begin. In a well-known study of musicians, what set the professionals apart wasn’t talent but the hours they had put in. And you’re not starting from zero: every hour you’ve already practised counts.")
                }
                .padding(.top, 18)

                track.padding(.top, 20)

                Text("Hours aren't a guarantee, but they're the part you control.")
                    .lgText(.caption, color: LGColor.inkMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 14)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            Button("Keep playing") { dismiss() }
                .buttonStyle(.lg(.primary))
                .padding(.horizontal, 24).padding(.top, 8).padding(.bottom, 12)
                .background(Color.white)
        }
        .background(Color.white)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(32)
        .onAppear { openedAt = Date() }
    }

    private func paragraph(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .lgText(.row, color: LGColor.inkMuted)
            .lineSpacing(4)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: Track

    private var finish: String { ForecastText.shortFinish(forecast, now: now) }
    private var wholeHours: String { DurationFormat.grouped(Totals.wholeHours(total: total)) }

    private var track: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                let w = geo.size.width
                let x = w * Totals.progress(total: total)
                ZStack(alignment: .leading) {
                    Capsule().fill(LGColor.track).frame(height: 6)
                    Capsule().fill(LGColor.ink).frame(width: x, height: 6)
                    Circle().fill(.white).frame(width: 14, height: 14)
                        .overlay(Circle().stroke(LGColor.ink, lineWidth: 3))
                        .position(x: x, y: 3)
                    Circle().fill(LGColor.sunBody).frame(width: 16, height: 16)
                        .position(x: w - 6, y: 3)
                }
                .frame(height: 6)
            }
            .frame(height: 16)

            ViewThatFits(in: .horizontal) {
                HStack { todayLabel; Spacer(minLength: 8); finishLabel }
                VStack(alignment: .leading, spacing: 4) { todayLabel; finishLabel }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Today, \(wholeHours) hours. Forecast finish \(finish), 10,000 hours."))
    }

    private var todayLabel: some View {
        (Text("Today").fontWeight(.semibold) + Text(" · \(wholeHours) h").foregroundColor(LGColor.inkMuted))
            .lgText(.caption)
            .fixedSize()
    }

    private var finishLabel: some View {
        (Text(finish).fontWeight(.semibold) + Text(" · 10,000 h").foregroundColor(LGColor.inkMuted))
            .lgText(.caption)
            .fixedSize()
    }
}

/// The small risen-sun icon on the Home row.
struct RisenSunIcon: View {
    var body: some View {
        Canvas { context, size in
            let s = size.width / 200
            context.scaleBy(x: s, y: s)
            context.fill(Path(ellipseIn: CGRect(x: 0, y: 0, width: 200, height: 200)), with: .color(Color(hex: 0xFFF1D6)))

            var sun = context
            sun.translateBy(x: 40, y: 30)
            sun.scaleBy(x: 0.6, y: 0.6)
            var rays = Path()
            for k in 0..<12 {
                let angle = (Double(k) * 30 - 90) * .pi / 180
                let outer = k % 2 == 1 ? 92.0 : 82.0
                rays.move(to: CGPoint(x: 100 + 66 * cos(angle), y: 100 + 66 * sin(angle)))
                rays.addLine(to: CGPoint(x: 100 + outer * cos(angle), y: 100 + outer * sin(angle)))
            }
            sun.stroke(rays, with: .color(LGColor.sunRays), style: StrokeStyle(lineWidth: 12, lineCap: .round))
            sun.fill(Path(ellipseIn: CGRect(x: 44, y: 44, width: 112, height: 112)), with: .color(LGColor.sunBody))

            var wave = Path()
            wave.move(to: CGPoint(x: 30, y: 140))
            var x: CGFloat = 30
            var up = true
            for _ in 0..<5 {
                wave.addQuadCurve(to: CGPoint(x: x + 28, y: 140), control: CGPoint(x: x + 14, y: up ? 131 : 149))
                x += 28
                up.toggle()
            }
            context.stroke(wave, with: .color(LGColor.ink), style: StrokeStyle(lineWidth: 9, lineCap: .round))
        }
        .accessibilityHidden(true)
    }
}

#Preview("Future self") {
    FutureSelfSheet(total: 3_294, forecast: ScenarioResult(monthsToGoal: 110, points: []))
}

#Preview("Future self · large Dynamic Type") {
    FutureSelfSheet(total: 3_294, forecast: ScenarioResult(monthsToGoal: 110, points: []))
        .environment(\.dynamicTypeSize, .accessibility3)
}
