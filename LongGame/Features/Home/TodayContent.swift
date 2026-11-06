import SwiftUI

/// The big number and the line under it on the Today tab: today's time, then "of today's 1 h 45" (or what the
/// state says instead). One number, one quiet line.
struct TodayNumber: View {
    var state: StretchState
    var style: NumberLayout = .stacked

    var body: some View {
        style.container {
            switch state {
            case .stretch(let target, let done):
                big(StretchText.clock(seconds: done))
                sub(StretchText.ofToday(target))
            case .covered(let target, let done):
                big(StretchText.clock(seconds: done))
                sub(StretchText.coveredToday(target))
            case .weekCovered(let done):
                big(StretchText.clock(seconds: done))
                sub(String(localized: "This week is covered"))
            case .freeDay(let done) where done > 0:
                big(StretchText.clock(seconds: done))
                sub(String(localized: "a step ahead"))
            case .freeDay, .noTarget:
                big(String(localized: "Free day"))
                sub(String(localized: "Not one of your usual days"))
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

/// The one quiet line under the number (14 pt, muted).
struct TodayQuietLine: View {
    var state: StretchState
    /// Left-aligned, in the wide window's right pane.
    var leading = false

    private var text: String {
        switch state {
        case .stretch(let target, let done): StretchText.toGo(target - done)
        case .covered: String(localized: "You reached the moon.")
        case .weekCovered: String(localized: "Anything more is a bonus.")
        case .freeDay, .noTarget: String(localized: "Playing anyway brings your future a little closer.")
        }
    }

    var body: some View {
        Text(verbatim: text)
            .lgText(LGTextStyle(size: 14, weight: .regular, relativeTo: .subheadline), color: LGColor.gaugeLabel)
            .multilineTextAlignment(leading ? .leading : .center)
            .frame(maxWidth: .infinity, alignment: leading ? .leading : .center)
    }
}

#Preview("Today · in progress, covered, week covered, free day, free day while playing") {
    let states: [StretchState] = [
        .stretch(target: 6_300, done: 3_900),
        .covered(target: 3_600, done: 3_700),
        .weekCovered(done: 0),
        .freeDay(done: 0),
        .freeDay(done: 900),
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
