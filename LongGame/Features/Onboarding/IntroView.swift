import SwiftUI

/// "How the game works": three swipeable pages between Welcome and "What's your game?".
/// Back goes a page back (from the first page, to Welcome); Skip and the last button go to "What's your game?".
struct IntroView: View {
    /// The real estimate once the user has made one; until then the design's example is shown.
    var startingScore: Int?
    let onBack: () -> Void
    let onFinish: () -> Void

    @State private var page = 0

    private struct Copy {
        let title: LocalizedStringKey
        let text: LocalizedStringKey
        let button: LocalizedStringKey
        let illustration: LocalizedStringKey
    }

    private static let pages: [Copy] = [
        Copy(title: "One game, 10,000 hours",
             text: "Around 10,000 hours of focused practice is where people tend to reach mastery in their craft: musicians, makers, surgeons, writers. That’s your finish line. It’s the longest game on the App Store, and it’s played in real life.",
             button: "Next",
             illustration: "The sun high above the sea, under a dashed line marking the finish line at 10,000 hours"),
        Copy(title: "You don’t start at level one",
             text: "Tell us roughly how much you’ve practised so far. Those hours become your starting score, whether you began last year or decades ago. It’s never too late to play.",
             button: "Next",
             illustration: "The sun just rising out of the sea, above a badge showing your starting score"),
        Copy(title: "Play it every day",
             text: "Start the sun timer when you practise, or add hours afterwards. Every hour lifts your sun a little higher, and Long Game shows you when you’ll cross the finish line.",
             button: "Choose your game",
             illustration: "The sun with 8 of its 12 rays lit, next to a badge saying plus 1 hour today"),
    ]

    private var count: Int { Self.pages.count }

    var body: some View {
        VStack(spacing: 0) {
            header
            TabView(selection: $page) {
                ForEach(0..<count, id: \.self) { index in
                    pageContent(index).tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            dots.padding(.bottom, 20)
            Button(Self.pages[page].button) { next() }
                .buttonStyle(.lg(.primary))
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
        }
        .lgScreen()
    }

    private var header: some View {
        HStack {
            LGIconButton(systemName: "chevron.left", label: "Back") { back() }
                .padding(.leading, -10)
            Spacer()
            Button(action: onFinish) {
                Text("Skip").lgText(LGTextStyle(size: 15, weight: .medium, relativeTo: .subheadline), color: LGColor.inkMuted)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
        }
        .padding(.horizontal, 24)
        .frame(height: 44)
        .padding(.top, 8)
    }

    private func pageContent(_ index: Int) -> some View {
        let copy = Self.pages[index]
        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                IntroIllustration(page: index, startingScore: startingScore)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(copy.illustration)
                    .accessibilityAddTraits(.isImage)
                    .padding(.top, 12)
                VStack(alignment: .leading, spacing: 12) {
                    Text(copy.title)
                        .lgText(LGTextStyle(size: 30, weight: .bold, relativeTo: .title, tracking: -0.6))
                        .accessibilityAddTraits(.isHeader)
                    Text(copy.text)
                        .lgText(.body, color: LGColor.inkMuted)
                        .lineSpacing(4)
                }
                .padding(.horizontal, 24)
                .padding(.top, 28)
                .padding(.bottom, 16)
            }
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private var dots: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == page ? LGColor.ink : LGColor.introDot)
                    .frame(width: index == page ? 22 : 7, height: 7)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: page)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Page \(page + 1) of \(count)"))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: if page < count - 1 { page += 1 }
            case .decrement: if page > 0 { page -= 1 }
            @unknown default: break
            }
        }
    }

    private func back() {
        if page == 0 { onBack() } else { withAnimation { page -= 1 } }
    }

    private func next() {
        if page < count - 1 { withAnimation { page += 1 } } else { onFinish() }
    }
}

/// The illustration of one intro page: the shared sunrise hero plus the page's badge.
private struct IntroIllustration: View {
    let page: Int
    let startingScore: Int?

    private static let exampleScore = 3_208

    var body: some View {
        ZStack(alignment: .topLeading) {
            SunriseHero(layout: .intro(page: page), label: "")
                .accessibilityHidden(true)
            GeometryReader { geo in
                overlay(width: geo.size.width)
            }
        }
        .frame(height: 300)
    }

    @ViewBuilder
    private func overlay(width: CGFloat) -> some View {
        switch page {
        case 0:
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .strokeBorder(LGColor.finishDash, style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
                    .frame(height: 0)
                    .padding(.horizontal, 32)
                    .offset(y: 46)
                Text("Finish line · 10,000 hours")
                    .lgText(.label, color: LGColor.finishLabel)
                    .padding(.leading, 32)
                    .offset(y: 18)
            }
        case 1:
            chip(Text("Your starting score · \(DurationFormat.grouped(startingScore ?? Self.exampleScore)) h"),
                 background: .white, foreground: LGColor.ink)
                .frame(maxWidth: .infinity)
                .offset(y: 86)
        default:
            chip(Text("+1 h today"), background: LGColor.ink, foreground: .white)
                .offset(x: (width - 390) / 2 + 262, y: 58)
        }
    }

    private func chip(_ text: Text, background: Color, foreground: Color) -> some View {
        text
            .lgText(LGTextStyle(size: 14, weight: .semibold, relativeTo: .subheadline), color: foreground)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(background, in: Capsule())
    }
}

#Preview("Intro · page 1") { IntroView(onBack: {}, onFinish: {}) }
#Preview("Intro · large Dynamic Type") {
    IntroView(onBack: {}, onFinish: {}).environment(\.dynamicTypeSize, .accessibility3)
}
