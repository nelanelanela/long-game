import SwiftUI
import SwiftData

/// The two ids of the pair the person chose, as one value (kept outside the model class, so SwiftData's macro only
/// sees the two stored ids).
extension AppSettings {
    var thenAndNowChoice: ThenAndNow.Choice? {
        get { thenAndNowThenId.flatMap { t in thenAndNowNowId.map { ThenAndNow.Choice(then: t, now: $0) } } }
        set { thenAndNowThenId = newValue?.then; thenAndNowNowId = newValue?.now }
    }
}

/// What Then and now needs from the saved sessions, worked out once.
struct ThenAndNowData {
    let pair: ThenAndNow.Pair
    let thenSession: Session
    let nowSession: Session
    let thenHours: Double
    let nowHours: Double

    /// Then and now for this craft, or nil when there is no pair (fewer than two photos, or under 90 days apart).
    @MainActor
    static func make(sessions: [Session], estimates: [YearEstimate], craft: Craft, settings: AppSettings?) -> ThenAndNowData? {
        let photos = sessions.filter(\.hasPhoto).map { ThenAndNow.Photo(sessionId: $0.id, start: $0.start) }
        let chosen = settings?.thenAndNowChoice
        guard let pair = ThenAndNow.pair(photos: photos, chosen: chosen),
              let then = sessions.first(where: { $0.id == pair.then.sessionId }),
              let now = sessions.first(where: { $0.id == pair.now.sessionId }) else { return nil }
        let baseline = Baseline.hours(estimates: estimates.map(\.rate), onboardingDate: craft.createdAt)
        let all = sessions.map { (id: $0.id, start: $0.start, hours: $0.durationSec / 3600) }
        return ThenAndNowData(pair: pair, thenSession: then, nowSession: now,
                              thenHours: ThenAndNow.total(atEndOf: then.id, sessions: all, baseline: baseline),
                              nowHours: ThenAndNow.total(atEndOf: now.id, sessions: all, baseline: baseline))
    }
}

