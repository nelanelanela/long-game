import SwiftUI
import SwiftData

struct CalendarTab: View {
    let craft: Craft
    let sessions: [Session]
    let weekStart: WeekStart

    @State private var selected = Calendar.current.startOfDay(for: Date())
    @State private var editing: Session?

    private let cell: CGFloat = 14
    private let gap: CGFloat = 3
    private var calendar: Calendar { .current }

    var body: some View {
        let now = Date()
        let weeks = CalendarGrid.weeks(endingOn: now, weekStart: weekStart, calendar: calendar)
        let daily = Streaks.dailySeconds(sessions.map(\.record), calendar: calendar)
        let windowStart = weeks.first?.first ?? now

        VStack(spacing: 18) {
            gridCard(weeks: weeks, daily: daily, windowStart: windowStart, now: now)
            dayCard(daily: daily, now: now)
            statsCard(daily: daily, windowStart: windowStart, now: now)
        }
        .sheet(item: $editing) { session in
            SessionFormView(craft: craft, sessions: sessions, editing: session)
        }
    }

    // MARK: Grid

    private func gridCard(weeks: [[Date]], daily: [Date: Double], windowStart: Date, now: Date) -> some View {
        let windowHours = sessions
            .filter { $0.start >= windowStart && $0.start <= now.addingTimeInterval(86_400) }
            .reduce(0.0) { $0 + $1.durationSec } / 3600
        let today = calendar.startOfDay(for: now)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Last 12 months").lgText(.rowStrong)
                Spacer()
                Text("\(Int(windowHours.rounded()).formatted()) h").lgText(.row, color: LGColor.inkMuted)
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
                                    dayCell(day, daily: daily, today: today)
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
        }
        .padding(.horizontal, 16).padding(.vertical, 18)
        .lgCard()
    }

    private func dayCell(_ day: Date, daily: [Date: Double], today: Date) -> some View {
        let isFuture = day > today
        let seconds = daily[day] ?? 0
        let level = CalendarLevel.level(hours: seconds / 3600)
        let isSelected = day == selected
        return RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(isFuture ? Color.clear : LGColor.calendar(level))
            .frame(width: cell, height: cell)
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
            .accessibilityLabel(Self.spoken(day, seconds: seconds, calendar: calendar))
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

        return VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(RelativeDay.full(day, calendar: calendar)).lgText(.rowStrong)
                    Text(firstNote ?? (seconds > 0 ? (daySessions.count == 1 ? "1 session" : "\(daySessions.count) sessions") : "Rest day"))
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
                    Button { editing = session } label: {
                        HStack {
                            Text(sessionTitle(session)).lgText(.row)
                            Spacer()
                            Text(DurationFormat.short(seconds: session.durationSec)).lgText(.row, color: LGColor.inkMuted)
                            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(LGColor.inkMuted)
                        }
                        .frame(minHeight: 48)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Edit or delete this session")
                }
            }
        }
        .padding(.horizontal, 18)
        .lgCard()
    }

    private func sessionTitle(_ s: Session) -> String {
        if s.source == .manual { return s.note.flatMap { $0.isEmpty ? nil : $0 } ?? "Added hours" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_GB")
        f.dateFormat = "HH:mm"
        return "Session at " + f.string(from: s.start)
    }

    // MARK: Stats

    private func statsCard(daily: [Date: Double], windowStart: Date, now: Date) -> some View {
        let current = Streaks.current(daily: daily, today: now, calendar: calendar)
        let longest = Streaks.longest(daily: daily, calendar: calendar)
        let active = Streaks.activeDays(daily: daily, from: windowStart, to: now, calendar: calendar)
        return HStack(spacing: 0) {
            VStack(spacing: 4) {
                Text("\(current) \(current == 1 ? "day" : "days")").lgNumber(.statValue)
                HStack(spacing: 4) {
                    SunView(face: .happy, rayColor: LGColor.sunRays).frame(width: 14, height: 14)
                    Text("Streak").lgText(.caption, color: LGColor.inkMuted)
                }
            }
            .frame(maxWidth: .infinity)
            Divider().overlay(LGColor.divider)
            stat("\(longest) \(longest == 1 ? "day" : "days")", "Longest")
            Divider().overlay(LGColor.divider)
            stat("\(active)", "Active days")
        }
        .padding(.vertical, 18)
        .fixedSize(horizontal: false, vertical: true)
        .lgCard()
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).lgNumber(.statValue)
            Text(label).lgText(.caption, color: LGColor.inkMuted)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
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
        let minutes = Int((seconds / 60).rounded())
        let h = minutes / 60, m = minutes % 60
        var parts: [String] = []
        if h > 0 { parts.append("\(h) \(h == 1 ? "hour" : "hours")") }
        if m > 0 { parts.append("\(m) \(m == 1 ? "minute" : "minutes")") }
        return "\(date), " + parts.joined(separator: " ")
    }
}
