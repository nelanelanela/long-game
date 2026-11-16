import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Settings › Your data › Data & storage (update 42, `design/redesign/DataStorage.dc.html`): iCloud, what the photos
/// and the default pictures take up, the CSV export and import, and Delete all data. Pushed from Settings; Your photos
/// is pushed from here, so its back button returns here.
struct DataStorageView: View {
    let craft: Craft

    @Environment(\.dismiss) private var dismiss
    @Environment(\.lgEmbedded) private var embedded
    @Environment(\.modelContext) private var context
    @Environment(TimerStore.self) private var timer
    @Environment(StoreHost.self) private var store
    @Environment(ICloudMonitor.self) private var monitor
    @Query private var allCrafts: [Craft]
    /// Only the sessions with a photo: the export file is built in the background from its own read of the
    /// database, so opening this screen never loads every session.
    @Query(filter: #Predicate<Session> { $0.hasPhoto }) private var photoSessions: [Session]

    @State private var csvURL: URL?
    /// Bumped after each save, so the export files are rebuilt (the previous build is cancelled).
    @State private var exportRequest = 0
    @State private var lettersURL: URL?
    @State private var confirmDelete = false
    @State private var confirmDeleteCopy = false
    @State private var pickingCSV = false
    @State private var importMessage: String?
    @State private var iCloudMessage: String?
    @State private var photoStats: [PhotoStat]?
    @State private var pictureCacheBytes: Int?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if !embedded {
                    ZStack {
                        Text("Data & storage").lgText(.navTitle).accessibilityAddTraits(.isHeader)
                        HStack {
                            LGIconButton(systemName: "chevron.left", label: "Back") { dismiss() }
                                .padding(.leading, -10)
                            Spacer()
                        }
                    }
                    .frame(height: 44)
                } else {
                    Text("Data & storage").lgText(.screenTitle).padding(.top, 8)
                        .accessibilityAddTraits(.isHeader)
                }
                iCloudSection
                storageSection
                dataSection
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .lgScreen()
        .lgHidesNavigationBar()
        .task(id: exportRequest) { await buildExportFiles() }
        .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { _ in exportRequest += 1 }
        .task { await refreshStorage() }
        .onChange(of: photoSessions.count) { _, _ in Task { await refreshStorage() } }
        .fileImporter(isPresented: $pickingCSV, allowedContentTypes: [.commaSeparatedText, .plainText]) { importCSV($0) }
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
            Text("Deletes your game, sessions, notes and photos from this iPhone and iCloud. This can't be undone.")
        }
    }

    // MARK: iCloud

    private var iCloudSection: some View {
        let switchState = ICloudSwitchState.make(availability: monitor.availability, wantsOn: store.iCloudOn)
        let status = monitor.status(enabled: store.iCloudOn)
        return VStack(alignment: .leading, spacing: 0) {
            SettingsGroupLabel(title: "iCloud")
            SettingsCard {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 3) {
                        Toggle("Save to iCloud", isOn: Binding(get: { switchState.isOn }, set: setICloud))
                            .lgText(.row).tint(LGColor.selectedFill)
                            .disabled(!switchState.isEnabled)
                        Text(status.text(now: Date()))
                            .lgText(.caption, color: LGColor.inkMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 10)
                    Divider().overlay(LGColor.divider)
                    dangerRow("Delete iCloud copy") { confirmDeleteCopy = true }
                        .disabled(!CloudSync.isAvailable || monitor.availability != .available)
                }
            }
            SettingsFootnote(text: "Private to your Apple Account. Deleting the iCloud copy keeps everything on this iPhone.")
        }
    }

    // MARK: Storage

    private var storageSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsGroupLabel(title: "Storage")
            SettingsCard {
                VStack(spacing: 0) {
                    NavigationLink { YourPhotosView() } label: { yourPhotosRow }
                        .buttonStyle(.plain)
                    Divider().overlay(LGColor.divider)
                    defaultPicturesRow
                }
            }
        }
    }

    private var yourPhotosRow: some View {
        HStack(spacing: 12) {
            Group {
                if let first = photoSessions.max(by: { $0.start < $1.start }) {
                    PhotoThumb(session: first, side: 32, radius: 8)
                } else {
                    RoundedRectangle(cornerRadius: 8, style: .continuous).fill(LGColor.chipFill).frame(width: 32, height: 32)
                        .overlay { Image(systemName: "photo").lgIcon(14, weight: .regular).foregroundStyle(LGColor.inkMuted) }
                }
            }
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text("Your photos").lgText(.row)
                Text(photoStats.map { DataStorageText.photos(count: $0.count, bytes: PhotoStorage.totalBytes($0)) } ?? " ")
                    .lgText(.caption, color: LGColor.inkMuted)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right").lgIcon(13, weight: .semibold).foregroundStyle(LGColor.inkMuted)
        }
        .padding(.vertical, 10)
        .frame(minHeight: 54)
        .contentShape(Rectangle())
    }

    private var defaultPicturesRow: some View {
        HStack(spacing: 12) {
            // A sample of the pictures the app draws (an evening session).
            SessionPictureCanvas(layout: SessionPictureLayout.make(seed: 1, startMinute: 18 * 60 + 45, minutes: 65, progress: 0.8))
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text("Default pictures").lgText(.row)
                Text("\(ByteText.size(pictureCacheBytes ?? 0)) cache · never your photos")
                    .lgText(.caption, color: LGColor.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Button {
                Task {
                    _ = await Task.detached(priority: .utility) { SessionPictureCache.clear() }.value
                    await refreshStorage()
                }
            } label: {
                Text("Clear")
                    .lgText(LGTextStyle(size: 14, weight: .semibold, relativeTo: .subheadline), color: LGColor.ember)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 44)
                    .background(LGColor.peachWashSetup, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Clear the default pictures cache. Your photos are not affected.")
        }
        .padding(.vertical, 6)
        .frame(minHeight: 54)
    }

    // MARK: Your data

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsGroupLabel(title: "Your data")
            SettingsCard {
                VStack(spacing: 0) {
                    Group {
                        if let csvURL {
                            ShareLink(items: [csvURL] + (lettersURL.map { [$0] } ?? [])) { exportRow }
                                .buttonStyle(.plain)
                        } else {
                            exportRow.opacity(0.4)
                        }
                    }
                    Divider().overlay(LGColor.divider)
                    Button { pickingCSV = true } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Import sessions").lgText(.row)
                                Text("From a CSV exported from Long Game")
                                    .lgText(.caption, color: LGColor.inkMuted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 8)
                            Image(systemName: "square.and.arrow.down").lgIcon(14, weight: .semibold).foregroundStyle(LGColor.inkMuted)
                        }
                        .padding(.vertical, 10)
                        .frame(minHeight: 54)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Divider().overlay(LGColor.divider)
                    dangerRow("Delete all data") { confirmDelete = true }
                }
            }
            SettingsFootnote(text: "Deletes your game, sessions, notes and photos from this iPhone and iCloud. This can't be undone.")
        }
    }

    private var exportRow: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Export sessions").lgText(.row)
                Text("A CSV file with dates, times and notes. Photos aren't included.")
                    .lgText(.caption, color: LGColor.inkMuted)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Image(systemName: "square.and.arrow.up").lgIcon(14, weight: .semibold).foregroundStyle(LGColor.inkMuted)
        }
        .padding(.vertical, 10)
        .frame(minHeight: 54)
        .contentShape(Rectangle())
    }

    private func dangerRow(_ title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title).lgText(.row, color: LGColor.danger)
                Spacer()
            }
            .frame(minHeight: 50)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Work

    private func refreshStorage() async {
        pictureCacheBytes = await Task.detached(priority: .utility) { SessionPictureCache.sizeOnDisk() }.value
        photoStats = await PhotoLibrary.loadStats(container: store.container)
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

    /// The sessions CSV and, when there are letters, the letters CSV, written in the background.
    private func buildExportFiles() async {
        let container = store.container
        let files = await Task.detached(priority: .utility) {
            Signposts.measure("Export files") { ExportFiles.write(container: container) }
        }.value
        guard !Task.isCancelled else { return }
        csvURL = files.sessions
        lettersURL = files.letters
    }

    private func importCSV(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url), let text = String(data: data, encoding: .utf8) else {
            importMessage = String(localized: "That file couldn't be read. Choose a CSV exported from Long Game.")
            return
        }
        let parsed = CSVImport.sessions(text)
        guard !parsed.rows.isEmpty else {
            importMessage = String(localized: "No sessions found. Choose a CSV exported from Long Game.")
            return
        }
        let allSessions = (try? context.fetch(FetchDescriptor<Session>())) ?? []
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
        DataReset.deleteAll(context: context, timer: timer)
    }
}

