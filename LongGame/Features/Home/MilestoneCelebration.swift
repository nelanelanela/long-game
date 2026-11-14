import SwiftUI

/// One-time celebration when the total crosses a milestone. At 10,000 hours
/// the sun fully rises in a full-screen moment.
struct MilestoneCelebration: View {
    let hours: Int
    let craftName: String
    var offerSupport = false
    /// The app icon follows the total: only then does a milestone say it has grown.
    var iconGrows = true
    var onSupport: () -> Void = {}
    let onDone: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startedAt = Date()

    private var isMastery: Bool { hours >= 10_000 }

    var body: some View {
        if isMastery { masteryBody } else { milestoneBody }
    }

    /// A thousand hours and the others: the dawn scene, the number in white above it and a short line below.
    private var milestoneBody: some View {
        GeometryReader { geo in
            let k = min(1, max(0.6, (geo.size.height - 250) / 560))
            ZStack(alignment: .top) {
                LGColor.background.ignoresSafeArea()
                VStack(spacing: 0) {
                    ZStack(alignment: .top) {
                        SceneHero(tone: .dawn, height: 560 * k, skyHeight: 560 * k, horizon: 0.8, landTop: 403 * k,
                                  sunSize: 140 * k, sunTop: 240 * k, face: .celebrate, giggles: false, hidden: true)
                        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { timeline in
                            let p = min(1, timeline.date.timeIntervalSince(startedAt) / 1.2)
                            if !reduceMotion && p < 1 {
                                SaveBurst(progress: p)
                                    .position(x: geo.size.width / 2, y: (240 + 70) * k)
                            }
                        }
                        .frame(height: 560 * k)
                        VStack(spacing: 6) {
                            Text("\(craftName) · milestone")
                                .lgText(LGTextStyle(size: 12, weight: .semibold, relativeTo: .caption, tracking: 1.7), color: .white.opacity(0.85))
                                .textCase(.uppercase)
                            Text("\(DurationFormat.grouped(hours)) hours")
                                .lgNumber(LGTextStyle(size: 44, weight: .bold, relativeTo: .largeTitle, tracking: -1.3), color: .white)
                        }
                        .padding(.top, 70 * k + 8)
                        .accessibilityElement(children: .combine)
                    }
                    .ignoresSafeArea(edges: .top)
                    .frame(height: 560 * k)

                    VStack(spacing: 14) {
                        Text(Milestones.message(hours: hours, craft: craftName))
                            .lgText(LGTextStyle(size: 20, weight: .semibold, relativeTo: .title3))
                            .multilineTextAlignment(.center)
                        if iconGrows && Milestones.iconGrows(at: hours) {
                            Text("Your app icon has grown a little too.")
                                .lgText(.note, color: LGColor.inkMuted)
                                .multilineTextAlignment(.center)
                        }
                        Spacer(minLength: 12)
                        Button("Keep playing", action: onDone).buttonStyle(.lg(.primary))
                        if offerSupport {
                            Button("Support Long Game", action: onSupport).buttonStyle(.lg(.text))
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 18)
                    .padding(.bottom, 12)
                }
            }
        }
        // Rising three, the hour-milestone feeling (also 10,000 hours).
        .onAppear { Haptics.play(hours >= 10_000 ? .tenThousand : .hourMilestone) }
        .onAppear {
            let spoken = String(localized: "\(DurationFormat.grouped(hours)) hours") + ". " + Milestones.message(hours: hours, craft: craftName)
            AccessibilityNotification.Announcement(spoken).post()
        }
        .accessibilityAddTraits(.isModal)
    }

    private var masteryBody: some View {
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
                        SunView(idle: false, face: .celebrate,
                                rayColor: isMastery ? LGColor.sunRaysBright : LGColor.sunRays,
                                raySpread: reduceMotion || p >= 1 ? 1 : 1 + 0.8 * sin(p * .pi))
                            .frame(width: isMastery ? 240 : 140, height: isMastery ? 240 : 140)
                            .offset(y: reduceMotion || p >= 1 ? 0 : -sin(p * .pi) * 24)
                    }
                    .frame(height: isMastery ? 280 : 170)
                }

                VStack(spacing: 8) {
                    Text(isMastery ? "10,000 hours" : "\(DurationFormat.grouped(hours)) hours")
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
                if offerSupport {
                    Button("Support Long Game", action: onSupport)
                        .buttonStyle(.lg(.text))
                        .environment(\.colorScheme, .light)
                        .foregroundStyle(isMastery ? Color.white : LGColor.ink)
                }
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
        // Rising three, the hour-milestone feeling (also 10,000 hours).
        .onAppear { Haptics.play(hours >= 10_000 ? .tenThousand : .hourMilestone) }
        .onAppear {
            let spoken = (isMastery ? String(localized: "10,000 hours") : String(localized: "\(DurationFormat.grouped(hours)) hours")) + ". " + Milestones.message(hours: hours, craft: craftName)
            AccessibilityNotification.Announcement(spoken).post()
        }
        .accessibilityAddTraits(.isModal)
    }
}
