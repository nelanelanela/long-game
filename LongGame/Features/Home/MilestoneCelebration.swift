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
    /// "See then and now": only when there is a pair of photos to show (nil hides the button).
    var onThenAndNow: (() -> Void)?
    /// "Write to yourself at 4,000 hours": the next letter milestone (nil past 10,000 or with nothing to offer).
    var letterTo: Int?
    /// "Make a keepsake poster", at every 1,000 hours (nil hides it).
    var onKeepsake: (() -> Void)?
    var onWriteLetter: (Int) -> Void = { _ in }
    /// "Share this moment": the milestone card's words (nil hides the button).
    var shareCard: MilestoneCardView.Content?
    let onDone: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var startedAt = Date()

    private var isMastery: Bool { hours >= 10_000 }

    /// The offers besides Keep playing.
    private var extraButtons: Int {
        [onThenAndNow != nil, shareCard != nil, letterTo != nil, onKeepsake != nil && hours % 1_000 == 0]
            .filter { $0 }.count
    }

    var body: some View {
        if isMastery { masteryBody } else { milestoneBody }
    }

    /// A thousand hours and the others: the dawn scene, the number in white above it and a short line below.
    private var milestoneBody: some View {
        GeometryReader { geo in
            // The board measures from the top of the screen, so the scene does too: it runs up under the status bar.
            let top = geo.safeAreaInsets.top
            let screen = geo.size.height + top
            // Each extra offer under the words takes about 62 pt: the scene gives that room up first.
            // At the accessibility sizes the buttons are taller than that and everything under the scene scrolls
            // anyway, so the scene keeps its height and the words above the sun stay clear of it.
            let room = typeSize.isAccessibilitySize ? 250 : max(250, 160 + CGFloat(extraButtons) * 62)
            // The scene ends where the land does (403 × k + its 120 pt), never cutting the sea off part-way.
            let k = min(1, max(0.5, (screen - room - 140) / 403))
            let sceneHeight = 403 * k + 120
            ZStack(alignment: .top) {
                LGColor.background.ignoresSafeArea()
                VStack(spacing: 0) {
                    ZStack(alignment: .top) {
                        // A squeezed sky would put the moon under the clock and battery, so it only shows full size.
                        SceneHero(tone: .dawn, height: sceneHeight, skyHeight: 560 * k, horizon: 0.8, landTop: 403 * k,
                                  sunSize: 140 * k, sunTop: 240 * k, face: .celebrate, moon: k >= 0.95,
                                  giggles: false, hidden: true)
                        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { timeline in
                            let p = min(1, timeline.date.timeIntervalSince(startedAt) / 1.2)
                            if !reduceMotion && p < 1 {
                                SaveBurst(progress: p)
                                    .position(x: geo.size.width / 2, y: (240 + 70) * k)
                            }
                        }
                        .frame(height: sceneHeight)
                        VStack(spacing: 6) {
                            Text("\(craftName) · milestone")
                                .lgText(LGTextStyle(size: 12, weight: .semibold, relativeTo: .caption, tracking: 1.7), color: .white.opacity(0.85))
                                .textCase(.uppercase)
                            Text("\(DurationFormat.grouped(hours)) hours")
                                .lgNumber(LGTextStyle(size: 44, weight: .bold, relativeTo: .largeTitle, tracking: -1.3), color: .white)
                        }
                        // Never under the status bar.
                        .padding(.top, max(70 * k + 8, top + 8))
                        // Drawn on the sky above the sun: they grow up to xxxLarge so they never cover it.
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                        .accessibilityElement(children: .combine)
                    }
                    .frame(height: sceneHeight, alignment: .top)
                    // Laid out from the top of the screen, so the part under the status bar is not left empty below.
                    .padding(.top, -top)

                    // Everything under the scene scrolls if the largest text sizes need more room than is left
                    // (at the usual sizes it all fits and nothing moves).
                    ScrollView {
                        VStack(spacing: 14) {
                            Text(Milestones.message(hours: hours, craft: craftName))
                                .lgText(LGTextStyle(size: 20, weight: .semibold, relativeTo: .title3))
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                            if iconGrows && Milestones.iconGrows(at: hours) {
                                Text("Your app icon has grown a little too.")
                                    .lgText(.note, color: LGColor.inkMuted)
                                    .multilineTextAlignment(.center)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                            if let onThenAndNow {
                                Button("See then and now", action: onThenAndNow).buttonStyle(.lg(.secondary))
                            }
                            if let shareCard {
                                ShareMomentButton(content: shareCard)
                            }
                            Button("Keep playing", action: onDone).buttonStyle(.lg(.primary))
                            if let letterTo {
                                Button("Write to yourself at \(Letters.hoursName(letterTo))") { onWriteLetter(letterTo) }
                                    .buttonStyle(.lg(.secondary))
                            }
                            if let onKeepsake, hours % 1_000 == 0 {
                                Button("Make a keepsake poster", action: onKeepsake).buttonStyle(.lg(.secondary))
                            }
                            if offerSupport {
                                Button("Support Long Game", action: onSupport).buttonStyle(.lg(.text))
                            }
                        }
                        // iPad and Mac: a phone-wide column of words and buttons, centred.
                        .lgReadableColumn(440)
                        .frame(minHeight: max(0, screen - sceneHeight - 30), alignment: .top)
                    }
                    .scrollBounceBehavior(.basedOnSize)
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
                    RoundedRectangle(cornerRadius: 28, style: .continuous).fill(LGColor.surface)
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
