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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The sun rises into place when the sheet opens (at once with Reduce Motion).
    @State private var risen = false

    var body: some View {
        VStack(spacing: 0) {
            SceneHero(tone: .dawn, height: 264, skyHeight: 230, horizon: 0.82, landTop: 144, sunSize: 130,
                      sunTop: risen ? 40 : 150, eyesOpen: 1, giggles: true,
                      label: "The sun fully risen above the sea")
                .padding(.top, 0)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Meet your future self")
                        .lgText(LGTextStyle(size: 28, weight: .bold, relativeTo: .title, tracking: -0.56))
                        .accessibilityAddTraits(.isHeader)
                        .padding(.top, 6)
                    VStack(alignment: .leading, spacing: 10) {
                        point("Who you’re becoming.", "Every hour you play shapes the person you’ll be at 10,000.")
                        point("How Long Game helps.", "It keeps that person in view, counts every step and shows how close you are.")
                        point("Why steady matters.", "A little, most days, beats a lot once in a while. That’s how hours turn into mastery.")
                    }
                    .padding(.top, 12)

                    track.padding(.top, 18)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            }
            .scrollBounceBehavior(.basedOnSize)

            VStack(spacing: 12) {
                Text("Nature does not hurry, yet everything is accomplished.")
                    .lgText(.caption, color: LGColor.inkMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Keep playing") { dismiss() }
                    .buttonStyle(.lg(.primary))
            }
            .padding(.horizontal, 24).padding(.top, 8).padding(.bottom, 12)
        }
        .background(LGColor.background)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(30)
        .onAppear {
            if reduceMotion { risen = true } else { withAnimation(.easeOut(duration: 1.4)) { risen = true } }
        }
    }

    /// A short paragraph with a bold navy lead-in.
    private func point(_ lead: LocalizedStringKey, _ rest: LocalizedStringKey) -> some View {
        (Text(lead).fontWeight(.semibold).foregroundColor(LGColor.ink) + Text(" ") + Text(rest))
            .lgText(LGTextStyle(size: 15, weight: .regular, relativeTo: .subheadline), color: LGColor.inkMuted)
            .lineSpacing(3)
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
                    Capsule().fill(Color(hex: 0xE4DFD6)).frame(height: 4)
                    Capsule()
                        .fill(LinearGradient(colors: [LGColor.sunBody, LGColor.amber], startPoint: .leading, endPoint: .trailing))
                        .frame(width: x, height: 4)
                    Circle().fill(LGColor.ink).frame(width: 16, height: 16)
                        .overlay(Circle().stroke(LGColor.background, lineWidth: 3).padding(-1.5))
                        .position(x: x, y: 2)
                    SunView(idle: false, face: .happy)
                        .frame(width: 36, height: 36)
                        .position(x: w - 14, y: 2)
                }
                .frame(height: 4)
            }
            .frame(height: 36)

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
