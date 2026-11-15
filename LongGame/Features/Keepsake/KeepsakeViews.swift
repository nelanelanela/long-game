import SwiftUI
import SwiftData

// A keepsake poster (update 49, `design/redesign/Keepsake.dc.html`).

/// The poster at any page size. Everything is measured from the page width, so A4 and 50 × 70 look the same.
/// Drawn as shapes and text (vector in the PDF), never as a picture.
struct KeepsakePoster: View {
    struct Content {
        var hours: Int
        var craft: String
        var days: [CalendarLevel]
        var firstDay: Date
        var lastDay: Date
        /// Hours added for the time before the app.
        var baseline: Double
    }

    let content: Content
    let look: Keepsake.Look
    let size: CGSize

    private var night: Bool { look == .night }
    private var paper: Color { night ? Color(hex: 0x0B1029) : Color(hex: 0xFFFDF8) }
    private var ink: Color { night ? Color(hex: 0xF5EBDD) : Color(hex: 0x16244A) }
    private var muted: Color { night ? Color(hex: 0xF5EBDD, opacity: 0.7) : Color(hex: 0x5E6782) }
    private var ember: Color { night ? Color(hex: 0xFFD66B) : Color(hex: 0xB4561A) }

    var body: some View {
        let u = size.width / 100      // one unit: 1% of the page width
        let margin = Keepsake.margin * size.width / Keepsake.Paper.a4.size.width
        VStack(spacing: 0) {
            Text("LONG GAME")
                .font(.system(size: 1.5 * u, weight: .semibold)).tracking(0.5 * u)
                .foregroundStyle(muted)
            Text(verbatim: String(localized: "\(DurationFormat.grouped(content.hours)) hours"))
                .font(.system(size: 8 * u, weight: .bold)).tracking(-0.25 * u)
                .foregroundStyle(ink)
                .padding(.top, 1.6 * u)
            Text(verbatim: String(localized: "of \(content.craft.lowercased())"))
                .font(.system(size: 3 * u, weight: .semibold))
                .foregroundStyle(ember)
                .padding(.top, 0.4 * u)
            GeometryReader { geo in
                field(in: geo.size)
            }
            .padding(.top, 4 * u).padding(.bottom, 3 * u)
            footer(u: u)
        }
        .padding(margin)
        .frame(width: size.width, height: size.height)
        .background(paper)
        .environment(\.colorScheme, .light)
    }

