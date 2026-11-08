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
    @State private var photo: Data?
    @State private var hidesDefault = false
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
            _photo = State(initialValue: editing.photo)
            _hidesDefault = State(initialValue: editing.hidesDefaultPicture)
        } else {
            _day = State(initialValue: Date())
            _hours = State(initialValue: 1)
            _minutes = State(initialValue: 0)
            _note = State(initialValue: "")
        }
    }

    private var calendar: Calendar { .current }
    private var seconds: Double { Double(hours * 3600 + minutes * 60) }

    /// Hours before the onboarding date are already part of the estimates, so the calendar starts there.
    /// (An older session that is being edited keeps its own day.)
    private var earliestDay: Date {
        let start = calendar.startOfDay(for: craft.createdAt)
        guard let editing else { return start }
        return min(start, calendar.startOfDay(for: editing.start))
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
                .accessibilityLabel(Labels.hours(hours) + " " + Labels.minutes(minutes))

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

                NotePhotoRow(photo: $photo, note: $note, photoID: editing?.id ?? UUID(),
                             defaultPicture: editing.map {
                                 DefaultPictureInfo(id: $0.id, start: $0.start, durationSec: $0.durationSec,
                                                    progress: $0.sunriseProgressAtEnd ?? 0)
                             },
                             hidesDefaultPicture: $hidesDefault)

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
            Button(editing == nil ? Labels.addLabel(seconds: seconds) : "Save changes", action: save)
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
        let saved = SessionRules.savedNote(note)
        if let editing {
            if !calendar.isDate(editing.start, inSameDayAs: day) {
                let time = calendar.dateComponents([.hour, .minute, .second], from: editing.start)
                editing.start = calendar.date(bySettingHour: time.hour ?? 12, minute: time.minute ?? 0, second: time.second ?? 0, of: day) ?? day
            }
            editing.durationSec = seconds
            editing.end = editing.start.addingTimeInterval(seconds)
            editing.note = saved
            if editing.hasPhoto != (photo != nil) || (photo != nil && photo != editing.photo) { editing.setPhoto(photo) }
            if editing.hidesDefaultPicture != hidesDefault { editing.hidesDefaultPicture = hidesDefault }
            editing.editedAt = Date()
        } else {
            context.insert(Session(craftId: craft.id, start: SessionRules.manualStart(on: day),
                                   durationSec: seconds, source: .manual, note: saved, photo: photo))
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
