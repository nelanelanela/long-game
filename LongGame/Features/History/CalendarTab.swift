import SwiftUI
import SwiftData

struct CalendarTab: View {
    let craft: Craft
    let sessions: [Session]
    let weekStart: WeekStart

    @State private var selected: Date
    @State private var editing: Session?
    @State private var explaining: StatInfo?
    /// The session whose photo is open full screen.
    @State private var viewing: Session?

    init(craft: Craft, sessions: [Session], weekStart: WeekStart, initialDay: Date? = nil) {
        self.craft = craft
        self.sessions = sessions
        self.weekStart = weekStart
        _selected = State(initialValue: Calendar.current.startOfDay(for: initialDay ?? Date()))
    }

    private let cell: CGFloat = 14
    private let gap: CGFloat = 3
    private var calendar: Calendar { .current }

    var body: some View {
        let now = Date()
        let weeks = CalendarGrid.weeks(endingOn: now, weekStart: weekStart, calendar: calendar)
        let daily = Practice.dailySeconds(sessions.map(\.record), calendar: calendar)
        let windowStart = weeks.first?.first ?? now

        VStack(spacing: 18) {
            gridCard(weeks: weeks, daily: daily, windowStart: windowStart, now: now)
            dayCard(daily: daily, now: now)
            statsCard(daily: daily, windowStart: windowStart, now: now)
        }
        .sheet(item: $editing) { session in
            SessionFormView(craft: craft, sessions: sessions, editing: session)
                .lgSheetCard()
        }
        .sheet(item: $explaining) { info in
            StatExplainer(info: info)
                .lgSheetCard()
        }
        .fullScreenCover(item: $viewing) { session in
            PhotoViewer(sessions: photoSessions, startAt: session)
        }
    }

    /// Every session with a photo, oldest first (the newest is last in the viewer).
    private var photoSessions: [Session] {
        sessions.filter(\.hasPhoto).sorted { $0.start < $1.start }
    }

    // MARK: Grid

    private func gridCard(weeks: [[Date]], daily: [Date: Double], windowStart: Date, now: Date) -> some View {
        let windowHours = sessions
            .filter { $0.start >= windowStart && $0.start <= now.addingTimeInterval(86_400) }
            .reduce(0.0) { $0 + $1.durationSec } / 3600
        let today = calendar.startOfDay(for: now)
        let photoDays = SessionPhotos.daysWithPhoto(sessions.map { ($0.start, $0.hasPhoto) }, calendar: calendar)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Last 12 months").lgText(.rowStrong)
                Spacer()
                Text(Labels.shortHours(Int(windowHours.rounded()))).lgText(.row, color: LGColor.inkMuted)
            }

            HStack(alignment: .top, spacing: 6) {
                weekdayLabels(weeks: weeks)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: gap) {
                        let labels = monthLabels(weeks: weeks)
                        ForEach(Array(weeks.enumerated()), id: \.offset) { index, week in
                            VStack(spacing: gap) {
                                Text(labels[index] ?? "")
                                    .lgText(LGTextStyle(size: 10, weight: .regular, relativeTo: .caption2), color: LGColor.inkMuted)
                                    .fixedSize()
                                    .frame(width: cell, height: cell, alignment: .leading)
                                    .accessibilityHidden(true)
                                ForEach(week, id: \.self) { day in
                                    dayCell(day, daily: daily, today: today, hasPhoto: photoDays.contains(day))
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 4).padding(.vertical, 4)
                }
                .defaultScrollAnchor(.trailing)
            }

            HStack {
                legendSwatch(LGColor.rest, "Rest")
                Spacer()
                HStack(spacing: 4) {
                    Text("Less").lgText(.tiny, color: LGColor.inkMuted).padding(.trailing, 4)
                    ForEach(0..<4, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 3).fill(LGColor.practice[i]).frame(width: 12, height: 12)
                    }
                    Text("More").lgText(.tiny, color: LGColor.inkMuted).padding(.leading, 4)
                }
            }
            .accessibilityHidden(true)

