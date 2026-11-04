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
            case .restDay(let done) where done > 0:
                big(StretchText.clock(seconds: done))
                sub(String(localized: "a rest-day bonus"))
            case .restDay, .noTarget:
                big(String(localized: "Rest day"))
                sub(String(localized: "The sun's taking it easy too"))
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
        case .covered, .weekCovered: String(localized: "Anything more is a bonus.")
        case .restDay(let done) where done > 0: String(localized: "Every minute still counts.")
        case .restDay, .noTarget: String(localized: "Playing anyway? Every minute still counts.")
        }
    }

    var body: some View {
        Text(verbatim: text)
            .lgText(LGTextStyle(size: 14, weight: .regular, relativeTo: .subheadline), color: LGColor.gaugeLabel)
            .multilineTextAlignment(leading ? .leading : .center)
            .frame(maxWidth: .infinity, alignment: leading ? .leading : .center)
    }
}
