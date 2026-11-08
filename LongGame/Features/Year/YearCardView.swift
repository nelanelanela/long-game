import SwiftUI

/// The three looks of the year card.
enum YearCardStyle: String, CaseIterable, Hashable {
    case sunrise, evening, photos

    var title: LocalizedStringKey {
        switch self {
        case .sunrise: "Sunrise"
        case .evening: "Evening"
        case .photos: "Photos"
        }
    }

    /// Stories are 9:16, the photo card is square.
    var size: CGSize { self == .photos ? CGSize(width: 360, height: 360) : CGSize(width: 360, height: 640) }
}

/// The year card, laid out at 360 pt wide with fixed text sizes (no Dynamic Type), so it always fits. It is shown
/// scaled on the "Your year" screen and rendered at 3x (1080 pt wide) for sharing. Always light or dark exactly as
/// its style says. Notes never appear on it, and nothing about other people.
struct YearCardView: View {
    let summary: YearSummary
    let craftName: String
    let style: YearCardStyle
    var showHours = true
    let now: Date
    var weekStart: WeekStart = .monday
    /// The six photos of the Photos card (already chosen), in order.
    var photos: [PlatformImage] = []
    /// In the preview only: long-pressing a photo tile asks to swap it.
    var onSwapTile: ((Int) -> Void)?

    private var evening: Bool { style == .evening }
    private var ink: Color { evening ? .white : LGColor.ink }
    private var muted: Color { evening ? .white.opacity(0.7) : LGColor.inkMuted }
    private var label: Color { evening ? LGColor.mote : LGColor.finishLabel }

    var body: some View {
        Group {
            if style == .photos { photosCard } else { storyCard }
        }
        .frame(width: style.size.width, height: style.size.height)
        .environment(\.colorScheme, .light)
    }

    // MARK: Story (Sunrise and Evening), 9:16

    private var storyCard: some View {
        ZStack(alignment: .top) {
            background
            VStack(spacing: 0) {
                Text("My \(String(summary.year)) in the long game")
                    .textCase(.uppercase)
                    .font(.system(size: 12, weight: .semibold)).tracking(1.68)
                    .foregroundStyle(label)
                    .padding(.top, 34)
                Text(craftName)
                    .font(.system(size: 30, weight: .bold)).tracking(-0.6)
                    .foregroundStyle(ink)
                    .lineLimit(1).minimumScaleFactor(0.5)
                    .padding(.horizontal, 24)
                    .padding(.top, 6)
                SunriseCanvas(layout: .yearCard(sea: evening ? .evening : .day, glowStrength: evening ? 0.35 : 0.3),
                              frame: .still)
                    .frame(width: 360, height: 222)
                    .padding(.top, 8)
                bottom
            }
        }
    }

    private var background: some View {
        Group {
            if evening {
                LinearGradient(stops: [.init(color: Color(hex: 0x16244A), location: 0), .init(color: Color(hex: 0x24306A), location: 0.55),
                                       .init(color: Color(hex: 0x3A2F6B), location: 1)], startPoint: .top, endPoint: .bottom)
            } else {
                LinearGradient(stops: [.init(color: Color(hex: 0xFFF6E6), location: 0), .init(color: Color(hex: 0xFFE9C7), location: 0.62),
                                       .init(color: LGColor.background, location: 0.62), .init(color: LGColor.background, location: 1)],
                               startPoint: .top, endPoint: .bottom)
            }
        }
    }

