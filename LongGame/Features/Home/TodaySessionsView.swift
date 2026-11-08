import SwiftUI

/// "Today's sessions" under the quiet line on the Today tab: one row per session that started today, oldest first,
/// and the running timer as the first row. Tapping a saved row opens it to edit.
struct TodaySessionsList: View {
    var rows: [TodaySession]
    /// Seconds of the running timer when it started today, nil when none runs.
    var running: TimeInterval?
    var onSelect: (UUID) -> Void = { _ in }
    /// A picture dropped on a row (Photos or Files on an iPad or Mac): attach it to that session.
    var onDropImage: ((UUID, Data) -> Void)?
    var calendar: Calendar = .current

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if !rows.isEmpty || running != nil {
            VStack(alignment: .leading, spacing: 0) {
                Text("Today's sessions")
                    .lgText(LGTextStyle(size: 13, weight: .semibold, relativeTo: .footnote), color: LGColor.gaugeLabel)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.bottom, 6)
                if let running {
                    NowRow(seconds: running)
                    if !rows.isEmpty { Divider().overlay(LGColor.divider) }
                }
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    if index > 0 { Divider().overlay(LGColor.divider) }
                    SessionRow(row: row, calendar: calendar, stacked: typeSize.isAccessibilitySize,
                               onDrop: onDropImage.map { drop in { data in drop(row.id, data) } }) { onSelect(row.id) }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct SessionRow: View {
    let row: TodaySession
    let calendar: Calendar
    let stacked: Bool
    var onDrop: ((Data) -> Void)?
    let action: () -> Void
    @State private var dropping = false

    var body: some View {
        Button(action: action) {
            let layout = stacked ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(spacing: 12))
            layout {
                HStack(spacing: 12) {
                    thumbnail
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: TodaySessions.timeRange(start: row.start, end: row.end, calendar: calendar))
                            .lgText(LGTextStyle(size: 14, weight: .semibold, relativeTo: .subheadline)).monospacedDigit()
                        if let note = TodaySessions.noteLine(row.note) {
                            Text(verbatim: note)
                                .lgText(LGTextStyle(size: 13, weight: .regular, relativeTo: .footnote), color: LGColor.inkMuted)
                                .lineLimit(stacked ? 3 : 1).truncationMode(.tail)
                        } else {
                            Text("No note")
                                .lgText(LGTextStyle(size: 13, weight: .regular, relativeTo: .footnote), color: LGColor.gaugeLabel)
                        }
                    }
                    if !stacked { Spacer(minLength: 8) }
                }
                Text(verbatim: TodaySessions.duration(row.durationSec))
                    .lgText(LGTextStyle(size: 15, weight: .semibold, relativeTo: .subheadline)).monospacedDigit()
                    .padding(.leading, stacked ? 52 : 0)
            }
            .padding(.vertical, 8)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .lgPointerHighlight()
        .lgImageDrop(isTargeted: $dropping) { onDrop?($0) }
        .background(dropping ? LGColor.stepperHighlight : .clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(TodaySessions.spoken(row, calendar: calendar))
        .accessibilityHint("Edit or delete this session")
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let photo = row.photo {
            PhotoThumb(id: row.id, data: photo, side: 40, radius: 10)
        } else {
            SessionPictureThumb(id: row.id, start: row.start, durationSec: row.durationSec, progress: row.sunriseProgress,
                                side: 40, radius: 10)
        }
    }
}

/// The running session: "Now · 12 m" with a small pulsing dot (still with Reduce Motion).
private struct NowRow: View {
    let seconds: TimeInterval

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(LGColor.forecast.opacity(0.22)).frame(width: 20, height: 20)
                    .scaleEffect(pulse ? 1.25 : 0.8).opacity(pulse ? 0.3 : 1)
                Circle().fill(LGColor.forecast).frame(width: 9, height: 9)
            }
            .frame(width: 40, height: 40)
            Text(verbatim: TodaySessions.nowLabel(seconds: seconds))
                .lgText(LGTextStyle(size: 14, weight: .semibold, relativeTo: .subheadline)).monospacedDigit()
            Spacer(minLength: 8)
        }
        .padding(.vertical, 8)
        .frame(minHeight: 56)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(TodaySessions.spokenNow(seconds: seconds))
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { pulse = true }
        }
    }
}

#if DEBUG
@MainActor
private enum SessionsPreview {
    static let cal = Calendar.current
    static func at(_ h: Int, _ m: Int) -> Date { cal.date(bySettingHour: h, minute: m, second: 0, of: Date())! }
    static func row(_ h: Int, _ m: Int, minutes: Int, note: String?, photo: Bool = false) -> TodaySession {
        let start = at(h, m)
        return TodaySession(id: UUID(), start: start, end: start.addingTimeInterval(Double(minutes) * 60), durationSec: Double(minutes) * 60,
                            note: note, photo: photo ? PlatformImage.photoPlaceholder.pngData() : nil)
    }
    static let six = [
        row(7, 40, minutes: 40, note: "Scales and arpeggios", photo: true),
        row(9, 5, minutes: 15, note: nil),
        row(11, 30, minutes: 65, note: "A long note about the second movement that goes on and on past the edge"),
        row(13, 0, minutes: 20, note: "Sight-reading"),
        row(15, 45, minutes: 30, note: nil),
        row(18, 10, minutes: 45, note: "Evening run-through"),
    ]
    static func page(_ rows: [TodaySession], running: TimeInterval?) -> some View {
        ScrollView { TodaySessionsList(rows: rows, running: running).padding(24) }.lgScreen()
    }
}

#Preview("Today's sessions · none") { SessionsPreview.page([], running: nil) }
#Preview("Today's sessions · 2") { SessionsPreview.page(Array(SessionsPreview.six.prefix(2)), running: nil) }
#Preview("Today's sessions · 6 and a running timer") { SessionsPreview.page(SessionsPreview.six, running: 12 * 60) }
#Preview("Today's sessions · AX5") {
    SessionsPreview.page(Array(SessionsPreview.six.prefix(3)), running: 12 * 60).dynamicTypeSize(.accessibility5)
}
#endif
