import SwiftUI

/// The row under the day bars: how the week stands against the target, and what the target is. Opens the
/// "Your pace for the year" screen. From 14 days before the year ends (and after it, until a new one is set) the
/// reminder takes the place of the second line.
struct TargetRow: View {
    let target: TargetRecord?
    let hoursThisWeek: Double
    let weekStart: WeekStart
    var now: Date = Date()

    private var week: WeekTarget? {
        target.map { WeekTarget.make(hoursThisWeek: hoursThisWeek, target: $0.hoursPerWeek, now: now, weekStart: weekStart) }
    }

    private var headline: String { week?.headline ?? String(localized: "Choose your pace for the year") }

    private var subtitle: String {
        guard let target else { return String(localized: "Hours a week for the next 12 months") }
        // Non-breaking spaces keep the date in one piece when the line wraps.
        let until = DateText.dayMonthYear(target.end).replacingOccurrences(of: " ", with: "\u{00A0}")
        return TargetCycle.reminder(target, now: now)
            ?? "Your pace for the year: \(DurationFormat.hours(target.hoursPerWeek)) a week, until \(until)"
    }

    private var reminding: Bool { target.flatMap { TargetCycle.reminder($0, now: now) } != nil }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(headline)
                    .lgText(.rowStrong, color: week?.reached == true ? LGColor.finishLabel : LGColor.ink)
                Text(subtitle)
                    .lgText(.caption, color: reminding ? LGColor.finishLabel : LGColor.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .lgIcon(13, weight: .semibold)
                .foregroundStyle(LGColor.inkMuted)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens your pace for the year")
    }
}
