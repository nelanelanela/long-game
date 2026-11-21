import SwiftUI

/// A small picture of the game that builds up through setup (update 53, `design/redesign/SetupScene.dc.html`): at the
/// top of steps 2, 3 and 4, right under the top bar. The day sky and land, a dashed gold finish line at 10,000 h, and
/// the happy sun at the height of the starting score; under it, chips for what has been set so far.
struct SetupSceneView: View {
    let state: SetupSceneState

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    /// The picture is 80 pt tall: the sun's centre runs from the horizon (0 h) up to the finish line (10,000 h).
    private static let height: CGFloat = 80
    private static let horizonY: CGFloat = 56
    private static let finishY: CGFloat = 16
    private static let sunSize: CGFloat = 48

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            picture
            chips.padding(.horizontal, 24)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: state.spoken))
    }

    private var picture: some View {
        let dark = colorScheme == .dark
        let sunY = Self.horizonY - (Self.horizonY - Self.finishY) * state.sunHeight
        return GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                SkyView(tone: dark ? .dawn : .day, horizon: Self.horizonY / Self.height, moon: false)
                    .frame(width: geo.size.width, height: Self.height)
                // The finish line, dashed, with its label at the right end.
                Path { p in
                    p.move(to: CGPoint(x: 16, y: Self.finishY))
                    p.addLine(to: CGPoint(x: geo.size.width - 134, y: Self.finishY))
                }
                .stroke(LGColor.setupChipRing, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [4, 4]))
                Text("Finish line · 10,000 h")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(LGColor.ember)
                    .lineLimit(1)
                    .fixedSize()
                    .position(x: geo.size.width - 74, y: Self.finishY)
                SunView(idle: false, face: .happy)
                    .frame(width: Self.sunSize, height: Self.sunSize)
                    .position(x: geo.size.width / 2, y: sunY)
                    .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.7), value: sunY)
                // The land and sea in front of the sun: at 0 h its lower half is under the sea, as on Home.
                LandView(tone: dark ? .night : .day)
                    .frame(width: geo.size.width, height: 60)
                    .offset(y: Self.horizonY - 23)
            }
        }
        .frame(height: Self.height)
        .clipped()
        .allowsHitTesting(false)
    }

    private var chips: some View {
        FlowLayout(spacing: 6) {
            chip(state.craftName.isEmpty ? nil : state.craftName, placeholder: String(localized: "your game"), as: .craft)
            chip(state.startText, placeholder: String(localized: "start year"), as: .startYear)
            chip(state.scoreText, placeholder: String(localized: "starting score"), as: .score)
            chip(state.paceText, placeholder: String(localized: "weekly pace"), as: .pace)
            if let finish = state.finishText {
                Text(verbatim: finish)
                    .lgText(LGTextStyle(size: 12, weight: .bold, relativeTo: .caption), color: LGColor.navy)
                    .padding(.horizontal, 11)
                    .frame(minHeight: 28)
                    .background(LinearGradient(colors: [LGColor.setupFinishTop, LGColor.setupFinishBottom],
                                               startPoint: .top, endPoint: .bottom), in: Capsule())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func chip(_ value: String?, placeholder: String, as kind: SetupSceneState.Chip) -> some View {
        let editing = state.editing == kind
        if let value {
            Text(verbatim: value)
                .lgText(LGTextStyle(size: 12, weight: .semibold, relativeTo: .caption))
                .lineLimit(1)
                .padding(.horizontal, 11)
                .frame(minHeight: 28)
                .background(editing ? LGColor.setupChipEditing : LGColor.surface, in: Capsule())
                .overlay { if editing { Capsule().strokeBorder(LGColor.setupChipRing, lineWidth: 1.5) } }
        } else {
            Text(verbatim: placeholder)
                .lgText(LGTextStyle(size: 12, weight: .medium, relativeTo: .caption), color: LGColor.inkMuted)
                .padding(.horizontal, 11)
                .frame(minHeight: 28)
                .background(editing ? LGColor.setupChipEditing : .clear, in: Capsule())
                .overlay {
                    Capsule().strokeBorder(editing ? LGColor.setupChipRing : LGColor.setupChipPending,
                                           style: StrokeStyle(lineWidth: editing ? 1.5 : 1, dash: editing ? [] : [3, 3]))
                }
        }
    }
}

/// The thin strip under the setup scene on steps 3 and 4: "Before today" · a bar · Today · a bar · "Next 12 months".
/// The part the screen is about is lit gold with a bold label.
struct SetupTimeStripView: View {
    let lit: SetupTimeStrip

    var body: some View {
        HStack(spacing: 8) {
            label("Before today", lit: lit == .beforeToday)
            bar(lit: lit == .beforeToday, dashed: false)
            VStack(spacing: 2) {
                Circle().fill(LGColor.selectedFill).frame(width: 8, height: 8)
                Text("Today").lgText(LGTextStyle(size: 10, weight: .semibold, relativeTo: .caption2))
            }
            .padding(.top, 12)
            bar(lit: lit == .nextYear, dashed: lit == .beforeToday)
            label("Next 12 months", lit: lit == .nextYear)
        }
        .padding(.horizontal, 24)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: lit.spoken))
    }

    private func label(_ text: LocalizedStringKey, lit: Bool) -> some View {
        Text(text)
            .lgText(LGTextStyle(size: 12, weight: lit ? .bold : .regular, relativeTo: .caption),
                    color: lit ? LGColor.ember : LGColor.inkMuted)
            .lineLimit(1)
            .fixedSize()
    }

    @ViewBuilder
    private func bar(lit: Bool, dashed: Bool) -> some View {
        if lit {
            Capsule().fill(LinearGradient(colors: [LGColor.setupFinishTop, LGColor.setupFinishBottom],
                                          startPoint: .leading, endPoint: .trailing))
                .frame(height: 4)
        } else if dashed {
            Line().stroke(LGColor.setupStripQuiet, style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [4, 5]))
                .frame(height: 4)
        } else {
            Capsule().fill(LGColor.setupStripQuiet).frame(height: 4)
        }
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            Path { p in p.move(to: CGPoint(x: rect.minX, y: rect.midY)); p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY)) }
        }
    }
}

#Preview("Setup scene · step 2") {
    VStack(spacing: 16) {
        SetupSceneView(state: SetupSceneState(craftName: "Calligraphy", startYear: 2019, editing: .startYear))
        SetupSceneView(state: SetupSceneState(craftName: "Calligraphy", startYear: 2019, score: 3_100, editing: .score))
        SetupTimeStripView(lit: .beforeToday)
        SetupSceneView(state: SetupSceneState(craftName: "Calligraphy", startYear: 2019, score: 3_100, weeklyPace: 12,
                                              showsFinish: true, editing: .pace))
        SetupTimeStripView(lit: .nextYear)
    }
    .lgScreen()
}