/// Then and now (`design/redesign/ThenAndNow.dc.html`): the first photo next to the latest, tilted very slightly,
/// with the time and the hours between them. Share makes a 9:16 image; Choose other photos picks another pair.
struct ThenAndNowView: View {
    let craft: Craft

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.dynamicTypeSize) private var typeSize
    @Query private var sessions: [Session]
    @Query private var estimates: [YearEstimate]
    @Query private var settingsRows: [AppSettings]

    @State private var images: [UUID: PlatformImage] = [:]
    @State private var shareURL: URL?
    @State private var choosing = false
    @State private var viewing: Session?

    init(craft: Craft) {
        self.craft = craft
        let id = craft.id
        _sessions = Query(filter: #Predicate<Session> { $0.craftId == id }, sort: \Session.start)
        _estimates = Query(filter: #Predicate<YearEstimate> { $0.craftId == id })
    }

    private var data: ThenAndNowData? {
        ThenAndNowData.make(sessions: sessions, estimates: estimates, craft: craft, settings: settingsRows.first)
    }

    var body: some View {
        VStack(spacing: 0) {
            header.padding(.horizontal, 24)
            if let data {
                // At the accessibility sizes the page scrolls; otherwise it fits as on the board.
                ScrollView {
                    content(data).padding(.horizontal, 24).padding(.bottom, 16)
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollDisabled(!typeSize.isAccessibilitySize)
                VStack(spacing: 2) {
                    shareButton
                    Button("Choose other photos") { choosing = true }.buttonStyle(.lg(.text))
                }
                .padding(.horizontal, 24).padding(.bottom, 10)
                .task(id: shareKey(data)) { await prepare(data) }
            } else {
                Spacer()
            }
        }
        .background(alignment: .top) {
            LinearGradient(colors: [LGColor.peachWash, LGColor.background], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.34))
                .ignoresSafeArea()
        }
        .background(LGColor.background.ignoresSafeArea())
        .lgHidesNavigationBar()
        .sheet(isPresented: $choosing) {
            ThenAndNowPicker(sessions: sessions.filter(\.hasPhoto)) { then, now in
                guard let settings = settingsRows.first else { return }
                settings.thenAndNowChoice = ThenAndNow.Choice(then: then, now: now)
                try? context.save()
            }
            .lgSheetCard()
        }
        .fullScreenCover(item: $viewing) { session in
            PhotoViewer(sessions: sessions.filter(\.hasPhoto), startAt: session)
        }
    }

    private var header: some View {
        HStack {
            LGIconButton(systemName: "chevron.left", label: "Back") { dismiss() }
                .padding(.leading, -10)
            Spacer()
            Text("Then and now").lgText(.navTitle).accessibilityAddTraits(.isHeader)
            Spacer()
            Color.clear.frame(width: 34, height: 44)
        }
        .frame(height: 44)
    }

    private func content(_ d: ThenAndNowData) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                SunView(idle: false, face: .happy, eyesOpen: 1)
                    .frame(width: 44, height: 44)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Look how far.")
                        .lgText(LGTextStyle(size: 22, weight: .bold, relativeTo: .title2, tracking: -0.44))
                    Text(verbatim: ThenAndNow.between(hours: d.nowHours - d.thenHours, craft: craft.name))
                        .lgText(.note, color: LGColor.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                Spacer(minLength: 0)
            }
            .padding(.top, 6)

            card(session: d.thenSession, hours: d.thenHours, isThen: true)
                .rotationEffect(.degrees(-1.5))
                .padding(.top, 16)
            Text(verbatim: ThenAndNow.gap(from: d.pair.then.start, to: d.pair.now.start))
                .lgText(LGTextStyle(size: 12, weight: .bold, relativeTo: .caption), color: LGColor.timerGold)
                .padding(.horizontal, 12)
                .frame(minHeight: 28)
                .background(LGColor.storyPill, in: Capsule())
                .shadow(color: LGColor.navy.opacity(0.25), radius: 6, y: 4)
                .padding(.vertical, -8)
                .zIndex(1)
            card(session: d.nowSession, hours: d.nowHours, isThen: false)
                .rotationEffect(.degrees(1.2))
        }
    }

    /// A white card: the photo with its Then / Now pill, the date and the hours, and the note on one line.
    private func card(session: Session, hours: Double, isThen: Bool) -> some View {
        let date = ThenAndNow.date(session.start)
        return VStack(alignment: .leading, spacing: 10) {
            Button { viewing = session } label: {
                ThenAndNowPhoto(image: images[session.id], height: typeSize.isAccessibilitySize ? 220 : 178)
                    .overlay(alignment: .topLeading) {
                        Text(isThen ? "Then" : "Now")
                            .lgText(LGTextStyle(size: 12, weight: .semibold, relativeTo: .caption), color: .white)
                            .padding(.horizontal, 10)
                            .frame(minHeight: 24)
                            .background(LGColor.navy.opacity(0.72), in: Capsule())
                            .padding(10)
                    }
            }
            .buttonStyle(.plain)
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) {
                    Text(verbatim: date).lgText(LGTextStyle(size: 15, weight: .semibold, relativeTo: .subheadline))
                    Spacer(minLength: 8)
                    Text(verbatim: ThenAndNow.atHours(hours)).lgText(LGTextStyle(size: 13, weight: .regular, relativeTo: .footnote), color: LGColor.inkMuted)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: date).lgText(LGTextStyle(size: 15, weight: .semibold, relativeTo: .subheadline))
                    Text(verbatim: ThenAndNow.atHours(hours)).lgText(LGTextStyle(size: 13, weight: .regular, relativeTo: .footnote), color: LGColor.inkMuted)
                }
            }
            .padding(.horizontal, 4)
            if let note = session.note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
                Text(verbatim: note)
                    .lgText(LGTextStyle(size: 13, weight: .regular, relativeTo: .footnote), color: LGColor.inkMuted)
                    .lineLimit(1)
                    .padding(.horizontal, 4)
            }
        }
        .padding(.horizontal, 10).padding(.top, 10).padding(.bottom, 12)
        .background(LGColor.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: LGColor.navy.opacity(0.1), radius: 14, y: 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: ThenAndNow.spoken(isThen: isThen, date: date, hours: hours, note: session.note)))
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Opens the photo")
        .accessibilityAction { viewing = session }
    }

    @ViewBuilder private var shareButton: some View {
        if let shareURL {
            ShareLink(item: shareURL, preview: SharePreview(String(localized: "Then and now"),
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

    private func shareKey(_ d: ThenAndNowData) -> String { "\(d.pair.then.sessionId)-\(d.pair.now.sessionId)" }

    /// Loads both photos, then makes the shared image.
    private func prepare(_ d: ThenAndNowData) async {
        shareURL = nil
        for session in [d.thenSession, d.nowSession] where images[session.id] == nil {
            guard let data = session.photo else { continue }
            let cg = await Task.detached(priority: .userInitiated) { PhotoProcessing.thumbnail(data, maxPixel: 1200) }.value
            if let cg { images[session.id] = PlatformImage.make(cgImage: cg) }
        }
        guard let thenImage = images[d.thenSession.id], let nowImage = images[d.nowSession.id] else { return }
        let card = ThenAndNowCard(craftName: craft.name,
                                  then: .init(image: thenImage, date: ThenAndNow.date(d.thenSession.start), hours: d.thenHours),
                                  now: .init(image: nowImage, date: ThenAndNow.date(d.nowSession.start), hours: d.nowHours),
                                  gap: ThenAndNow.gap(from: d.pair.then.start, to: d.pair.now.start))
        shareURL = YearCardRender.png(card, name: "Long-Game-then-and-now")
    }
}

/// A photo filling its frame (aspect fill, radius 10), or a soft placeholder while it loads.
private struct ThenAndNowPhoto: View {
    let image: PlatformImage?
    let height: CGFloat

    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .overlay {
                if let image {
                    Image(platformImage: image).resizable().scaledToFill()
                } else {
                    LGColor.peachWash
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .accessibilityIgnoresInvertColors()
    }
}

/// The shared image: 360 × 640 pt, rendered at 3x (1080 × 1920) like the year card. No notes on it.
struct ThenAndNowCard: View {
    struct Side {
        let image: PlatformImage
        let date: String
        let hours: Double
    }

    let craftName: String
    let then: Side
    let now: Side
    let gap: String

    var body: some View {
        VStack(spacing: 0) {
            Text("Then and now · \(craftName)")
                .textCase(.uppercase)
                .font(.system(size: 11, weight: .semibold)).tracking(1.76)
                .foregroundStyle(LGColor.finishLabel)
                .lineLimit(1).minimumScaleFactor(0.6)
                .padding(.top, 30)
            side(then, label: String(localized: "Then")).rotationEffect(.degrees(-1.5)).padding(.top, 18)
            Text(verbatim: gap)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(LGColor.timerGold)
                .padding(.horizontal, 12)
                .frame(height: 28)
                .background(LGColor.navy, in: Capsule())
                .padding(.vertical, -8)
                .zIndex(1)
            side(now, label: String(localized: "Now")).rotationEffect(.degrees(1.2))
            Text(verbatim: ThenAndNow.betweenShort(hours: now.hours - then.hours))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(LGColor.ink)
                .padding(.top, 16)
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                SunView(idle: false, face: .happy).frame(width: 18, height: 18)
                Text("Long Game · the longest game, played in real life")
            }
            .font(.system(size: 11)).foregroundStyle(LGColor.inkMuted)
            .padding(.bottom, 18)
        }
        .padding(.horizontal, 28)
        .frame(width: 360, height: 640)
        .background {
            LinearGradient(colors: [Color(hex: 0xFFF1DA), Color(hex: 0xFAF7F1)], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.34))
        }
        .environment(\.colorScheme, .light)
    }

    private func side(_ s: Side, label: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Color.clear.frame(height: 196)
                .overlay { Image(platformImage: s.image).resizable().scaledToFill() }
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(alignment: .topLeading) {
                    Text(verbatim: label)
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 10).frame(height: 24)
                        .background(Color(hex: 0x16244A, opacity: 0.72), in: Capsule())
                        .padding(10)
                }
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: s.date).font(.system(size: 15, weight: .semibold)).foregroundStyle(LGColor.ink)
                Spacer(minLength: 8)
                Text(verbatim: ThenAndNow.atHours(s.hours)).font(.system(size: 13)).foregroundStyle(LGColor.inkMuted)
            }
            .padding(.horizontal, 4)
        }
        .padding(10)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color(hex: 0x16244A, opacity: 0.1), radius: 14, y: 10)
    }
}

