import SwiftUI

/// Shown when the user taps Finish: adjust the time, add a note, save or discard.
struct FinishSheet: View {
    let elapsed: TimeInterval
    let onSave: (_ duration: TimeInterval, _ note: String?) -> Void
    let onDiscard: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var duration: TimeInterval
    @State private var note = ""
    @State private var confirmDiscard = false

    init(elapsed: TimeInterval, onSave: @escaping (TimeInterval, String?) -> Void, onDiscard: @escaping () -> Void) {
        self.elapsed = elapsed
        self.onSave = onSave
        self.onDiscard = onDiscard
        _duration = State(initialValue: elapsed)
    }

    private var canSave: Bool { FinishRules.canSave(elapsed: elapsed) }

    var body: some View {
        VStack(spacing: 20) {
            Text("Finish session").lgText(.navTitle)
                .accessibilityAddTraits(.isHeader)

            if canSave {
                HStack {
                    stepper("minus", "Less time", enabled: duration > FinishRules.minimumSave) {
                        duration = FinishRules.lowered(duration)
                    }
                    Spacer()
                    VStack(spacing: 4) {
                        Text(DurationFormat.hoursMinutes(seconds: duration)).lgNumber(.yearNumber)
                        Text("hours : minutes").lgText(.caption, color: LGColor.inkMuted)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(DurationFormat.short(seconds: duration))
                    Spacer()
                    stepper("plus", "More time", enabled: duration < elapsed) {
                        duration = FinishRules.raised(duration, elapsed: elapsed)
                    }
                }
                Text("You can trim up to what you really practised.")
                    .lgText(.caption, color: LGColor.inkMuted)

                TextField("Add a note (optional)", text: $note, axis: .vertical)
                    .lineLimit(2...4)
                    .lgText(.row)
                    .padding(.horizontal, 18).padding(.vertical, 14)
                    .lgCard()
                    .onChange(of: note) { _, new in
                        if new.count > SessionRules.maxNoteLength { note = String(new.prefix(SessionRules.maxNoteLength)) }
                    }

                Button("Save") {
                    let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
                    onSave(duration, trimmed.isEmpty ? nil : trimmed)
                }
                .buttonStyle(.lg(.primary))
            } else {
                SunView(face: .sleepy).frame(width: 80, height: 80)
                Text("Sessions under a minute can't be saved.")
                    .lgText(.body, color: LGColor.inkMuted)
                    .multilineTextAlignment(.center)
            }

            Button("Discard") { confirmDiscard = true }
                .buttonStyle(.lg(.text))
                .foregroundStyle(LGColor.danger)
        }
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(LGColor.background)
        .presentationDetents([.height(canSave ? 520 : 340), .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(32)
        .confirmationDialog("Discard this session?", isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button("Discard", role: .destructive, action: onDiscard)
        } message: {
            Text("The time won't be added to your hours.")
        }
    }

    private func stepper(_ icon: String, _ label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(LGColor.ink)
                .frame(width: 52, height: 52)
                .background(LGColor.chipFill, in: Circle())
        }
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
        .accessibilityLabel(label)
    }
}
