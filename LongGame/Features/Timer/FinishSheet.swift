import SwiftUI

/// Shown when the user taps Finish: adjust the time, add a note, save or discard.
struct FinishSheet: View {
    let elapsed: TimeInterval
    /// The person's usual session (`UsualSession.usual`), for "A long one. Did the timer keep running?".
    var usual: TimeInterval?
    /// Whether a session of this length covers today's stretch (it was still open when the session began).
    var coversStretch: (TimeInterval) -> Bool = { _ in false }
    let onSave: (_ duration: TimeInterval, _ note: String?, _ photo: Data?) -> Void
    let onDiscard: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var duration: TimeInterval
    @State private var note = ""
    @State private var photo: Data?
    @State private var confirmDiscard = false
    /// Keep the measured time (the default) or use the usual length, on the long-session card.
    @State private var choice: UsualSession.Choice = .keep

    init(elapsed: TimeInterval, usual: TimeInterval? = nil, coversStretch: @escaping (TimeInterval) -> Bool = { _ in false },
         onSave: @escaping (TimeInterval, String?, Data?) -> Void, onDiscard: @escaping () -> Void) {
        self.elapsed = elapsed
        self.usual = usual
        self.coversStretch = coversStretch
        self.onSave = onSave
        self.onDiscard = onDiscard
        _duration = State(initialValue: elapsed)
    }

    private var canSave: Bool { FinishRules.canSave(elapsed: elapsed) }
    private var showsLongCard: Bool { UsualSession.isLong(elapsed: elapsed, usual: usual) }

    var body: some View {
        VStack(spacing: 0) {
            // The day scene with the celebrating sun, edge to edge under the grabber.
            SceneHero(tone: .day, height: canSave ? 203 : 170, skyHeight: 160, horizon: 0.8, landTop: canSave ? 83 : 70,
                      sunSize: 120, sunTop: 10, face: canSave ? .celebrate : .sleepy, hidden: true)
                .padding(.top, 6)

            VStack(spacing: 0) {
                if canSave {
                    HStack {
                        LGRepeatButton(systemName: "minus", label: "Less time", enabled: duration > FinishRules.minimumSave) {
                            duration = FinishRules.lowered(duration)
                        }
                        Spacer()
                        VStack(spacing: 4) {
                            Text(DurationFormat.short(seconds: duration))
                                .lgNumber(LGTextStyle(size: 48, weight: .bold, relativeTo: .largeTitle, tracking: -1.9))
                            Text("this session").lgText(.note, color: LGColor.inkMuted)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(DurationFormat.short(seconds: duration))
                        .accessibilityHint("You can trim up to what you really practised.")
                        Spacer()
                        LGRepeatButton(systemName: "plus", label: "More time", enabled: duration < elapsed) {
                            duration = FinishRules.raised(duration, elapsed: elapsed)
                        }
                    }
                    .padding(.top, 6)

                    if let usual, UsualSession.isLong(elapsed: elapsed, usual: usual) {
                        LongSessionCard(elapsed: elapsed, usual: UsualSession.rounded(usual), choice: choice) { picked in
                            choice = picked
                            duration = UsualSession.duration(for: picked, elapsed: elapsed, usual: usual)
                        }
                        .padding(.top, 16)
                    }

                    // Optional and quiet: nothing here opens or focuses by itself, and Save works the same without it.
                    NotePhotoRow(photo: $photo, note: $note)
                        .padding(.top, 22)

                    Spacer(minLength: 12)

                    if coversStretch(duration) {
                        Text("Today's stretch covered.")
                            .lgText(.label, color: LGColor.ember)
                            .padding(.bottom, 12)
                    }

                    Button("Save") {
                        onSave(duration, SessionRules.savedNote(note), photo)
                    }
                    .buttonStyle(.lg(.primary))
                } else {
                    Text("Sessions under a minute can't be saved.")
                        .lgText(.body, color: LGColor.inkMuted)
                        .multilineTextAlignment(.center)
                        .padding(.top, 12)
                    Spacer(minLength: 12)
                }

                Button("Discard") { confirmDiscard = true }
                    .buttonStyle(.lg(.text))
                    .padding(.top, 2)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(LGColor.background)
        .presentationDetents([.height(canSave ? (showsLongCard ? 760 : 600) : 340), .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(30)
        .confirmationDialog("Discard this session?", isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button("Discard", role: .destructive, action: onDiscard)
        } message: {
            Text("The time won't be added to your hours.")
        }
    }
}

/// "A long one. Did the timer keep running?": a quiet card with Keep (the measured time) and Use (the usual length).
/// Nothing changes unless a choice is tapped; the stepper still adjusts the length afterwards.
private struct LongSessionCard: View {
    let elapsed: TimeInterval
    /// Already rounded to 5 minutes.
    let usual: TimeInterval
    let choice: UsualSession.Choice
    let onChoose: (UsualSession.Choice) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 10) {
                Text("A long one. Did the timer keep running?")
                    .lgText(LGTextStyle(size: 14, weight: .semibold, relativeTo: .subheadline))
                Text("Your sessions are usually about \(DurationFormat.short(seconds: usual)).")
                    .lgText(LGTextStyle(size: 13, weight: .regular, relativeTo: .footnote), color: LGColor.inkMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)

            HStack(spacing: 8) {
                option(String(localized: "Keep \(DurationFormat.short(seconds: elapsed))"), .keep)
                option(String(localized: "Use \(DurationFormat.short(seconds: usual))"), .useUsual)
            }
        }
        .padding(14)
        .background(LGColor.longSessionCard, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func option(_ title: String, _ value: UsualSession.Choice) -> some View {
        let selected = choice == value
        return Button { onChoose(value) } label: {
            Text(verbatim: title)
                .lgText(LGTextStyle(size: 14, weight: .semibold, relativeTo: .subheadline), color: selected ? .white : LGColor.ink)
                .lineLimit(2).minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(selected ? LGColor.ink : LGColor.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
