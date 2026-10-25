import SwiftUI

/// One-time celebration when the total crosses a milestone. At 10,000 hours
/// the sun fully rises in a full-screen moment.
struct MilestoneCelebration: View {
    let hours: Int
    let craftName: String
    let onDone: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startedAt = Date()

    private var isMastery: Bool { hours >= 10_000 }

    var body: some View {
        ZStack {
            if isMastery {
                LinearGradient(gradient: LGColor.welcomeSky, startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            } else {
                Color.black.opacity(0.3).ignoresSafeArea()
            }

            VStack(spacing: 20) {
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { timeline in
                    let t = timeline.date.timeIntervalSince(startedAt)
                    let p = reduceMotion ? 1 : (isMastery ? (t.truncatingRemainder(dividingBy: 2.6) / 1.2) : t / 1.2)
                    ZStack {
                        if !reduceMotion && p < 1 { SaveBurst(progress: p) }
                        SunView(face: .celebrate,
                                rayColor: isMastery ? LGColor.sunRaysBright : LGColor.sunRays,
                                raySpread: reduceMotion || p >= 1 ? 1 : 1 + 0.8 * sin(p * .pi))
                            .frame(width: isMastery ? 240 : 140, height: isMastery ? 240 : 140)
                            .offset(y: reduceMotion || p >= 1 ? 0 : -sin(p * .pi) * 24)
                    }
                    .frame(height: isMastery ? 280 : 170)
                }

                VStack(spacing: 8) {
                    Text(isMastery ? "10,000 hours" : "\(NumberFormatter.localizedString(from: NSNumber(value: hours), number: .decimal)) hours")
                        .lgNumber(LGTextStyle(size: 34, weight: .bold, relativeTo: .largeTitle, tracking: -1),
                                  color: isMastery ? .white : LGColor.ink)
                    Text(Milestones.message(hours: hours, craft: craftName))
                        .lgText(.bodyLarge, color: isMastery ? .white.opacity(0.9) : LGColor.inkMuted)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    if isMastery {
                        Text("The app keeps counting. This is the beginning of the next stretch.")
                            .lgText(.row, color: .white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)
                    }
                }
                .accessibilityElement(children: .combine)

                Button("Keep going", action: onDone)
                    .buttonStyle(.lg(isMastery ? .light : .primary))
            }
            .padding(24)
            .frame(maxWidth: isMastery ? .infinity : 340)
            .background {
                if !isMastery {
                    RoundedRectangle(cornerRadius: 28, style: .continuous).fill(.white)
                }
            }
            .padding(.horizontal, isMastery ? 0 : 24)
        }
        .sensoryFeedback(.success, trigger: startedAt)
        .accessibilityAddTraits(.isModal)
    }
}
