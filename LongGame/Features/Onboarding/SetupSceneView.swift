import SwiftUI

/// A small picture of the game that builds up through setup (updates 53, `design/redesign/SetupScene.dc.html`): at
/// the top of steps 2, 3 and 4, full width, 6 pt under the top bar. The day sky and land, a dashed gold finish line at
/// 10,000 h, and the happy sun at the height of the starting score; under it, chips for what has been set so far.
struct SetupSceneView: View {
    let state: SetupSceneState

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    /// The board's 390 × 80 picture: the sun's centre runs from the horizon (0 h) up to the finish line (10,000 h).
    private static let height: CGFloat = 80
    private static let horizonY: CGFloat = 64
    private static let finishY: CGFloat = 16
    private static let sunSize: CGFloat = 48
    /// The land box (390 × 120) starts here; its shoreline (46 pt down) meets the horizon.
    private static let landTop: CGFloat = 19

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            picture
            chips.padding(.horizontal, 24)
        }
        // One element for VoiceOver, read as a picture; its words change as the steppers move without moving focus.
        .accessibilityHidden(true)
        .overlay {
            Color.clear
                .accessibilityElement()
                .accessibilityLabel(Text(verbatim: state.spoken))
                .accessibilityAddTraits(.isImage)
        }
    }

    private var picture: some View {
        let dark = colorScheme == .dark
        let sunY = Self.horizonY - (Self.horizonY - Self.finishY) * state.sunHeight
        return GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                SkyView(tone: dark ? .dawn : .day, horizon: 0.8, moon: false, glowX: 0.5)
                    .frame(width: geo.size.width, height: Self.height)
                // The finish line: the top of the scene is 10,000 h.
                Path { p in
                    p.move(to: CGPoint(x: 24, y: Self.finishY))
                    p.addLine(to: CGPoint(x: geo.size.width - 24, y: Self.finishY))
                }
                .stroke(LGColor.setupFinishLine, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [4, 5]))
                Text("Finish line · 10,000 h")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(LGColor.ember)
                    .lineLimit(1)
                    .fixedSize()
                    .frame(width: geo.size.width - 24, alignment: .trailing)
                    .offset(y: 2)
                SunView(idle: false, face: .happy)
                    .frame(width: Self.sunSize, height: Self.sunSize)
                    .position(x: geo.size.width / 2, y: sunY)
                    .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.7), value: sunY)
                // The land and sea in front of the sun: at 0 h its lower half is under the sea, as on Home.
                LandView(tone: dark ? .night : .day)
                    .frame(width: geo.size.width, height: 120)
                    .offset(y: Self.landTop)
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
                                               startPoint: .leading, endPoint: .trailing), in: Capsule())
                    .shadow(color: LGColor.amber.opacity(0.3), radius: 5, y: 3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Filled: white with a soft shadow, or #FFF0C8 with a gold ring while it is being changed on this step.
    /// Not yet set: a thin #D9D2C6 outline and a muted placeholder.
    @ViewBuilder
    private func chip(_ value: String?, placeholder: String, as kind: SetupSceneState.Chip) -> some View {
        let editing = state.editing == kind
        if let value {
            Text(verbatim: value)
                .lgText(LGTextStyle(size: 12, weight: .semibold, relativeTo: .caption))
                .padding(.horizontal, 11)
                .frame(minHeight: 28)
                .background {
                    Capsule().fill(editing ? LGColor.setupChipEditing : LGColor.surface)
                        .shadow(color: LGColor.navy.opacity(editing ? 0 : 0.06), radius: 5, y: 3)
                }
                .overlay { if editing { Capsule().strokeBorder(LGColor.setupChipRing, lineWidth: 1.5) } }
        } else {
            Text(verbatim: placeholder)
                .lgText(LGTextStyle(size: 12, weight: .medium, relativeTo: .caption), color: LGColor.gaugeLabel)
                .padding(.horizontal, 11)
                .frame(minHeight: 28)
                .overlay { Capsule().strokeBorder(LGColor.setupChipPending, lineWidth: 1) }
        }
    }
}

/// The thin strip on steps 3 and 4: "Before today" · a bar · Today · a bar · "Next 12 months". The part the screen
/// is about is lit gold with a bold label; on step 3 the future is a dashed line, on step 4 the past a grey bar.
struct SetupTimeStripView: View {
    let lit: SetupTimeStrip

    var body: some View {
        // One line when it fits; at the largest text sizes the three parts stack, so the page never grows wider.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                label("Before today", lit: lit == .beforeToday)
                bar(lit: lit == .beforeToday, dashed: false)
                VStack(spacing: 3) {
                    dot
                    today
                }
                .padding(.top, 13)
                bar(lit: lit == .nextYear, dashed: lit == .beforeToday)
                label("Next 12 months", lit: lit == .nextYear)
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    bar(lit: lit == .beforeToday, dashed: false).frame(width: 36)
                    label("Before today", lit: lit == .beforeToday)
                }
                HStack(spacing: 10) {
                    dot.frame(width: 36)
                    today
                }
                HStack(spacing: 10) {
                    bar(lit: lit == .nextYear, dashed: lit == .beforeToday).frame(width: 36)
                    label("Next 12 months", lit: lit == .nextYear)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityHidden(true)
        .overlay {
            Color.clear
                .accessibilityElement()
                .accessibilityLabel(Text(verbatim: lit.spoken))
                .accessibilityAddTraits(.isImage)
        }
    }

    private var dot: some View { Circle().fill(LGColor.selectedFill).frame(width: 10, height: 10) }

    private var today: some View {
        Text("Today").lgText(LGTextStyle(size: 10, weight: .semibold, relativeTo: .caption2))
    }

    private func label(_ text: LocalizedStringKey, lit: Bool) -> some View {
        Text(text)
            .lgText(LGTextStyle(size: 12, weight: lit ? .bold : .medium, relativeTo: .caption),
                    color: lit ? LGColor.ember : LGColor.inkMuted)
            .lineLimit(1)
            .fixedSize()
    }

    @ViewBuilder
    private func bar(lit: Bool, dashed: Bool) -> some View {
        if lit {
            Capsule().fill(LinearGradient(colors: [LGColor.setupLitStart, LGColor.setupLitEnd],
                                          startPoint: .leading, endPoint: .trailing))
                .frame(minWidth: 28, idealWidth: 28, maxWidth: .infinity, minHeight: 4, maxHeight: 4)
        } else if dashed {
            Line().stroke(LGColor.setupChipPending, style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
                .frame(minWidth: 28, idealWidth: 28, maxWidth: .infinity, minHeight: 4, maxHeight: 4)
        } else {
            Capsule().fill(LGColor.setupStripQuiet)
                .frame(minWidth: 28, idealWidth: 28, maxWidth: .infinity, minHeight: 4, maxHeight: 4)
        }
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            Path { p in p.move(to: CGPoint(x: rect.minX, y: rect.midY)); p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY)) }
        }
    }
}

#Preview("Setup scene and strip") {
    VStack(spacing: 16) {
        SetupSceneView(state: SetupSceneState(craftName: "Calligraphy", startYear: 2019, editing: .startYear))
        SetupSceneView(state: SetupSceneState(craftName: "Calligraphy", startYear: 2019, score: 3_208, editing: .score))
        SetupTimeStripView(lit: .beforeToday).padding(.horizontal, 24)
        SetupSceneView(state: SetupSceneState(craftName: "Calligraphy", startYear: 2019, score: 3_100, weeklyPace: 12,
                                              showsFinish: true, editing: .pace))
        SetupTimeStripView(lit: .nextYear).padding(.horizontal, 24)
    }
    .lgScreen()
}
