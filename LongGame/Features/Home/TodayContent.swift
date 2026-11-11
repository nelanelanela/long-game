import SwiftUI

/// The big number and the line under it on the Today tab: today's time, then "of today's 1 h 45" (or what the
/// state says instead). One number, one quiet line.
struct TodayNumber: View {
    var state: StretchState
    var style: NumberLayout = .stacked

    var body: some View {
        style.container {
            switch state {
            case .inProgress(let target, let done):
                big(StretchText.clock(seconds: done))
                sub(StretchText.ofToday(target))
            case .covered(let target, let done):
                big(StretchText.clock(seconds: done))
                sub(StretchText.coveredToday(target))
            case .noTarget:
                big(StretchText.clock(seconds: 0))
                sub(String(localized: "No weekly pace yet"))
            }
        }
    }

    private func big(_ text: String) -> some View {
        Text(verbatim: text).lgNumber(style.numberStyle).monospacedDigit().lineLimit(1).minimumScaleFactor(0.5)
    }

    private func sub(_ text: String) -> some View {
        Text(verbatim: text).lgText(.row, color: LGColor.inkMuted)
    }
}

/// Today before anything has been played: a short welcome instead of "0 m".
struct EmptyDayHeading: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("The sun is up.").lgText(LGTextStyle(size: 34, weight: .bold, relativeTo: .largeTitle, tracking: -1))
                .multilineTextAlignment(.center)
            Text("What will you practise today?").lgText(.bodyLarge, color: LGColor.inkMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 10)
    }
}

/// The one quiet line under the number (14 pt, muted).
struct TodayQuietLine: View {
    var state: StretchState
    /// Left-aligned, in the wide window's right pane.
    var leading = false

    private var text: String { StretchText.quietLine(state) }

    var body: some View {
        Text(verbatim: text)
            .lgText(LGTextStyle(size: 14, weight: .regular, relativeTo: .subheadline), color: LGColor.gaugeLabel)
            .multilineTextAlignment(leading ? .leading : .center)
            .frame(maxWidth: .infinity, alignment: leading ? .leading : .center)
    }
}

#Preview("Today · to go, done, extra") {
    let states: [StretchState] = [
        .inProgress(target: 6_300, done: 3_900),
        .covered(target: 3_600, done: 3_620),
        .covered(target: 6_300, done: 7_800),
    ]
    VStack(spacing: 24) {
        ForEach(Array(states.enumerated()), id: \.offset) { _, state in
            VStack(spacing: 4) {
                TodayNumber(state: state)
                TodayQuietLine(state: state)
            }
        }
    }
    .padding()
    .background(LGColor.background)
}