    private var bottom: some View {
        VStack(spacing: 0) {
            Text(YearCardText.big(summary, showHours: showHours))
                .font(.system(size: 54, weight: .bold)).tracking(-2.2)
                .foregroundStyle(evening ? LGColor.mote : ink)
                .lineLimit(1).minimumScaleFactor(0.5)
            Text(YearCardText.caption(summary, showHours: showHours))
                .font(.system(size: 14))
                .foregroundStyle(muted)
                .padding(.top, 6)
            YearStrip(summary: summary, now: now, weekStart: weekStart, evening: evening)
                .frame(width: 300, height: 40)
                .padding(.top, 22)
            HStack {
                ForEach(Array(YearCardText.monthLabels().enumerated()), id: \.offset) { i, name in
                    if i > 0 { Spacer(minLength: 0) }
                    Text(name)
                }
            }
            .font(.system(size: 9)).foregroundStyle(muted)
            .frame(width: 300)
            .padding(.top, 4)
            HStack(alignment: .top, spacing: 0) {
                stat(summary.rhythm > 0 ? Labels.daysPerWeek(summary.rhythm) : "–", String(localized: "Rhythm"))
                stat(summary.mostPlayedMonth.map { YearCardText.monthName($0) } ?? "–", String(localized: "Most played"))
                stat(YearCardText.totalValue(summary, showHours: showHours), YearCardText.totalCaption(showHours: showHours))
            }
            .frame(width: 300)
            .padding(.top, 20)
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                SunView(idle: false, face: .happy).frame(width: 14, height: 14)
                Text("Long Game · the longest game, played in real life")
            }
            .font(.system(size: 11)).foregroundStyle(muted)
            .padding(.bottom, 20)
        }
        .padding(.top, 6).padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(evening ? Color(hex: 0x2B3A73) : LGColor.background)
    }

    private func stat(_ value: String, _ caption: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 15, weight: .bold)).foregroundStyle(ink).lineLimit(1).minimumScaleFactor(0.6)
            Text(caption).font(.system(size: 10)).foregroundStyle(muted).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Photos, square

    private var photosCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    Text("My \(String(summary.year)) · \(craftName)")
                        .textCase(.uppercase)
                        .font(.system(size: 10, weight: .semibold)).tracking(1.4)
                        .foregroundStyle(label)
                        .lineLimit(1)
                    Text(YearCardText.big(summary, showHours: showHours))
                        .font(.system(size: 30, weight: .bold)).tracking(-0.9)
                        .foregroundStyle(ink)
                        .lineLimit(1).minimumScaleFactor(0.5)
                }
                Spacer(minLength: 8)
                SunView(idle: false, face: .happy).frame(width: 58, height: 58)
            }
            let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 3)
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(0..<6, id: \.self) { i in tile(i) }
            }
            HStack {
                Text(YearCardText.photoFooter(summary, showHours: showHours)).lineLimit(1).minimumScaleFactor(0.7)
                Spacer(minLength: 8)
                Text("Long Game")
            }
            .font(.system(size: 11)).foregroundStyle(muted)
        }
        .padding(22)
        .background(LGColor.background)
    }

    private func tile(_ index: Int) -> some View {
        let side = (360 - 44 - 12) / 3.0
        return Group {
            if photos.indices.contains(index) {
                Image(platformImage: photos[index]).resizable().scaledToFill().accessibilityIgnoresInvertColors()
            } else {
                LGColor.chipFill
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .contentShape(Rectangle())
        .onLongPressGesture { onSwapTile?(index) }
    }
}

/// The year as a strip of weeks: a column per week, a row per day, in the calendar colours. Days still to come and
/// days outside the year are left out.
struct YearStrip: View {
    let summary: YearSummary
    let now: Date
    var weekStart: WeekStart = .monday
    var evening = false

    var body: some View {
        let grid = YearSummary.grid(year: summary.year, levels: summary.levels, now: now, weekStart: weekStart)
        let rest = evening ? Color(hex: 0x6677B5) : LGColor.rest
        Canvas { context, size in
            guard !grid.isEmpty else { return }
            let pitch = min(size.width / CGFloat(grid.count), size.height / 7)
            let cell = pitch * 0.86
            let left = (size.width - pitch * CGFloat(grid.count)) / 2
            for (c, column) in grid.enumerated() {
                for (r, level) in column.enumerated() {
                    guard let level else { continue }
                    let rect = CGRect(x: left + CGFloat(c) * pitch, y: CGFloat(r) * pitch, width: cell, height: cell)
                    context.fill(CalendarLevelShape(level: level).path(in: rect), with: .color(level == .rest ? rest : LGColor.calendar(level)))
                }
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: Previews

extension YearSummary {
    /// A year of sample practice, for previews and the debug option.
    static func sample(year: Int = 2026) -> YearSummary {
        var levels: [Date: CalendarLevel] = [:]
        let cal = Calendar(identifier: .gregorian)
        var day = cal.date(from: DateComponents(year: year, month: 1, day: 1))!
        var n = 0
        while cal.component(.year, from: day) == year {
            if (n * 7919) % 10 < 6 { levels[day] = CalendarLevel.allCases[1 + (n * 31) % 4] }
            day = cal.date(byAdding: .day, value: 1, to: day)!
            n += 1
        }
        return YearSummary(year: year, hours: 624, daysOfPractice: levels.count, rhythm: 5, mostPlayedMonth: 3, total: 3_294,
                           percent: 32, levels: levels, since: nil, photos: [], daysCovered: 365)
    }
}

#Preview("Cards · hours shown") {
    ScrollView(.horizontal) {
        HStack(spacing: 16) {
            ForEach(YearCardStyle.allCases, id: \.self) { style in
                YearCardView(summary: .sample(), craftName: "Piano", style: style,
                             now: Calendar.current.date(from: DateComponents(year: 2026, month: 12, day: 20))!,
                             photos: (0..<6).map { _ in PlatformImage.photoPlaceholder })
            }
        }
        .padding()
    }
}

#Preview("Cards · hours hidden") {
    ScrollView(.horizontal) {
        HStack(spacing: 16) {
            ForEach(YearCardStyle.allCases, id: \.self) { style in
                YearCardView(summary: .sample(), craftName: "Piano", style: style, showHours: false,
                             now: Calendar.current.date(from: DateComponents(year: 2026, month: 12, day: 20))!)
            }
        }
        .padding()
    }
}
