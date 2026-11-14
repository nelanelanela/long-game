import SwiftUI
import WatchKit

/// Add time: the amount in large gold numbers, changed with the Digital Crown in 5-minute steps (5 m to 8 h, a click
/// per step), three quick picks, and Add, which names the amount. Saved as hours added for today.
struct WatchAddTimeView: View {
    /// What today already holds, for the 12-hour limit.
    let todaySeconds: TimeInterval
    let onAdd: (TimeInterval) -> Void

    @State private var crown: Double = WatchAddTime.initial

    private var amount: TimeInterval { WatchAddTime.clamped(crown) }
    private var fits: Bool { WatchAddTime.canAdd(amount, todaySeconds: todaySeconds) }

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text(verbatim: WatchAddTime.amount(amount))
                    .lgNumber(LGTextStyle(size: 40, weight: .bold, relativeTo: .largeTitle, tracking: -1.2), color: LGColor.timerGold)
                    .contentTransition(.numericText())
                    .focusable()
                    .digitalCrownRotation($crown, from: WatchAddTime.minimum, through: WatchAddTime.maximum,
                                          by: WatchAddTime.step, sensitivity: .low, isContinuous: false,
                                          isHapticFeedbackEnabled: true)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(verbatim: Labels.spoken(seconds: Int(amount), includeSeconds: false)))
                    .accessibilityAdjustableAction { direction in
                        switch direction {
                        case .increment: crown = WatchAddTime.clamped(amount + WatchAddTime.step)
                        case .decrement: crown = WatchAddTime.clamped(amount - WatchAddTime.step)
                        @unknown default: break
                        }
                    }

                Text("today · turn the Crown")
                    .lgText(LGTextStyle(size: 11, weight: .regular, relativeTo: .caption2), color: .white.opacity(0.7))
                    .accessibilityHidden(true)

                HStack(spacing: 6) {
                    ForEach(WatchAddTime.quickPicks, id: \.self) { pick in
                        let chosen = amount == pick
                        Button {
                            crown = pick
                            WKInterfaceDevice.current().play(.click)
                        } label: {
                            Text(verbatim: WatchAddTime.amount(pick))
                                .lgText(LGTextStyle(size: 12, weight: .semibold, relativeTo: .caption), color: chosen ? LGColor.ink : .white)
                                .lineLimit(1).minimumScaleFactor(0.7)
                                .frame(maxWidth: .infinity, minHeight: 30)
                                .background(chosen ? Color.white : Color.white.opacity(0.16), in: Capsule())
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(chosen ? .isSelected : [])
                    }
                }

                Button {
                    WKInterfaceDevice.current().play(.success)
                    onAdd(amount)
                } label: {
                    Text(verbatim: fits ? String(localized: "Add \(WatchAddTime.amount(amount))")
                                        : String(localized: "That's more than a day holds"))
                        .lgText(LGTextStyle(size: 14, weight: .bold, relativeTo: .footnote), color: LGColor.ink)
                        .multilineTextAlignment(.center)
                        .lineLimit(2).minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .background(LGColor.timerGold.opacity(fits ? 1 : 0.45), in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!fits)
                .padding(.top, 4)
            }
            .padding(.horizontal, 6)
        }
        .navigationTitle(Text("Add time"))
        .background(LGColor.night)
    }
}

/// "30 m added" with Undo for 6 seconds after Add time, then "Removed." for 2 seconds after Undo.
struct WatchAddedToast: View {
    @Environment(WatchStore.self) private var store

    var body: some View {
        if let added = store.justAdded {
            HStack(spacing: 8) {
                Text("\(WatchAddTime.amount(added.durationSec)) added")
                    .lgText(LGTextStyle(size: 13, weight: .semibold, relativeTo: .footnote), color: .white)
                    .lineLimit(1).minimumScaleFactor(0.7)
                Button { store.undoAdd() } label: {
                    Text("Undo")
                        .lgText(LGTextStyle(size: 13, weight: .semibold, relativeTo: .footnote), color: LGColor.timerGold)
                        .padding(.horizontal, 10)
                        .frame(minHeight: 30)
                        .background(Color.white.opacity(0.14), in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.leading, 12).padding(.trailing, 4)
            .frame(minHeight: 38)
            .background(LGColor.ink, in: Capsule())
            .padding(.top, 2)
            .transition(.move(edge: .top).combined(with: .opacity))
        } else if store.showsRemoved {
            Text("Removed.")
                .lgText(LGTextStyle(size: 13, weight: .semibold, relativeTo: .footnote), color: .white)
                .padding(.horizontal, 14)
                .frame(minHeight: 38)
                .background(LGColor.ink, in: Capsule())
                .padding(.top, 2)
                .transition(.opacity)
        }
    }
}
