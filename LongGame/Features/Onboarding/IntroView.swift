import SwiftUI

/// "How the game works": three swipeable pages between Welcome and "What's your game?".
/// Back goes a page back (from the first page, to Welcome); Skip and the last button go to "What's your game?".
struct IntroView: View {
    /// The real estimate once the user has made one; until then the design's example is shown.
    var startingScore: Int?
    let onBack: () -> Void
    let onFinish: () -> Void

    @State private var page = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Copy {
        let title: LocalizedStringKey
        let text: LocalizedStringKey
        let button: LocalizedStringKey
        let illustration: LocalizedStringKey
    }

    private static let pages: [Copy] = [
        Copy(title: "One game, 10,000 hours",
             text: "Roughly where mastery begins. That’s your finish line.",
             button: "Next",
             illustration: "The sun high above the sea, under a dashed line marking the finish line at 10,000 hours"),
        Copy(title: "You don’t start at zero",
             text: "The hours you’ve already practised are your starting score. Not sure how many? We’ll work it out together, one year at a time.",
             button: "Next",
             illustration: "The sun just rising out of the sea, above a badge showing your starting score"),
        Copy(title: "Play every day",
             text: "Start the timer, or add your hours later. Each hour is a step. What matters most is to keep walking.",
             button: "Choose your game",
             illustration: "The sun with 8 of its 12 rays lit, next to a badge saying plus 1 hour today"),
    ]

    private var count: Int { Self.pages.count }

    var body: some View {
        VStack(spacing: 0) {
            header
            #if os(iOS)
            TabView(selection: $page) {
                ForEach(0..<count, id: \.self) { index in
                    pageContent(index).tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            #else
            pageContent(page).id(page).frame(maxWidth: .infinity, maxHeight: .infinity)
            #endif

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
                IntroIllustration(page: index, startingScore: startingScore, label: copy.illustration)
                    .padding(.top, 8)
                VStack(alignment: .leading, spacing: 12) {
                    Text(copy.title)
                        .lgText(LGTextStyle(size: 30, weight: .bold, relativeTo: .title, tracking: -0.6))
                        .accessibilityAddTraits(.isHeader)
                    Text(copy.text)
                        .lgText(.body, color: LGColor.inkMuted)
                        .lineSpacing(4)
                }
                .padding(.horizontal, 24)
                .padding(.top, 18)
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
        .lgAnimation(.easeInOut(duration: 0.2), value: page)
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
        if page == 0 { onBack() } else { withAnimation(reduceMotion ? nil : .default) { page -= 1 } }
    }

    private func next() {
        if page < count - 1 { withAnimation(reduceMotion ? nil : .default) { page += 1 } } else { onFinish() }
    }
}

private struct HorizontalLine: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p
    }
}

/// The illustration of one intro page: the shared scene plus the page's badge (positions are the board's, 390 wide).
private struct IntroIllustration: View {
    let page: Int
    let startingScore: Int?
    let label: LocalizedStringKey

    private static let exampleScore = 3_208

    var body: some View {
        ZStack(alignment: .top) {
            switch page {
            case 0:
                SceneHero(tone: .day, height: 354, skyHeight: 340, horizon: 0.82, landTop: 234,
                          sunSize: 150, sunTop: 66, giggles: true, label: label)
            case 1:
                SceneHero(tone: .dawn, height: 354, skyHeight: 340, horizon: 0.82, landTop: 234,
                          sunSize: 150, sunTop: 204, giggles: true, label: label)
            default:
                SceneHero(tone: .day, height: 354, skyHeight: 340, horizon: 0.82, landTop: 234,
                          sunSize: 160, sunTop: 116, eyesOpen: 1, giggles: true, label: label)
            }
            badge.allowsHitTesting(false).accessibilityHidden(true)
        }
        .frame(height: 354)
    }

    @ViewBuilder
    private var badge: some View {
        switch page {
        case 0:
            ZStack(alignment: .topLeading) {
                HorizontalLine()
                    .stroke(LGColor.finishDash, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    .frame(height: 2)
                    .padding(.horizontal, 30)
                    .offset(y: 35)
                Text("Finish line · 10,000 h")
                    .lgText(LGTextStyle(size: 12, weight: .semibold, relativeTo: .caption), color: LGColor.finishLabel)
                    .padding(.leading, 30)
                    .offset(y: 14)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        case 1:
            chip(Text("Your starting score · \(DurationFormat.grouped(startingScore ?? Self.exampleScore)) h"),
                 background: .white, foreground: LGColor.ink)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 120)
        default:
            chip(Text("+1 h today"), background: LGColor.ink, foreground: .white)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 62)
        }
    }

    private func chip(_ text: Text, background: Color, foreground: Color) -> some View {
        text
            .lgText(LGTextStyle(size: 13, weight: .semibold, relativeTo: .subheadline), color: foreground)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: Color(hex: 0x0B1029, opacity: 0.25), radius: 9, y: 6)
    }
}

#Preview("Intro · page 1") { IntroView(onBack: {}, onFinish: {}) }
#Preview("Intro · large Dynamic Type") {
    IntroView(onBack: {}, onFinish: {}).environment(\.dynamicTypeSize, .accessibility3)
}