/// The files behind Export: every session (all crafts) and every letter, read from their own context so this can run
/// off the main thread.
enum ExportFiles {
    nonisolated static func write(container: ModelContainer) -> (sessions: URL?, letters: URL?) {
        let context = ModelContext(container)
        let crafts = (try? context.fetch(FetchDescriptor<Craft>())) ?? []
        let sessions = (try? context.fetch(FetchDescriptor<Session>())) ?? []
        let letters = (try? context.fetch(FetchDescriptor<Letter>())) ?? []
        let names = Dictionary(crafts.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        let rows = sessions.map {
            CSVExport.Row(craft: names[$0.craftId] ?? "", start: $0.start, durationSec: $0.durationSec,
                          source: $0.sourceRaw, note: $0.note ?? "")
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("LongGame-sessions.csv")
        do {
            try CSVExport.sessions(rows).write(to: url, atomically: true, encoding: .utf8)
            guard !letters.isEmpty else { return (url, nil) }
            let letterRows = letters.map {
                CSVExport.LetterRow(craft: names[$0.craftId] ?? "", written: $0.writtenAt, milestone: $0.milestone,
                                    opened: $0.openedAt, text: $0.text)
            }
            let lettersURL = FileManager.default.temporaryDirectory.appendingPathComponent("LongGame-letters.csv")
            try CSVExport.letters(letterRows).write(to: lettersURL, atomically: true, encoding: .utf8)
            return (url, lettersURL)
        } catch {
            return (nil, nil)
        }
    }
}

/// Deleting everything, shared by Data & storage and the debug Reset onboarding.
@MainActor
enum DataReset {
    static func deleteAll(context: ModelContext, timer: TimerStore) {
        timer.clear()
        NotificationPlanner.cancelAll()
        // One by one (not a batch delete) so every photo's file goes with its session.
        for session in (try? context.fetch(FetchDescriptor<Session>())) ?? [] { context.delete(session) }
        try? context.delete(model: YearEstimate.self)
        try? context.delete(model: Craft.self)
        try? context.delete(model: AppSettings.self)
        try? context.delete(model: TargetPeriod.self)
        try? context.delete(model: Letter.self)
        try? context.save()
        UserDefaults.standard.removeObject(forKey: Notifications.askedKey)
    }
}

/// The small words on Settings' Data & storage row and on the Your photos row.
enum DataStorageText {
    static func photos(count: Int, bytes: Int) -> String {
        let n = count == 1 ? String(localized: "1 photo") : String(localized: "\(count) photos")
        return "\(n) · \(ByteText.size(bytes))"
    }

    /// "iCloud on · photos 486 MB · export"; "iCloud off" when it's off; no photos part before there are any.
    static func summary(iCloudOn: Bool, photoBytes: Int?) -> String {
        var parts = [iCloudOn ? String(localized: "iCloud on") : String(localized: "iCloud off")]
        if let photoBytes, photoBytes > 0 { parts.append(String(localized: "photos \(ByteText.size(photoBytes))")) }
        parts.append(String(localized: "export"))
        return parts.joined(separator: " · ")
    }
}

/// Settings' small grey group title ("Your data").
struct SettingsGroupLabel: View {
    let title: LocalizedStringKey
    var body: some View {
        Text(title)
            .lgText(LGTextStyle(size: 12, weight: .semibold, relativeTo: .caption), color: LGColor.inkMuted)
            .padding(.horizontal, 4)
            .padding(.top, 14)
            .padding(.bottom, 6)
            .accessibilityAddTraits(.isHeader)
    }
}

/// The small grey line under a Settings card.
struct SettingsFootnote: View {
    let text: LocalizedStringKey
    var body: some View {
        Text(text)
            .lgText(.caption, color: LGColor.inkMuted)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 4)
            .padding(.top, 6)
    }
}

/// A white Settings card.
struct SettingsCard<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        content.padding(.horizontal, 18).frame(maxWidth: .infinity, alignment: .leading).lgCard()
    }
}