    /// One mark per day, 28 to a row, centred; the cell shrinks for long histories so nothing is cut.
    private func field(in box: CGSize) -> some View {
        let cell = Keepsake.cell(dayCount: content.days.count, in: box)
        let rows = (content.days.count + Keepsake.perRow - 1) / Keepsake.perRow
        let mark = cell * 0.74
        let width = cell * CGFloat(Keepsake.perRow), height = cell * CGFloat(rows)
        return Canvas { context, _ in
            for (i, level) in content.days.enumerated() {
                let r = i / Keepsake.perRow, c = i % Keepsake.perRow
                let rect = CGRect(x: CGFloat(c) * cell + (cell - mark) / 2, y: CGFloat(r) * cell + (cell - mark) / 2,
                                  width: mark, height: mark)
                context.fill(CalendarLevelShape(level: level).path(in: rect), with: .color(colour(level)))
            }
        }
        .frame(width: width, height: height)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func colour(_ level: CalendarLevel) -> Color {
        guard night else { return LGColor.calendar(level) }   // the light colours: the poster is drawn in the light scheme
        // Gold on navy: four gold tints, the rest dot faint.
        switch level {
        case .rest: return Color(hex: 0xFFD66B, opacity: 0.18)
        case .under1: return Color(hex: 0xFFE7A3)
        case .from1to2: return Color(hex: 0xFFD66B)
        case .from2to3: return Color(hex: 0xF5B33F)
        case .over3: return Color(hex: 0xF0922A)
        }
    }

    private func footer(u: CGFloat) -> some View {
        HStack(alignment: .bottom, spacing: 2 * u) {
            VStack(alignment: .leading, spacing: 0.4 * u) {
                Text(verbatim: "\(ThenAndNow.date(content.firstDay)) – \(ThenAndNow.date(content.lastDay))")
                Text(verbatim: Keepsake.playedLine(Keepsake.daysPlayed(content.days)))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 0.6 * u) {
                Text("less")
                ForEach(CalendarLevel.allCases, id: \.self) { level in
                    CalendarLevelShape(level: level).fill(colour(level)).frame(width: 1.4 * u, height: 1.4 * u)
                }
                Text("more")
            }
            VStack(alignment: .trailing, spacing: 0.4 * u) {
                if let before = Keepsake.before(content.baseline) { Text(verbatim: before) }
                Text("by We Have Sun")
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(.system(size: 1.3 * u))
        .foregroundStyle(muted)
    }
}

/// The poster as a one-page vector PDF at the paper size, made on the device.
@MainActor
enum KeepsakePDF {
    static func make(_ content: KeepsakePoster.Content, paper: Keepsake.Paper, look: Keepsake.Look) -> URL? {
        let size = paper.size
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(Keepsake.fileName(hours: content.hours, craft: content.craft))
        let renderer = ImageRenderer(content: KeepsakePoster(content: content, look: look, size: size))
        renderer.proposedSize = ProposedViewSize(size)
        var made = false
        renderer.render { _, draw in
            var box = CGRect(origin: .zero, size: size)
            let info: [CFString: Any] = [
                kCGPDFContextTitle: String(localized: "\(DurationFormat.grouped(content.hours)) hours of \(content.craft.lowercased())"),
                kCGPDFContextSubject: String(localized: "A keepsake poster from Long Game: every day as a small sun."),
                kCGPDFContextCreator: "Long Game",
            ]
            guard let pdf = CGContext(url as CFURL, mediaBox: &box, info as CFDictionary) else { return }
            pdf.beginPDFPage(nil)
            draw(pdf)
            pdf.endPDFPage()
            pdf.closePDF()
            made = true
        }
        return made ? url : nil
    }
}

/// The sheet: a small preview, paper and look, Save the poster (share sheet) and Not now.
struct KeepsakeSheet: View {
    let content: KeepsakePoster.Content

    @Environment(\.dismiss) private var dismiss
    @State private var paper = Keepsake.defaultPaper()
    @State private var look: Keepsake.Look = .paper
    @State private var fileURL: URL?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    KeepsakePoster(content: content, look: look, size: CGSize(width: 1000, height: 1000 * paper.size.height / paper.size.width))
                        // A picture: its words are read once, in the label below, not one by one.
                        .accessibilityHidden(true)
                        .scaleEffect(150 / 1000, anchor: .topLeading)
                        .frame(width: 150, height: 150 * paper.size.height / paper.size.width, alignment: .topLeading)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .shadow(color: LGColor.navy.opacity(0.18), radius: 12, y: 8)
                        .rotationEffect(.degrees(-1.5))
                        .padding(.top, 24)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text(verbatim: Keepsake.spoken(hours: content.hours, craft: content.craft,
                                                                           played: Keepsake.daysPlayed(content.days))))
                        .accessibilityAddTraits(.isImage)
                    Text("A keepsake for your wall")
                        .lgText(.sheetTitle)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.top, 22)
                    Text("Every day of your \(DurationFormat.grouped(content.hours)) hours as a small sun. Print it at home or at any print shop.")
                        .lgText(.note, color: LGColor.inkMuted)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 6)
                    choice("Paper") {
                        LGSegmentedControl(items: Keepsake.Paper.allCases, selection: paper, label: "Paper",
                                           title: { LocalizedStringKey($0.title) }, onSelect: { paper = $0 })
                    }
                    .padding(.top, 20)
                    choice("Look") {
                        LGSegmentedControl(items: Keepsake.Look.allCases, selection: look, label: "Look",
                                           title: { $0 == .paper ? "Paper" : "Night" }, onSelect: { look = $0 })
                    }
                    .padding(.top, 14)
                }
                .padding(.horizontal, 24).padding(.bottom, 16)
            }
            VStack(spacing: 2) {
                if let fileURL {
                    ShareLink(item: fileURL) { Text("Save the poster").frame(maxWidth: .infinity) }
                        .buttonStyle(.lg(.primary))
                } else {
                    Button {} label: { Text("Save the poster").frame(maxWidth: .infinity) }
                        .buttonStyle(.lg(.primary)).disabled(true)
                }
                Button("Not now") { dismiss() }.buttonStyle(.lg(.text))
            }
            .padding(.horizontal, 24).padding(.bottom, 10)
        }
        .background(LGColor.background.ignoresSafeArea())
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(30)
        .task(id: "\(paper.rawValue)-\(look.rawValue)") {
            fileURL = nil
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            fileURL = KeepsakePDF.make(content, paper: paper, look: look)
        }
    }

    private func choice<C: View>(_ title: LocalizedStringKey, @ViewBuilder _ control: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).lgText(.rowStrong, color: LGColor.inkMuted)
            control()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension KeepsakePoster.Content {
    /// The poster for `hours` from this craft's saved sessions; nil until the total has got there.
    @MainActor
    static func make(hours: Int, craft: Craft, sessions: [Session], estimates: [YearEstimate]) -> KeepsakePoster.Content? {
        let records = sessions.map(\.record)
        let baseline = Baseline.hours(estimates: estimates.map(\.rate), onboardingDate: craft.createdAt)
        guard let reached = Keepsake.dayReached(hours, sessions: records, baseline: baseline),
              let first = records.map(\.start).min() else { return nil }
        // Reached with the hours from before the app (nothing logged yet to show it): the field runs to today instead.
        let last = baseline >= Double(hours) ? Calendar.current.startOfDay(for: Date()) : reached
        let days = Keepsake.days(sessions: records.filter { $0.start < last.addingTimeInterval(86_400) }, through: last)
        return KeepsakePoster.Content(hours: hours, craft: craft.name, days: days, firstDay: Calendar.current.startOfDay(for: first),
                                      lastDay: last, baseline: baseline)
    }
}
