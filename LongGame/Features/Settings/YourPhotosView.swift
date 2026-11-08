import SwiftUI
import SwiftData

/// Settings › iCloud & storage › Your photos: what the photos you added take up, one card per year, and a way to
/// delete a whole year's photos (the sessions, hours and notes stay).
struct YourPhotosView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(StoreHost.self) private var store
    @Query private var sessions: [Session]
    @Query private var settingsRows: [AppSettings]

    @State private var stats: [PhotoStat]?
    @State private var asking: PhotoYearGroup?

    /// Re-read the sizes when photos come or go.
    private var photoCount: Int { sessions.filter(\.hasPhoto).count }

    private var groups: [PhotoYearGroup] { PhotoStorage.groups(stats ?? []) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                if stats == nil {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                } else {
                    ForEach(groups) { group in yearCard(group).padding(.top, 16) }
                }
                Text("Deleting photos keeps your sessions, hours and notes. Tap a photo in History to delete just one.")
                    .lgText(LGTextStyle(size: 12, weight: .regular, relativeTo: .caption), color: LGColor.inkMuted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .lgScreen()
        .safeAreaInset(edge: .top, spacing: 0) { bar }
        .lgHidesNavigationBar()
        .task(id: photoCount) { stats = await PhotoLibrary.loadStats(container: store.container) }
        .confirmationDialog(title(for: asking), isPresented: Binding(get: { asking != nil }, set: { if !$0 { asking = nil } }),
                            titleVisibility: .visible, presenting: asking) { group in
            Button("Delete \(group.count) photos from \(String(group.year))", role: .destructive) { delete(group) }
            Button("Cancel", role: .cancel) {}
        } message: { group in
            Text("This frees \(ByteText.size(group.bytes)). Your \(String(group.year)) sessions, hours and notes stay. The photos are removed from this iPhone and from iCloud, and can’t be brought back.")
        }
    }

    private func title(for group: PhotoYearGroup?) -> String {
        guard let group else { return "" }
        return String(localized: "Delete all \(group.count) photos from \(String(group.year))?")
    }

    // MARK: Pieces

    private var bar: some View {
        HStack {
            LGIconButton(systemName: "chevron.left", label: "Back to Settings") { dismiss() }
                .padding(.leading, -10)
            Spacer()
            Text("Your photos").lgText(.navTitle).accessibilityAddTraits(.isHeader)
            Spacer()
            Color.clear.frame(width: 34, height: 44)
        }
        .frame(height: 44)
        .padding(.horizontal, 20).padding(.top, 8)
        .background(LGColor.background)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(ByteText.size(PhotoStorage.totalBytes(stats ?? [])))
                .lgNumber(LGTextStyle(size: 28, weight: .bold, relativeTo: .title, tracking: -0.56))
            Text("\(stats?.count ?? 0) photos you added to your sessions. The default pictures drawn by the app aren’t here; they take no space.")
                .lgText(LGTextStyle(size: 14, weight: .regular, relativeTo: .subheadline), color: LGColor.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
    }

    private func yearCard(_ group: PhotoYearGroup) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(String(group.year)).lgText(LGTextStyle(size: 17, weight: .bold, relativeTo: .headline))
                Spacer()
                Text("\(group.count) photos · \(ByteText.size(group.bytes))")
                    .lgText(.note, color: LGColor.inkMuted)
            }
            HStack(spacing: 5) {
                ForEach(Array(group.newest.enumerated()), id: \.element) { index, id in
                    tile(id, more: index == PhotoStorage.thumbnails - 1 ? PhotoStorage.moreCount(group) : nil)
                }
                // Keeps the tiles the same size when a year has fewer than five photos.
                ForEach(0..<max(0, PhotoStorage.thumbnails - group.newest.count), id: \.self) { _ in Color.clear.aspectRatio(1, contentMode: .fit) }
            }
            Button { asking = group } label: {
                Text("Delete all photos from \(String(group.year))…")
                    .lgText(LGTextStyle(size: 14, weight: .semibold, relativeTo: .subheadline), color: LGColor.deleteInk)
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .background(LGColor.deleteWash, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityHint("Asks first. Your sessions, hours and notes stay.")
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lgCard()
    }

    private func tile(_ id: UUID, more: Int?) -> some View {
        GeometryReader { geo in
            Group {
                if let data = sessions.first(where: { $0.id == id })?.photo {
                    PhotoThumb(id: id, data: data, side: geo.size.width, radius: 8)
                } else {
                    RoundedRectangle(cornerRadius: 8, style: .continuous).fill(LGColor.chipFill)
                }
            }
            .overlay {
                if let more {
                    RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color(hex: 0x16244A, opacity: 0.55))
                        .overlay { Text("+\(more)").lgText(LGTextStyle(size: 13, weight: .semibold, relativeTo: .footnote), color: .white) }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    // MARK: Deleting

    private func delete(_ group: PhotoYearGroup) {
        PhotoLibrary.removePhotos(inYear: group.year, from: sessions)
        if let settings = settingsRows.first {
            settings.yearCardPinsRaw = YearCardPins.removing(year: group.year, from: settings.yearCardPinsRaw)
        }
        try? context.save()
        asking = nil
        AccessibilityNotification.Announcement(String(localized: "Photos from \(String(group.year)) deleted")).post()
    }
}
