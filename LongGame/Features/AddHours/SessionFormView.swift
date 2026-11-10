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
            VStack(spacing: 0) {
                header

                VStack(spacing: 6) {
                    Text(DurationFormat.hoursMinutes(seconds: seconds))
                        .lgNumber(LGTextStyle(size: 76, weight: .bold, relativeTo: .largeTitle, tracking: -3.4))
                    Text(RelativeDay.full(day)).lgText(.note, color: LGColor.inkMuted)
                }
                .padding(.top, 24)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Labels.hours(hours) + " " + Labels.minutes(minutes) + ", " + RelativeDay.full(day))

                VStack(spacing: 0) {
                    row("Day") {
                        DatePicker("Day", selection: $day, in: earliestDay...Date(), displayedComponents: .date)
                            .labelsHidden()
                            .tint(LGColor.ink)
                    }
                    Divider().overlay(LGColor.divider)
                    stepperRow("Hours", value: $hours, range: 0...12, step: 1, spoken: Labels.hours(hours),
                               less: "Fewer hours", more: "More hours")
                    Divider().overlay(LGColor.divider)
                    stepperRow("Minutes", value: $minutes, range: 0...55, step: 5, spoken: Labels.minutes(minutes),
                               less: "Fewer minutes", more: "More minutes")
                }
                .padding(.horizontal, 16).padding(.vertical, 2)
                .lgCard(radius: 20)
                .padding(.top, 26)

                if !fits {
                    Text("That would be more than 24 hours on this day. Lower the time or pick another day.")
                        .lgText(.caption, color: LGColor.danger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 10)
                }

                NotePhotoRow(photo: $photo, note: $note, photoID: editing?.id ?? UUID(),
                             defaultPicture: editing.map {
                                 DefaultPictureInfo(id: $0.id, start: $0.start, durationSec: $0.durationSec,
                                                    progress: $0.sunriseProgressAtEnd ?? 0)
                             },
                             hidesDefaultPicture: $hidesDefault)
                    .padding(.top, 12)

                if editing != nil {
                    Button("Delete session") { confirmDelete = true }
                        .buttonStyle(.lg(.text))
                        .foregroundStyle(LGColor.danger)
                        .padding(.top, 12)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            Button(editing == nil ? Labels.addLabel(seconds: seconds) : "Save changes", action: save)
                .buttonStyle(.lg(.primary))
                .disabled(!canSave)
                .padding(.horizontal, 24).padding(.vertical, 8)
        }
        .lgSetupScreen(fadeBy: 0.34)
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

    /// "Cancel" as words on the left, the title in the middle.
    private var header: some View {
        ZStack {
            Text(editing == nil ? "Add past hours" : "Edit session")
                .lgText(LGTextStyle(size: 16, weight: .semibold, relativeTo: .body))
                .accessibilityAddTraits(.isHeader)
            HStack {
                Button { dismiss() } label: {
                    Text("Cancel").lgText(LGTextStyle(size: 16, weight: .medium, relativeTo: .body))
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Spacer()
            }
        }
        .frame(minHeight: 44)
        .padding(.top, 16)
    }

    private func row<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(title).lgText(.body)
            Spacer()
            content()
        }
        .frame(minHeight: 52)
    }

    /// Label on the left, then − value + (hold to repeat). One adjustable element for VoiceOver.
    private func stepperRow(_ title: LocalizedStringKey, value: Binding<Int>, range: ClosedRange<Int>, step: Int, spoken: String,
                            less: String, more: String) -> some View {
        row(title) {
            HStack(spacing: 10) {
                LGRepeatButton(systemName: "minus", label: less, enabled: value.wrappedValue > range.lowerBound, diameter: 36) {
                    value.wrappedValue = max(range.lowerBound, value.wrappedValue - step)
                }
                .frame(width: 44, height: 44)
                Text("\(value.wrappedValue)")
                    .lgText(LGTextStyle(size: 17, weight: .semibold, relativeTo: .body))
                    .monospacedDigit()
                    .frame(minWidth: 40)
                    .accessibilityHidden(true)
                LGRepeatButton(systemName: "plus", label: more, enabled: value.wrappedValue < range.upperBound, diameter: 36) {
                    value.wrappedValue = min(range.upperBound, value.wrappedValue + step)
                }
                .frame(width: 44, height: 44)
            }
            .padding(.trailing, -4)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(spoken)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value.wrappedValue = min(range.upperBound, value.wrappedValue + step)
            case .decrement: value.wrappedValue = max(range.lowerBound, value.wrappedValue - step)
            @unknown default: break
            }
        }
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