            // Only once there is a photo: what the white dot means.
            if !photoDays.isEmpty {
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 3).fill(LGColor.practice[1]).frame(width: 12, height: 12)
                        .overlay { Circle().fill(.white).frame(width: 4, height: 4) }
                    Text("White dot: a day with a photo").lgText(.tiny, color: LGColor.inkMuted)
                }
                .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 18)
        .lgCard()
    }

    private func dayCell(_ day: Date, daily: [Date: Double], today: Date, hasPhoto: Bool) -> some View {
        let isFuture = day > today
        let seconds = daily[day] ?? 0
        let level = CalendarLevel.level(hours: seconds / 3600)
        let isSelected = day == selected
        return RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(isFuture ? Color.clear : LGColor.calendar(level))
            .frame(width: cell, height: cell)
            .overlay {
                // A tiny white dot in the middle: this day has a photo.
                if hasPhoto && !isFuture { Circle().fill(.white).frame(width: 4, height: 4) }
            }
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 5.5)
                        .stroke(LGColor.ink, lineWidth: 1.5)
                        .padding(-3)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { if !isFuture { selected = day } }
            .accessibilityElement()
            .accessibilityLabel(Self.spoken(day, seconds: seconds, calendar: calendar) + (hasPhoto ? String(localized: ", with a photo") : ""))
            .accessibilityAddTraits(isFuture ? [] : .isButton)
            .accessibilityHidden(isFuture)
    }

    private func weekdayLabels(weeks: [[Date]]) -> some View {
        VStack(alignment: .leading, spacing: gap) {
            Color.clear.frame(width: 1, height: cell)
            ForEach(Array((weeks.first ?? []).enumerated()), id: \.offset) { _, date in
                let weekday = calendar.component(.weekday, from: date)
                Text([2, 4, 6].contains(weekday) ? Self.shortWeekday(date, calendar) : "")
                    .lgText(LGTextStyle(size: 10, weight: .regular, relativeTo: .caption2), color: LGColor.inkMuted)
                    .fixedSize()
                    .frame(height: cell, alignment: .leading)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityHidden(true)
    }

    private func legendSwatch(_ color: Color, _ title: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 12, height: 12)
            Text(title).lgText(.tiny, color: LGColor.inkMuted)
        }
    }

    private func monthLabels(weeks: [[Date]]) -> [Int: String] {
        var result: [Int: String] = [:]
        var lastMonth = -1
        for (i, week) in weeks.enumerated() {
            guard let first = week.first else { continue }
            let c = calendar.dateComponents([.day, .month], from: first)
            if (c.day ?? 99) <= 7, c.month != lastMonth {
                result[i] = Self.shortMonth(first, calendar)
                lastMonth = c.month ?? -1
            }
        }
        return result
    }

    // MARK: Day detail

    private func dayCard(daily: [Date: Double], now: Date) -> some View {
        let day = selected
        let daySessions = sessions
            .filter { calendar.isDate($0.start, inSameDayAs: day) }
            .sorted { $0.start < $1.start }
        let seconds = daily[day] ?? 0
        let firstNote = daySessions.compactMap(\.note).first(where: { !$0.isEmpty })
        let afterBreak = !daySessions.isEmpty && daySessions.allSatisfy { $0.source == .catchUp }

        return VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(RelativeDay.full(day, calendar: calendar)).lgText(.rowStrong)
                    Text(afterBreak ? "Added after a break" : firstNote ?? (seconds > 0 ? Labels.sessions(daySessions.count) : "Rest day"))
                        .lgText(LGTextStyle(size: 14, weight: .regular, relativeTo: .subheadline), color: LGColor.inkMuted)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                Text(seconds > 0 ? DurationFormat.short(seconds: seconds) : "—")
                    .lgText(LGTextStyle(size: 17, weight: .semibold, relativeTo: .body))
            }
            .padding(.vertical, 16)
            .accessibilityElement(children: .combine)

            if daySessions.count > 0 {
                ForEach(daySessions, id: \.persistentModelID) { session in
                    Divider().overlay(LGColor.divider)
                    sessionRow(session)
                }
            }
        }
        .padding(.horizontal, 18)
        .lgCard()
    }

    /// One session in the day card: its photo (56 pt) and note if it has them, otherwise a quiet "No note".
    /// Tapping the photo opens it full screen; tapping anywhere else edits the session.
    private func sessionRow(_ session: Session) -> some View {
        HStack(alignment: .top, spacing: 12) {
            if session.hasPhoto, let data = session.photo {
                Button { viewing = session } label: {
                    PhotoThumb(id: session.id, data: data, side: 56, radius: 12)
                        .frame(minWidth: 56, minHeight: 56)
                }
                .buttonStyle(.plain)
                .padding(.vertical, 8)
                .accessibilityLabel(SessionPhotos.spokenLabel(start: session.start))
                .accessibilityHint("Opens the photo")
            }
            Button { editing = session } label: {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(sessionTitle(session)).lgText(.row)
                        // A manual session already shows its note as the title.
                        if let note = session.note, !note.isEmpty, session.source != .manual {
                            Text(note)
                                .lgText(LGTextStyle(size: 14, weight: .regular, relativeTo: .subheadline), color: LGColor.inkMuted)
                                .lineLimit(3)
                                .multilineTextAlignment(.leading)
                        } else if !session.hasPhoto, session.note?.isEmpty != false {
                            Text("No note")
                                .lgText(LGTextStyle(size: 14, weight: .regular, relativeTo: .subheadline), color: Color(hex: 0xB3B8C7))
                        }
                    }
                    Spacer(minLength: 8)
                    Text(DurationFormat.short(seconds: session.durationSec)).lgText(.row, color: LGColor.inkMuted)
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(LGColor.inkMuted)
                        .padding(.top, 4)
                }
                .padding(.vertical, 12)
                .frame(minHeight: 48)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Edit or delete this session")
        }
    }

    private func sessionTitle(_ s: Session) -> String {
        if s.source == .catchUp { return "Added after a break" }
        if s.source == .manual { return s.note.flatMap { $0.isEmpty ? nil : $0 } ?? "Added hours" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_GB")
        f.dateFormat = "HH:mm"
        return "Session at " + f.string(from: s.start)
    }

    // MARK: Stats

    private func statsCard(daily: [Date: Double], windowStart: Date, now: Date) -> some View {
        let rhythm = Rhythm.compute(daily: daily, since: craft.createdAt, now: now, weekStart: weekStart, calendar: calendar)
        let active = Practice.activeDays(daily: daily, from: windowStart, to: now, calendar: calendar)
        let needed = max(1, rhythm.daysPerWeek - 1)
        return HStack(spacing: 0) {
            stat(rhythm.daysPerWeek > 0 ? Labels.daysPerWeek(rhythm.daysPerWeek) : "–", "Rhythm", info: .rhythm)
            Divider().overlay(LGColor.divider)
            stat(rhythm.daysPerWeek > 0 ? Labels.weeks(rhythm.steadyWeeks) : "–", "Steady for",
                 info: .steady(daysNeeded: rhythm.daysPerWeek > 0 ? needed : nil))
            Divider().overlay(LGColor.divider)
            stat("\(active)", "Active days", info: .active)
        }
        .padding(.vertical, 6)
        .fixedSize(horizontal: false, vertical: true)
        .lgCard()
    }

    /// Tapping a stat explains how it is worked out.
    private func stat(_ value: String, _ label: String, info: StatInfo) -> some View {
        Button { explaining = info } label: {
            VStack(spacing: 4) {
                Text(value).lgNumber(.statValue)
                Text(label).lgText(.caption, color: LGColor.inkMuted)
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .padding(.vertical, 12).padding(.horizontal, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Shows how this is worked out")
    }

    // MARK: Formatting

    private static func formatter(_ format: String, _ calendar: Calendar) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_GB")
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.dateFormat = format
        return f
    }

    private static func shortWeekday(_ d: Date, _ c: Calendar) -> String { formatter("EEE", c).string(from: d) }
    private static func shortMonth(_ d: Date, _ c: Calendar) -> String { formatter("MMM", c).string(from: d) }

    /// "Thursday 22 October, 2 hours" or "…, rest day"
    static func spoken(_ day: Date, seconds: Double, calendar: Calendar) -> String {
        let date = formatter("EEEE d MMMM", calendar).string(from: day)
        guard seconds > 0 else { return "\(date), rest day" }
        return "\(date), " + Labels.spoken(seconds: Int((seconds / 60).rounded()) * 60, includeSeconds: false)
    }
}

/// What each Calendar stat means, shown when it is tapped.
enum StatInfo: Identifiable {
    case rhythm
    case steady(daysNeeded: Int?)
    case active

    var id: String {
        switch self {
        case .rhythm: "rhythm"
        case .steady: "steady"
        case .active: "active"
        }
    }

    var title: String {
        switch self {
        case .rhythm: "Rhythm"
        case .steady: "Steady for"
        case .active: "Active days"
        }
    }

    var paragraphs: [String] {
        switch self {
        case .rhythm:
            ["Your typical number of practice days in a week.",
             "For each of the last 8 full weeks, and this week so far, we count the days with any time logged. Rhythm is the middle of those numbers, so one busy or quiet week barely moves it.",
             "Weeks from before you began aren't counted."]
        case .steady(let needed):
            ["How many weeks in a row, counting back from this week, you practised on at least one day fewer than your Rhythm.",
             needed.map { "Right now that means \($0) \($0 == 1 ? "day" : "days") a week." } ?? "Once you have a Rhythm, this shows how long you've kept it up.",
             "This week counts once it gets there, and it never ends your run while it's still going. Nothing ever breaks: a quiet week just starts a new run."]
        case .active:
            ["The number of days with any practice in the last 12 months, the same days you see lit up in the grid above.",
             "Hours added after a break count like any other."]
        }
    }
}

private struct StatExplainer: View {
    let info: StatInfo
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(info.title).lgText(.sheetTitle)
                .accessibilityAddTraits(.isHeader)
            ForEach(info.paragraphs, id: \.self) { text in
                Text(text).lgText(.body, color: LGColor.inkMuted)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button("Got it") { dismiss() }.buttonStyle(.lg(.primary))
        }
        .padding(.horizontal, 24).padding(.top, 28).padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(LGColor.background)
        .presentationDetents([.height(400), .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(32)
    }
}
