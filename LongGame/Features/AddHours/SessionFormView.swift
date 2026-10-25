import SwiftUI
import SwiftData

/// "Add past hours" — also used to edit an existing session.
struct SessionFormView: View {
    let craft: Craft
    let sessions: [Session]
    let editing: Session?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var day: Date
    @State private var hours: Int
    @State private var minutes: Int
    @State private var note: String
    @State private var confirmDelete = false

    init(craft: Craft, sessions: [Session], editing: Session?) {
        self.craft = craft
        self.sessions = sessions
        self.editing = editing
        if let editing {
            let total = Int((editing.durationSec / 60).rounded())
            _day = State(initialValue: editing.start)
            _hours = State(initialValue: min(12, total / 60))
            _minutes = State(initialValue: (total % 60) / 5 * 5)
            _note = State(initialValue: editing.note ?? "")
        } else {
            _day = State(initialValue: Date())
            _hours = State(initialValue: 1)
            _minutes = State(initialValue: 0)
            _note = State(initialValue: "")
        }
    }

    private var calendar: Calendar { .current }
    private var seconds: Double { Double(hours * 3600 + minutes * 60) }

    private var earliestDay: Date {
        calendar.date(from: DateComponents(year: craft.startYear, month: 1, day: 1)) ?? Date.distantPast
    }

    private var otherSecondsThatDay: Double {
        sessions
            .filter { $0 !== editing && calendar.isDate($0.start, inSameDayAs: day) }
            .reduce(0) { $0 + $1.durationSec }
    }

    private var fits: Bool { SessionRules.fits(existingSecondsThatDay: otherSecondsThatDay, adding: seconds) }
    private var canSave: Bool { seconds > 0 && fits }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header

                VStack(spacing: 4) {
                    Text(DurationFormat.hoursMinutes(seconds: seconds)).lgNumber(.yearNumber)
                    Text("hours : minutes").lgText(.caption, color: LGColor.inkMuted)
                }
                .padding(.top, 12)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(hours) hours \(minutes) minutes")

                VStack(spacing: 0) {
                    row("Day") {
                        DatePicker("Day", selection: $day, in: earliestDay...Date(), displayedComponents: .date)
                            .labelsHidden()
                            .tint(LGColor.ink)
                    }
                    Divider().overlay(LGColor.divider)
                    row("Hours") {
                        Picker("Hours", selection: $hours) {
                            ForEach(0...12, id: \.self) { Text("\($0)").tag($0) }
                        }
                        .menuStyleChip()
                    }
                    Divider().overlay(LGColor.divider)
                    row("Minutes") {
                        Picker("Minutes", selection: $minutes) {
                            ForEach(Array(stride(from: 0, through: 55, by: 5)), id: \.self) { Text("\($0)").tag($0) }
                        }
                        .menuStyleChip()
                    }
                }
                .padding(.horizontal, 18)
                .lgCard()

                if !fits {
                    Text("That would be more than 24 hours on this day. Lower the time or pick another day.")
                        .lgText(.caption, color: LGColor.danger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                VStack(alignment: .leading, spacing: 8) {
                    LGSectionLabel("Note")
                    TextField("Optional", text: $note, axis: .vertical)
                        .lineLimit(3...5)
                        .lgText(.row)
                        .padding(.horizontal, 18).padding(.vertical, 14)
                        .lgCard()
                        .onChange(of: note) { _, new in
                            if new.count > SessionRules.maxNoteLength { note = String(new.prefix(SessionRules.maxNoteLength)) }
                        }
                    if note.count > 240 {
                        Text("\(note.count) / \(SessionRules.maxNoteLength)").lgText(.tiny, color: LGColor.inkMuted)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }

                if editing != nil {
                    Button("Delete session") { confirmDelete = true }
                        .buttonStyle(.lg(.text))
                        .foregroundStyle(LGColor.danger)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            Button(editing == nil ? DurationFormat.addLabel(seconds: seconds) : "Save changes", action: save)
                .buttonStyle(.lg(.primary))
                .disabled(!canSave)
                .padding(.horizontal, 24).padding(.vertical, 8)
                .background(LGColor.background)
        }
        .lgScreen()
        .confirmationDialog("Delete this session?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let editing { context.delete(editing); try? context.save() }
                dismiss()
            }
        } message: {
            Text("Its hours will be removed from your total.")
        }
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        HStack {
            LGIconButton(systemName: "xmark", label: "Cancel") { dismiss() }
                .padding(.leading, -10)
            Spacer()
            Text(editing == nil ? "Add past hours" : "Edit session").lgText(.navTitle)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Color.clear.frame(width: 34, height: 44)
        }
        .padding(.top, 8)
    }

    private func row<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(title).lgText(.row)
            Spacer()
            content()
        }
        .frame(minHeight: 54)
    }

    private func save() {
        guard canSave else { return }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if let editing {
            if !calendar.isDate(editing.start, inSameDayAs: day) {
                let time = calendar.dateComponents([.hour, .minute, .second], from: editing.start)
                editing.start = calendar.date(bySettingHour: time.hour ?? 12, minute: time.minute ?? 0, second: time.second ?? 0, of: day) ?? day
            }
            editing.durationSec = seconds
            editing.end = editing.start.addingTimeInterval(seconds)
            editing.note = trimmed.isEmpty ? nil : trimmed
            editing.editedAt = Date()
        } else {
            context.insert(Session(craftId: craft.id, start: SessionRules.manualStart(on: day),
                                   durationSec: seconds, source: .manual, note: trimmed.isEmpty ? nil : trimmed))
        }
        try? context.save()
        dismiss()
    }
}

private extension View {
    func menuStyleChip() -> some View {
        self.pickerStyle(.menu)
            .labelsHidden()
            .tint(LGColor.ink)
            .padding(.horizontal, 6)
            .background(LGColor.chipFill, in: RoundedRectangle(cornerRadius: 10))
    }
}