/// Choose other photos: the person's session photos by year (newest last). Pick Then, then Now (later than Then).
struct ThenAndNowPicker: View {
    let sessions: [Session]
    let onPick: (UUID, UUID) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var then: Session?

    private var years: [(year: Int, sessions: [Session])] {
        let sorted = sessions.sorted { $0.start < $1.start }
        let grouped = Dictionary(grouping: sorted) { Calendar.current.component(.year, from: $0.start) }
        return grouped.keys.sorted().map { ($0, grouped[$0] ?? []) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button { if then != nil { then = nil } else { dismiss() } } label: {
                    Text(then == nil ? "Cancel" : "Back").lgText(LGTextStyle(size: 16, weight: .medium, relativeTo: .body))
                        .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Spacer()
            }
            Text(then == nil ? "Choose Then" : "Choose Now")
                .lgText(.sheetTitle)
                .accessibilityAddTraits(.isHeader)
            Text(then == nil ? "An early photo." : "A later photo than Then.")
                .lgText(.note, color: LGColor.inkMuted)
                .padding(.top, 2)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(years, id: \.year) { group in
                        Text(verbatim: String(group.year)).lgText(.rowStrong, color: LGColor.inkMuted)
                            .accessibilityAddTraits(.isHeader)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 8)], spacing: 8) {
                            ForEach(group.sessions) { session in tile(session) }
                        }
                    }
                }
                .padding(.vertical, 16)
            }
        }
        .padding(.horizontal, 24).padding(.top, 8)
        .background(LGColor.background)
        .presentationDragIndicator(.visible)
    }

    private func tile(_ session: Session) -> some View {
        let allowed = then.map { session.start > $0.start } ?? true
        return Button {
            if let first = then {
                onPick(first.id, session.id)
                dismiss()
            } else {
                then = session
            }
        } label: {
            if let data = session.photo {
                PhotoThumb(id: session.id, data: data, side: 76, radius: 10)
            }
        }
        .buttonStyle(.plain)
        .disabled(!allowed)
        .opacity(allowed ? 1 : 0.35)
        .overlay {
            if then?.id == session.id {
                RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(LGColor.ink, lineWidth: 3)
            }
        }
        .accessibilityLabel(Text(verbatim: ThenAndNow.date(session.start)))
        .accessibilityAddTraits(then?.id == session.id ? .isSelected : [])
    }
}
