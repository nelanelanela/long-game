import SwiftUI
import SwiftData

/// "Your year": a calm keepsake of the year, to keep or share. Three looks, a Show hours switch and Share.
struct YearScreen: View {
    let craft: Craft
    let sessions: [Session]
    let estimates: [YearEstimate]
    let weekStart: WeekStart

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var settingsRows: [AppSettings]
    @Environment(\.lgEmbedded) private var embedded
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var year: Int
    @State private var style: YearCardStyle = .sunrise
    @State private var showHours = true
    /// The six photos on the Photos card, newest first unless swapped.
    @State private var chosen: [UUID] = []
    @State private var images: [UUID: PlatformImage] = [:]
    @State private var swapping: Int?
    @State private var shareURL: URL?

    init(craft: Craft, sessions: [Session], estimates: [YearEstimate], weekStart: WeekStart, year: Int? = nil) {
        self.craft = craft
        self.sessions = sessions
        self.estimates = estimates
        self.weekStart = weekStart
        _year = State(initialValue: year ?? YearSummary.defaultYear(now: Date()))
    }

    private var now: Date { Date() }

    private var years: [Int] {
        let found = YearSummary.yearsWithData(sessions: sessions.map(\.record))
        return found.contains(year) ? found : ([year] + found).sorted(by: >)
    }

    private var summary: YearSummary {
        YearSummary.make(year: year, sessions: sessions.map(\.record),
                         photos: sessions.filter(\.hasPhoto).map { YearPhoto(id: $0.id, start: $0.start) },
                         estimates: estimates.map(\.rate), onboardingDate: craft.createdAt, now: now, weekStart: weekStart)
    }

    private var looks: [YearCardStyle] { summary.offersPhotosCard ? YearCardStyle.allCases : [.sunrise, .evening] }

    /// Everything that changes the picture; the shared image is made again when it changes.
    private struct RenderKey: Hashable {
        var year: Int
        var style: YearCardStyle
        var showHours: Bool
        var chosen: [UUID]
        var loaded: Int
    }

    var body: some View {
        let s = summary
        let shown = looks.contains(style) ? style : .sunrise
        VStack(spacing: 14) {
            header
            if looks.count > 1 {
                LGSegmentedControl(items: looks, selection: shown, label: "Look of the card", title: { $0.title }, onSelect: { style = $0 })
            }
            preview(s, style: shown)
            hoursRow
            shareButton
        }
        .padding(.horizontal, 24).padding(.bottom, 12)
        .lgScreen()
        .lgHidesNavigationBar()
        .sheet(item: Binding(get: { swapping.map { Swap(index: $0) } }, set: { swapping = $0?.index })) { swap in
            PhotoSwapSheet(sessions: sessions.filter { $0.hasPhoto && Calendar.current.component(.year, from: $0.start) == year }
                                .sorted { $0.start > $1.start },
                           current: chosen) { id in
                if chosen.indices.contains(swap.index) {
                    chosen[swap.index] = id
                    pinChosen()
                }
                swapping = nil
            }
            .lgSheetCard()
        }
        .task(id: year) { resetPhotos() }
        .task(id: chosen) { await loadImages() }
        .task(id: RenderKey(year: year, style: shown, showHours: showHours, chosen: chosen, loaded: images.count)) {
            await renderShareImage(summary: s, style: shown)
        }
    }

    private struct Swap: Identifiable { var index: Int; var id: Int { index } }

    // MARK: Pieces

    private var header: some View {
        HStack {
            if embedded {
                Color.clear.frame(width: 34, height: 44)
            } else {
                LGIconButton(systemName: "chevron.left", label: "Back") { dismiss() }
                    .padding(.leading, -10)
            }
            Spacer()
            title
            Spacer()
            Color.clear.frame(width: 34, height: 44)
        }
        .frame(height: 44)
    }

    @ViewBuilder private var title: some View {
        if years.count > 1 {
            Menu {
                ForEach(years, id: \.self) { y in
                    Button { year = y } label: {
                        if y == year { Label(String(y), systemImage: "checkmark") } else { Text(String(y)) }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text("Your \(String(year))").lgText(.navTitle).accessibilityAddTraits(.isHeader)
                    Image(systemName: "chevron.down").lgIcon(11, weight: .semibold).foregroundStyle(LGColor.inkMuted)
                }
                .frame(minHeight: 44)
            }
            .accessibilityHint("Choose another year")
            .accessibilityAddTraits(.isHeader)
        } else {
            Text("Your \(String(year))").lgText(.navTitle).accessibilityAddTraits(.isHeader)
        }
    }

    /// The card, scaled to fit the room that is left.
    private func preview(_ s: YearSummary, style: YearCardStyle) -> some View {
        GeometryReader { geo in
            let size = style.size
            let scale = min(geo.size.width / size.width, geo.size.height / size.height, 1.2)
            YearCardView(summary: s, craftName: craft.name, style: style, showHours: showHours, now: now, weekStart: weekStart,
                         photos: chosen.compactMap { images[$0] }, onSwapTile: { swapping = $0 })
                .scaleEffect(scale, anchor: .center)
                .frame(width: size.width * scale, height: size.height * scale)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: LGColor.ink.opacity(0.12), radius: 12, y: 4)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: style)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(YearCardText.spoken(s, showHours: showHours))
        .accessibilityAddTraits(.isImage)
        .accessibilityHint(style == .photos ? "Long-press a photo to swap it" : "")
    }

