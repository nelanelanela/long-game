import SwiftUI
import SwiftData
import UIKit
import AuthenticationServices

struct SettingsView: View {
    let craft: Craft

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(TimerStore.self) private var timer
    @Query private var settingsRows: [AppSettings]
    @Query private var allCrafts: [Craft]
    @Query private var allSessions: [Session]
    @Query private var craftSessions: [Session]

    @State private var csvURL: URL?
    @State private var confirmDelete = false
    @State private var notificationsDenied = false
    @State private var syncOn = CloudSync.isEnabled
    @Environment(AccountStore.self) private var account

    init(craft: Craft) {
        self.craft = craft
        let id = craft.id
        _craftSessions = Query(filter: #Predicate<Session> { $0.craftId == id })
    }

    private var settings: AppSettings? { settingsRows.first }
    private var archived: [Craft] { allCrafts.filter { !$0.isActive }.sorted { ($0.archivedAt ?? .distantPast) > ($1.archivedAt ?? .distantPast) } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    LGIconButton(systemName: "chevron.left", label: "Back") { dismiss() }
                        .padding(.leading, -10)
                    Spacer()
                }
                .frame(height: 44)

                Text("Settings").lgText(.screenTitle).padding(.top, -6)
                    .accessibilityAddTraits(.isHeader)

                if let settings {
                    weekCard(settings)
                    reminderCard(settings)
                }
                practiceCard
                dataCard
                syncCard
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .lgScreen()
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { ensureSettings(); buildCSV() }
        .onChange(of: allSessions.count) { _, _ in buildCSV() }
        .confirmationDialog("Delete all data?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete everything", role: .destructive, action: deleteAll)
        } message: {
            Text("Your crafts, estimates and sessions will be removed from this iPhone. This can't be undone.")
        }
    }

    // MARK: Cards

    private func weekCard(_ settings: AppSettings) -> some View {
        card {
            HStack {
                Text("Week starts on").lgText(.row)
                Spacer()
                Picker("Week starts on", selection: Binding(get: { settings.weekStart }, set: { settings.weekStart = $0; save() })) {
                    Text("Monday").tag(WeekStart.monday)
                    Text("Sunday").tag(WeekStart.sunday)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 190)
            }
            .frame(minHeight: 54)
        }
    }

    private func reminderCard(_ settings: AppSettings) -> some View {
        let dailyOn = Binding(
            get: { settings.reminderTime != nil },
            set: { on in
                if on { enableNotifications { settings.reminderTime = defaultReminder(); save() } }
                else { settings.reminderTime = nil; save() }
            })
        let streakOn = Binding(
            get: { settings.streakReminder },
            set: { on in
                if on { enableNotifications { settings.streakReminder = true; save() } }
                else { settings.streakReminder = false; save() }
            })
        return card {
            VStack(spacing: 0) {
                Toggle("Daily reminder", isOn: dailyOn).lgText(.row).tint(LGColor.ink).frame(minHeight: 54)
                if let time = settings.reminderTime {
                    Divider().overlay(LGColor.divider)
                    HStack {
                        Text("Time").lgText(.row)
                        Spacer()
                        DatePicker("Time", selection: Binding(get: { time }, set: { settings.reminderTime = $0; save() }),
                                   displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    }
                    .frame(minHeight: 54)
                    Divider().overlay(LGColor.divider)
                    dayChips(settings).padding(.vertical, 12)
                }
                Divider().overlay(LGColor.divider)
                VStack(alignment: .leading, spacing: 2) {
                    Toggle("Streak reminder", isOn: streakOn).lgText(.row).tint(LGColor.ink)
                    Text("At 8 pm, if you haven't practised and have a streak of 3 days or more.")
                        .lgText(.caption, color: LGColor.inkMuted)
                }
                .padding(.vertical, 10)
                if notificationsDenied {
                    Text("Notifications are off for Long Game. Turn them on in the iPhone's Settings app.")
                        .lgText(.caption, color: LGColor.danger)
                        .padding(.bottom, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func dayChips(_ settings: AppSettings) -> some View {
        let symbols = Calendar.current.veryShortStandaloneWeekdaySymbols
        let order = settings.weekStart == .monday ? [2, 3, 4, 5, 6, 7, 1] : [1, 2, 3, 4, 5, 6, 7]
        return HStack(spacing: 6) {
            ForEach(order, id: \.self) { weekday in
                let selected = settings.reminderDays.contains(weekday)
                Button {
                    if selected { settings.reminderDays.removeAll { $0 == weekday } } else { settings.reminderDays.append(weekday) }
                    save()
                } label: {
                    Text(symbols[weekday - 1])
                        .lgText(.rowStrong, color: selected ? .white : LGColor.ink)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(selected ? LGColor.ink : LGColor.chipFill, in: Circle())
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Calendar.current.weekdaySymbols[weekday - 1])
                .accessibilityAddTraits(selected ? [.isSelected] : [])
            }
        }
    }

    private var practiceCard: some View {
        card {
            VStack(spacing: 0) {
                NavigationLink {
                    EstimatesEditorView(craft: craft)
                } label: {
                    row("Your estimates", detail: "\(craft.startYear)–\(Calendar.current.component(.year, from: craft.createdAt))")
                }
                Divider().overlay(LGColor.divider)
                NavigationLink {
                    ArchivedCraftsView(crafts: archived)
                } label: {
                    row("Archived crafts", detail: archived.isEmpty ? "None" : "\(archived.count)")
                }
            }
        }
    }

    private var dataCard: some View {
        card {
            VStack(spacing: 0) {
                if let csvURL {
                    ShareLink(item: csvURL) { row("Export sessions (CSV)", detail: nil, icon: "square.and.arrow.up") }
                } else {
                    row("Export sessions (CSV)", detail: nil, icon: "square.and.arrow.up").opacity(0.4)
                }
                Divider().overlay(LGColor.divider)
                Button { confirmDelete = true } label: {
                    HStack {
                        Text("Delete all data").lgText(.row, color: LGColor.danger)
                        Spacer()
                    }
                    .frame(minHeight: 54)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var syncCard: some View {
        if CloudSync.isAvailable {
            card {
                VStack(alignment: .leading, spacing: 0) {
                    Toggle("iCloud sync", isOn: Binding(get: { syncOn }, set: { syncOn = $0; CloudSync.isEnabled = $0 }))
                        .lgText(.row).tint(LGColor.ink).frame(minHeight: 54)
                    Text(syncOn
                         ? "Your hours are kept in your private iCloud. Close and reopen Long Game to apply the change."
                         : "Turn on to keep your hours safe and on all your devices. Close and reopen Long Game to apply the change.")
                        .lgText(.caption, color: LGColor.inkMuted)
                        .padding(.bottom, 12)
                    Divider().overlay(LGColor.divider)
                    if account.isSignedIn {
                        HStack {
                            Text("Signed in with Apple").lgText(.row)
                            Spacer()
                            Button("Sign out") { account.signOut() }.buttonStyle(.lg(.text))
                        }
                        .frame(minHeight: 54)
                    } else {
                        SignInWithAppleButton(.signIn) { request in
                            request.requestedScopes = []
                        } onCompletion: { account.handle($0) }
                            .signInWithAppleButtonStyle(.black)
                            .frame(height: 48)
                            .padding(.vertical, 10)
                    }
                }
            }
        } else {
            card {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("iCloud sync").lgText(.row)
                        Spacer()
                        Text("Coming later").lgText(.row, color: LGColor.inkMuted)
                    }
                    Text("Your hours stay on this iPhone for now. Sync and Sign in with Apple need an Apple Developer account to switch on.")
                        .lgText(.caption, color: LGColor.inkMuted)
                }
                .padding(.vertical, 12)
            }
        }
    }

    // MARK: Helpers

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content().padding(.horizontal, 18).frame(maxWidth: .infinity, alignment: .leading).lgCard()
    }

    private func row(_ title: String, detail: String?, icon: String = "chevron.right") -> some View {
        HStack {
            Text(title).lgText(.row)
            Spacer()
            if let detail { Text(detail).lgText(.row, color: LGColor.inkMuted) }
            Image(systemName: icon).font(.system(size: 13, weight: .semibold)).foregroundStyle(LGColor.inkMuted)
        }
        .frame(minHeight: 54)
        .contentShape(Rectangle())
    }

    private func defaultReminder() -> Date {
        Calendar.current.date(bySettingHour: 19, minute: 0, second: 0, of: Date()) ?? Date()
    }

    private func save() {
        try? context.save()
        Task { await refreshNotifications() }
    }

    private func refreshNotifications() async {
        guard let settings else { return }
        await NotificationPlanner.refresh(craftName: craft.name, reminderTime: settings.reminderTime,
                                          reminderDays: settings.reminderDays, streakReminder: settings.streakReminder,
                                          sessions: craftSessions.map(\.record))
    }

    private func ensureSettings() {
        if settingsRows.isEmpty { context.insert(AppSettings()); try? context.save() }
    }

    private func enableNotifications(then apply: @escaping () -> Void) {
        Task {
            let granted = await Notifications.requestAuthorization()
            notificationsDenied = !granted
            if granted { apply() }
        }
    }

    private func buildCSV() {
        let names = Dictionary(uniqueKeysWithValues: allCrafts.map { ($0.id, $0.name) })
        let rows = allSessions.map {
            CSVExport.Row(craft: names[$0.craftId] ?? "", start: $0.start, durationSec: $0.durationSec,
                          source: $0.sourceRaw, note: $0.note ?? "")
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("LongGame-sessions.csv")
        do {
            try CSVExport.sessions(rows).write(to: url, atomically: true, encoding: .utf8)
            csvURL = url
        } catch {
            csvURL = nil
        }
    }

    private func deleteAll() {
        timer.clear()
        NotificationPlanner.cancelAll()
        try? context.delete(model: Session.self)
        try? context.delete(model: YearEstimate.self)
        try? context.delete(model: Craft.self)
        try? context.delete(model: AppSettings.self)
        try? context.save()
        UserDefaults.standard.removeObject(forKey: "notifications.asked")
    }
}
