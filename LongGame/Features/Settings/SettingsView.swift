import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    let craft: Craft
    /// Closes Settings and History together, back to Home (the debug buttons need Home on screen).
    var closeAll: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.lgEmbedded) private var embedded
    @Environment(\.modelContext) private var context
    @Environment(TimerStore.self) private var timer
    @Query private var settingsRows: [AppSettings]
    @Query private var allCrafts: [Craft]
    @Query private var allSessions: [Session]
    @Query private var craftSessions: [Session]
    @Query private var craftEstimates: [YearEstimate]

    #if os(macOS)
    @AppStorage(DockVisibility.defaultsKey) private var showInDock = true
    #endif
    @State private var csvURL: URL?
    @State private var confirmDelete = false
    @State private var pickingCSV = false
    @State private var importMessage: String?
    @State private var notificationsDenied = false
    @Environment(StoreHost.self) private var store
    @Environment(ICloudMonitor.self) private var monitor
    @State private var confirmDeleteCopy = false
    @State private var iCloudMessage: String?
    @State private var showOneCraft = false

    init(craft: Craft, closeAll: (() -> Void)? = nil) {
        self.craft = craft
        self.closeAll = closeAll
        let id = craft.id
        _craftSessions = Query(filter: #Predicate<Session> { $0.craftId == id })
        _craftEstimates = Query(filter: #Predicate<YearEstimate> { $0.craftId == id })
    }

    private var settings: AppSettings? { settingsRows.first }
    private var archived: [Craft] { allCrafts.filter { !$0.isActive }.sorted { ($0.archivedAt ?? .distantPast) > ($1.archivedAt ?? .distantPast) } }

    /// Whole hours played so far, shown in the One craft sheet's confirmation.
    private var oneCraftHours: Int {
        ProgressSummary.make(estimates: craftEstimates.map(\.rate), sessions: craftSessions.map(\.record),
                             onboardingDate: craft.createdAt, weekStart: .localeDefault, now: Date()).wholeHours
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if !embedded {
                    HStack {
                        LGIconButton(systemName: "chevron.left", label: "Back") { dismiss() }
                            .padding(.leading, -10)
                        Spacer()
                    }
                    .frame(height: 44)
                }

                Text("Settings").lgText(.screenTitle).padding(.top, embedded ? 8 : -6)
                    .accessibilityAddTraits(.isHeader)

                supportCard
                iCloudCard
                if let settings {
                    weekCard(settings)
                    reminderCard(settings)
                    iconCard(settings)
                    soundsCard(settings)
                }
                #if os(iOS)
                FocusSettingsCard()
                #else
                dockCard
                #endif
                practiceCard
                dataCard
                #if DEBUG
                debugCard
                #endif
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .lgScreen()
        .lgHidesNavigationBar()
        .onAppear { ensureSettings(); buildCSV() }
        .onChange(of: allSessions.count) { _, _ in buildCSV() }
        .sheet(isPresented: $showOneCraft) {
            OneCraftSheet(craft: craft, totalHours: oneCraftHours)
                .lgSheetCard()
        }
        .fileImporter(isPresented: $pickingCSV, allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
            importCSV(result)
        }
        .alert("Import sessions", isPresented: Binding(get: { importMessage != nil }, set: { if !$0 { importMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importMessage ?? "")
        }
        .confirmationDialog("Delete iCloud copy?", isPresented: $confirmDeleteCopy, titleVisibility: .visible) {
            Button("Delete iCloud copy", role: .destructive, action: deleteICloudCopy)
        } message: {
            Text("This removes your game from iCloud and turns iCloud saving off. The data on this iPhone stays.")
        }
        .alert("iCloud", isPresented: Binding(get: { iCloudMessage != nil }, set: { if !$0 { iCloudMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(iCloudMessage ?? "")
        }
        .confirmationDialog("Delete all data?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete everything", role: .destructive, action: deleteAll)
        } message: {
            Text("Your crafts, estimates and sessions will be removed from this iPhone. This can't be undone.")
        }
    }

    // MARK: Cards

    private var supportCard: some View {
        card {
            NavigationLink {
                TipJarView()
            } label: {
                HStack(spacing: 14) {
                    TipSunIcon(tier: .sunrise).scaleEffect(0.8).frame(width: 32, height: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Support Long Game").lgText(.row)
                        if (settings?.tipCount ?? 0) > 0 {
                            Text("Thank you for your support").lgText(.caption, color: LGColor.inkMuted)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right").lgIcon(13, weight: .semibold).foregroundStyle(LGColor.inkMuted)
                }
                .frame(minHeight: 54)
                .contentShape(Rectangle())
            }
        }
    }

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

    #if os(macOS)
    /// Mac only, and kept on this Mac (not synced): off leaves only the sun in the menu bar.
    private var dockCard: some View {
        card {
            VStack(alignment: .leading, spacing: 2) {
                Toggle("Show in Dock", isOn: $showInDock).lgText(.row).tint(LGColor.ink)
                Text("Off keeps only the sun in the menu bar.")
                    .lgText(.caption, color: LGColor.inkMuted)
            }
            .padding(.vertical, 10)
        }
        .onChange(of: showInDock) { _, show in MacDock.apply(show: show) }
    }
    #endif

    private func soundsCard(_ settings: AppSettings) -> some View {
        card {
            VStack(alignment: .leading, spacing: 2) {
                Toggle("Giggle sound", isOn: Binding(get: { settings.giggleSound }, set: { settings.giggleSound = $0; save() }))
                    .lgText(.row).tint(LGColor.ink)
                Text("A little laugh when you tap the sun. It stays quiet when your iPhone is on silent.")
                    .lgText(.caption, color: LGColor.inkMuted)
            }
            .padding(.vertical, 10)
        }
    }

    /// Turning it off sets the plain icon; turning it on sets the stage for the current total.
    private func iconCard(_ settings: AppSettings) -> some View {
        let on = Binding(
            get: { settings.iconGrows },
            set: { newValue in
                settings.iconGrows = newValue
                save()
                let total = ProgressSummary.make(estimates: craftEstimates.map(\.rate), sessions: craftSessions.map(\.record),
                                                 onboardingDate: craft.createdAt, weekStart: settings.weekStart, now: Date()).total
                AppIconManager.apply(IconPlan.wanted(totalHours: total, growsWithYou: newValue),
                                     settings: settings, context: context, timerRunning: timer.isActive)
            })
        return card {
            VStack(alignment: .leading, spacing: 2) {
                Toggle("App icon grows with you", isOn: on).lgText(.row).tint(LGColor.ink)
                Text("Grows every 1,000 hours")
                    .lgText(.caption, color: LGColor.inkMuted)
            }
            .padding(.vertical, 10)
        }
    }

    private func reminderCard(_ settings: AppSettings) -> some View {
        let dailyOn = Binding(
            get: { settings.reminderTime != nil },
            set: { on in
                if on { enableNotifications { settings.reminderTime = defaultReminder(); save() } }
                else { settings.reminderTime = nil; save() }
            })
        let nudgeOn = Binding(
            get: { settings.rhythmNudge },
            set: { on in
                if on { enableNotifications { settings.rhythmNudge = true; save() } }
                else { settings.rhythmNudge = false; save() }
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
                    Toggle("Rhythm nudge", isOn: nudgeOn).lgText(.row).tint(LGColor.ink)
                    Text("At 7 pm on a day you usually practise, if you haven't yet. At most twice a week.")
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
                Divider().overlay(LGColor.divider)
                Button { showOneCraft = true } label: {
                    row("Switch to a new game", detail: nil)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(.isButton)
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
                Button { pickingCSV = true } label: {
                    row("Import sessions (CSV)", detail: nil, icon: "square.and.arrow.down")
                }
                .buttonStyle(.plain)
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

    /// Save to iCloud, how the sync is going, and Delete iCloud copy (which leaves this iPhone's data alone).
    private var iCloudCard: some View {
        let switchState = ICloudSwitchState.make(availability: monitor.availability, wantsOn: store.iCloudOn)
        let status = monitor.status(enabled: store.iCloudOn)
        return card {
            VStack(alignment: .leading, spacing: 0) {
                Toggle("Save to iCloud", isOn: Binding(get: { switchState.isOn }, set: setICloud))
                    .lgText(.row).tint(LGColor.ink).frame(minHeight: 54)
                    .disabled(!switchState.isEnabled)
                Text(status.text(now: Date()))
                    .lgText(.caption, color: LGColor.inkMuted)
                    .padding(.bottom, 12)
                Divider().overlay(LGColor.divider)
                Button { confirmDeleteCopy = true } label: {
                    HStack {
                        Text("Delete iCloud copy").lgText(.row, color: LGColor.danger)
                        Spacer()
                    }
                    .frame(minHeight: 54)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!CloudSync.isAvailable || monitor.availability != .available)
            }
        }
    }

    private func setICloud(_ on: Bool) {
        do { try store.setICloud(on) }
        catch { iCloudMessage = String(localized: "Couldn't change iCloud saving. Nothing was lost.") }
    }

    private func deleteICloudCopy() {
        Task {
            do { try await store.deleteICloudCopy() }
            catch { iCloudMessage = String(localized: "Couldn't delete the iCloud copy. Check your connection and try again.") }
        }
    }

    #if DEBUG
    @AppStorage("debug.pretendDays") private var pretendDays = 10
    @State private var confirmResetOnboarding = false

    private var debugCard: some View {
        card {
            VStack(alignment: .leading, spacing: 0) {
                Text("Debug only").lgText(.caption, color: LGColor.inkMuted).padding(.top, 12)
                Stepper("Pretend last session was \(Labels.days(pretendDays)) ago", value: $pretendDays, in: 7...200)
                    .lgText(.row).frame(minHeight: 54)
                Divider().overlay(LGColor.divider)
                Button("Show Welcome back on Home") {
                    DebugOptions.setPretendLastSessionDaysAgo(pretendDays)
                    (closeAll ?? { dismiss() })()
                }
                .lgText(.rowStrong).frame(minHeight: 54)
                Divider().overlay(LGColor.divider)
                VStack(alignment: .leading, spacing: 2) {
                    Button("Fill a sample year") { fillSampleYear() }
                        .lgText(.rowStrong).frame(minHeight: 54, alignment: .leading)
                    Button("Remove the sample year") { removeSampleYear() }
                        .lgText(.rowStrong).frame(minHeight: 54, alignment: .leading)
                    Text("Adds about 60% of the days of this year so far as sessions, six with a photo, so History → Growth → Your year shows a full card straight away. Remove deletes only those sessions.")
                        .lgText(.caption, color: LGColor.inkMuted)
                        .padding(.bottom, 12)
                }
                Divider().overlay(LGColor.divider)
                VStack(alignment: .leading, spacing: 2) {
                    Button("Show Meet your future self again") {
                        settings?.futureSelfShown = false
                        try? context.save()
                        (closeAll ?? { dismiss() })()
                    }
                    .lgText(.rowStrong).frame(minHeight: 54, alignment: .leading)
                    Text("Back on Home the sheet opens by itself, as it does the first time after onboarding.")
                        .lgText(.caption, color: LGColor.inkMuted)
                        .padding(.bottom, 12)
                }
                Divider().overlay(LGColor.divider)
                VStack(alignment: .leading, spacing: 2) {
                    Button("Year of pace ends in 10 days") { pretendYearOfPaceEnds(inDays: 10) }
                        .lgText(.rowStrong).frame(minHeight: 54, alignment: .leading)
                    Button("Year of pace ended yesterday") { pretendYearOfPaceEnds(inDays: -1) }
                        .lgText(.rowStrong).frame(minHeight: 54, alignment: .leading)
                    Text("Moves the dates of your target. Back on Home you see the reminder in the target row, or the New year of pace sheet.")
                        .lgText(.caption, color: LGColor.inkMuted)
                        .padding(.bottom, 12)
                }
                Divider().overlay(LGColor.divider)
                VStack(alignment: .leading, spacing: 2) {
                    Button("Reset onboarding") { confirmResetOnboarding = true }
                        .lgText(.rowStrong, color: LGColor.danger).frame(minHeight: 54, alignment: .leading)
                    Text("Deletes all data and starts again from Welcome, with the three intro pages.")
                        .lgText(.caption, color: LGColor.inkMuted)
                        .padding(.bottom, 12)
                }
                .confirmationDialog("Reset onboarding?", isPresented: $confirmResetOnboarding, titleVisibility: .visible) {
                    Button("Delete everything and start over", role: .destructive, action: deleteAll)
                } message: {
                    Text("Debug only. Your crafts, estimates and sessions are removed from this iPhone.")
                }
                Divider().overlay(LGColor.divider)
                VStack(alignment: .leading, spacing: 2) {
                    Button("Jump total to just under a whole hour") { jumpTotalToJustUnderWholeHour() }
                        .lgText(.rowStrong).frame(minHeight: 54, alignment: .leading)
                    Text("Adds a short debug session (delete it from Recent afterwards) so the total sits 20 seconds below the next whole hour. Start a session and the sun bounces about 20 seconds later.")
                        .lgText(.caption, color: LGColor.inkMuted)
                        .padding(.bottom, 12)
                }
            }
        }
    }

    private static let sampleNote = "Debug: sample year"

    /// Sessions on about 60% of the days of this year so far, six of them with a made-up photo.
    private func fillSampleYear() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard var day = cal.date(from: DateComponents(year: cal.component(.year, from: today), month: 1, day: 1)) else { return }
        let id = craft.id
        let start = max(cal.startOfDay(for: craft.createdAt), day)
        var n = 0
        var photoDays: [Date] = []
        while day < today {
            if day >= start, (n * 7919) % 10 < 6 {
                let minutes = 20 + (n * 37) % 100
                let session = Session(craftId: id, start: SessionRules.manualStart(on: day), durationSec: Double(minutes * 60),
                                      source: .manual, note: Self.sampleNote)
                context.insert(session)
                photoDays.append(day)
                if photoDays.count % 9 == 0, let data = Self.samplePhoto(seed: photoDays.count) { session.setPhoto(data) }
            }
            day = cal.date(byAdding: .day, value: 1, to: day) ?? today
            n += 1
        }
        try? context.save()
        (closeAll ?? { dismiss() })()
    }

    private func removeSampleYear() {
        for session in craftSessions where session.note == Self.sampleNote { context.delete(session) }
        try? context.save()
        (closeAll ?? { dismiss() })()
    }

    /// A soft coloured picture, prepared the same way as a real photo.
    private static func samplePhoto(seed: Int) -> Data? {
        let hue = Double((seed * 47) % 100) / 100
        let view = ZStack {
            Color(hue: hue, saturation: 0.35, brightness: 0.95)
            Circle().fill(Color(hue: hue, saturation: 0.6, brightness: 0.75)).frame(width: 400, height: 400)
        }
        .frame(width: 900, height: 900)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        #if canImport(UIKit)
        let image = renderer.uiImage
        #else
        let image = renderer.nsImage
        #endif
        return image?.jpegData(compressionQuality: 0.9).flatMap(PhotoProcessing.prepare)
    }

    private func pretendYearOfPaceEnds(inDays days: Int) {
        guard let settings, settings.weeklyTargetHours > 0 else { return }
        let calendar = Calendar.current
        let ends = calendar.date(byAdding: .day, value: days, to: calendar.startOfDay(for: Date())) ?? Date()
        settings.targetEndsAt = ends
        settings.targetSetAt = calendar.date(byAdding: .month, value: -12, to: ends)
        settings.targetPromptShownAt = nil
        try? context.save()
        (closeAll ?? { dismiss() })()
    }

    private func jumpTotalToJustUnderWholeHour() {
        let id = craft.id
        let estimates = (try? context.fetch(FetchDescriptor<YearEstimate>(predicate: #Predicate { $0.craftId == id }))) ?? []
        let total = ProgressSummary.make(estimates: estimates.map(\.rate), sessions: craftSessions.map(\.record),
                                         onboardingDate: craft.createdAt, weekStart: settings?.weekStart ?? .localeDefault,
                                         now: Date()).total
        let seconds = DebugOptions.secondsToJustUnderWholeHour(total: total)
        context.insert(Session(craftId: id, start: SessionRules.manualStart(on: Date()), durationSec: seconds,
                               source: .manual, note: "Debug: total set to just under a whole hour"))
        try? context.save()
        (closeAll ?? { dismiss() })()
    }
    #endif

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
                                          reminderDays: settings.reminderDays, rhythmNudge: settings.rhythmNudge,
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

    private func importCSV(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url), let text = String(data: data, encoding: .utf8) else {
            importMessage = "That file couldn't be read. Choose a CSV exported from Long Game."
            return
        }
        let parsed = CSVImport.sessions(text)
        guard !parsed.rows.isEmpty else {
            importMessage = "No sessions found. Choose a CSV exported from Long Game."
            return
        }
        let existing = Set(allSessions.map { CSVImport.key(craftId: $0.craftId, start: $0.start, durationSec: $0.durationSec) })
        let plan = CSVImport.plan(rows: parsed.rows,
                                  crafts: allCrafts.map { .init(id: $0.id, name: $0.name) },
                                  activeId: craft.id, existingKeys: existing)
        for item in plan.toAdd {
            let source = SessionSource(rawValue: item.row.source) ?? .manual
            let note = item.row.note.isEmpty ? nil : item.row.note
            context.insert(Session(craftId: item.craftId, start: item.row.start, durationSec: item.row.durationSec,
                                   source: source, note: note))
        }
        try? context.save()

        var message = plan.toAdd.count == 1 ? "Added 1 session." : "Added \(plan.toAdd.count) sessions."
        if plan.duplicates > 0 { message += " \(plan.duplicates) already here, left as they were." }
        if plan.unmatched > 0 { message += " \(plan.unmatched) belonged to crafts that aren't on this iPhone and were skipped." }
        if parsed.skipped > 0 { message += " \(parsed.skipped) lines couldn't be read." }
        importMessage = message
    }

    private func deleteAll() {
        timer.clear()
        NotificationPlanner.cancelAll()
        // One by one (not a batch delete) so every photo's file goes with its session.
        for session in (try? context.fetch(FetchDescriptor<Session>())) ?? [] { context.delete(session) }
        try? context.delete(model: YearEstimate.self)
        try? context.delete(model: Craft.self)
        try? context.delete(model: AppSettings.self)
        try? context.delete(model: TargetPeriod.self)
        try? context.save()
        UserDefaults.standard.removeObject(forKey: "notifications.asked")
    }
}