    private var hoursRow: some View {
        Toggle(isOn: $showHours) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Show hours").lgText(.rowStrong)
                Text("Off shows days and percent instead").lgText(.caption, color: LGColor.inkMuted)
            }
        }
        .tint(LGColor.ink)
        .padding(.horizontal, 16).padding(.vertical, 6)
        .lgCard()
    }

    @ViewBuilder private var shareButton: some View {
        if let shareURL {
            ShareLink(item: shareURL, preview: SharePreview(String(localized: "Your \(String(year)) in the long game"),
                                                            image: Image(platformImage: PlatformImage.make(contentsOf: shareURL) ?? PlatformImage.photoPlaceholder))) {
                Text("Share").frame(maxWidth: .infinity)
            }
            .buttonStyle(.lg(.primary))
        } else {
            Button {} label: { Text("Share").frame(maxWidth: .infinity) }
                .buttonStyle(.lg(.primary))
                .disabled(true)
        }
    }

    // MARK: Photos and sharing

    /// The year's six: the photos pinned by swapping stay; the rest are the most viewed (newer first on ties).
    private func resetPhotos() {
        let candidates = sessions.filter { $0.hasPhoto && Calendar.current.component(.year, from: $0.start) == year }
            .map { YearPhotoCandidate(id: $0.id, start: $0.start, viewCount: $0.viewCount) }
        let pins = YearCardPins.decode(settingsRows.first?.yearCardPinsRaw ?? "")[year] ?? []
        chosen = YearPhotoChoice.choose(candidates: candidates, pinned: pins, year: year)
        if style == .photos && !summary.offersPhotosCard { style = .sunrise }
    }

    /// A photo swapped in stays on this year's card.
    private func pinChosen() {
        guard let settings = settingsRows.first else { return }
        var pins = YearCardPins.decode(settings.yearCardPinsRaw)
        pins[year] = chosen
        settings.yearCardPinsRaw = YearCardPins.encode(pins)
        try? context.save()
    }

    private func loadImages() async {
        for id in chosen where images[id] == nil {
            guard let data = sessions.first(where: { $0.id == id })?.photo else { continue }
            let cg = await Task.detached(priority: .utility) { PhotoProcessing.thumbnail(data, maxPixel: 420) }.value
            if let cg { images[id] = PlatformImage.make(cgImage: cg) }
        }
    }

    /// Makes the PNG: 1080 × 1920 for the stories, 1080 × 1080 for the square (the 360 pt layout × 3).
    private func renderShareImage(summary s: YearSummary, style: YearCardStyle) async {
        try? await Task.sleep(for: .milliseconds(250))   // let quick changes settle
        guard !Task.isCancelled else { return }
        shareURL = YearCardRender.png(summary: s, craftName: craft.name, style: style, showHours: showHours, now: now,
                                      weekStart: weekStart, photos: chosen.compactMap { images[$0] })
    }
}

/// Renders a card to a PNG file with ImageRenderer.
@MainActor
enum YearCardRender {
    /// The 360 pt layout times three.
    static let scale: CGFloat = 3

    static func image(summary: YearSummary, craftName: String, style: YearCardStyle, showHours: Bool, now: Date,
                      weekStart: WeekStart, photos: [PlatformImage]) -> PlatformImage? {
        let card = YearCardView(summary: summary, craftName: craftName, style: style, showHours: showHours, now: now,
                                weekStart: weekStart, photos: photos)
        let renderer = ImageRenderer(content: card)
        renderer.scale = scale
        renderer.isOpaque = true
        #if canImport(UIKit)
        return renderer.uiImage
        #else
        return renderer.nsImage
        #endif
    }

    static func png(summary: YearSummary, craftName: String, style: YearCardStyle, showHours: Bool, now: Date,
                    weekStart: WeekStart, photos: [PlatformImage]) -> URL? {
        guard let image = image(summary: summary, craftName: craftName, style: style, showHours: showHours, now: now,
                                weekStart: weekStart, photos: photos),
              let data = image.pngData() else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Long-Game-\(summary.year)-\(style.rawValue).png")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}

/// Choosing another of the year's photos for one tile of the Photos card.
private struct PhotoSwapSheet: View {
    let sessions: [Session]
    let current: [UUID]
    let onPick: (UUID) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Button("Cancel") { dismiss() }.buttonStyle(.lg(.text))
                Spacer()
                Text("Choose a photo").lgText(.navTitle).accessibilityAddTraits(.isHeader)
                Spacer()
                Color.clear.frame(width: 60, height: 1)
            }
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(sessions, id: \.persistentModelID) { s in
                        if let data = s.photo {
                            Button { onPick(s.id) } label: {
                                PhotoThumb(id: s.id, data: data, side: 100, radius: 10)
                                    .frame(maxWidth: .infinity)
                                    .overlay {
                                        if current.contains(s.id) {
                                            RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(LGColor.ink, lineWidth: 2)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(SessionPhotos.spokenLabel(start: s.start))
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 24).padding(.top, 20)
        .background(LGColor.background)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

/// The quiet row that opens the year card: History → Growth (all year) and The long game tab (1 Dec – 15 Jan).
struct YearEntryRow: View {
    let year: Int
    var sunSize: CGFloat = 40

    var body: some View {
        HStack(spacing: 12) {
            SunView(idle: false, face: .happy).frame(width: sunSize, height: sunSize).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Your \(String(year))").lgText(.rowStrong)
                Text("A card of your year, to keep or share").lgText(.caption, color: LGColor.inkMuted)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right").lgIcon(13, weight: .semibold)
                .foregroundStyle(LGColor.inkMuted).accessibilityHidden(true)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
    }
}
