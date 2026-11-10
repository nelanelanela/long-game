import SwiftUI

/// Shown after a tip: a hopping, open-eyed sun with a little burst. Still with Reduce Motion.
struct TipThanksSheet: View {
    let onDone: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startedAt = Date()

    var body: some View {
        VStack(spacing: 0) {
            // The day scene with the celebrating sun; the little dots drift out around it.
            ZStack {
                SceneHero(tone: .day, height: 239, skyHeight: 200, horizon: 0.82, landTop: 119, sunSize: 140, sunTop: 24,
                          face: .celebrate, hidden: true)
                if !reduceMotion {
                    TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
                        motes(timeline.date.timeIntervalSince(startedAt))
                    }
                    .frame(width: 140, height: 140)
                    .offset(y: -25)
                }
            }
            .padding(.top, 6)

            VStack(spacing: 10) {
                Text("Thank you!").lgText(.setupTitle).accessibilityAddTraits(.isHeader)
                Text("You just made the sun shine a little brighter. Your tip helps keep Long Game free for everyone.")
                    .lgText(.body, color: LGColor.inkMuted).multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)
            .padding(.top, 10)
            Spacer(minLength: 16)
            Button("Back to my game", action: onDone).buttonStyle(.lg(.primary))
                .padding(.horizontal, 24)
        }
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity)
        .background(LGColor.background.ignoresSafeArea())
        .sensoryFeedback(.success, trigger: startedAt)
    }

    private func motes(_ t: Double) -> some View {
        let specs: [(dx: Double, dy: Double, delay: Double, size: Double, color: Color)] = [
            (-110, -60, 0, 14, LGColor.sunBody), (110, -50, 0.3, 10, LGColor.sunCheeks),
            (-90, 60, 0.6, 10, LGColor.sunRays), (95, 70, 0.15, 12, LGColor.sunBody),
            (0, -110, 0.45, 10, LGColor.mote), (-130, 10, 0.8, 8, LGColor.sunCheeks), (130, 0, 0.9, 8, LGColor.sunRays),
        ]
        return ZStack {
            ForEach(specs.indices, id: \.self) { i in
                let s = specs[i]
                let p = ((t - s.delay).truncatingRemainder(dividingBy: 2.4) + 2.4).truncatingRemainder(dividingBy: 2.4) / 2.4
                Circle().fill(s.color).frame(width: s.size, height: s.size)
                    .scaleEffect(0.3 + 0.7 * p)
                    .offset(x: s.dx * p, y: s.dy * p)
                    .opacity(p < 0.3 ? p / 0.3 : 1 - (p - 0.3) / 0.7)
            }
        }
        .accessibilityHidden(true)
    }
}
