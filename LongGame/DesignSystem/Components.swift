import SwiftUI

// MARK: Card

struct LGCardModifier: ViewModifier {
    var radius: CGFloat = 20
    func body(content: Content) -> some View {
        // White, with the redesign's soft shadow (0 8 24, navy at 6%).
        content
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(LGColor.surface)
                    .shadow(color: LGColor.ink.opacity(0.06), radius: 12, y: 8)
            }
    }
}

extension View {
    func lgCard(radius: CGFloat = 20) -> some View { modifier(LGCardModifier(radius: radius)) }

    /// The warm-white screen background.
    func lgScreen() -> some View {
        background(LGColor.background.ignoresSafeArea())
    }

    /// The setup steps' background: a peach wash at the top that fades into the screen colour by 38% of the height.
    func lgSetupScreen(fadeBy: CGFloat = 0.38) -> some View {
        background {
            LinearGradient(stops: [.init(color: LGColor.peachWashSetup, location: 0),
                                   .init(color: LGColor.background, location: fadeBy),
                                   .init(color: LGColor.background, location: 1)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        }
    }
}

/// "by We Have Sun": the small letter-spaced line under the wordmark and under the setup screens' main button.
struct LGBrandLine: View {
    var text: LocalizedStringKey = "by We Have Sun"
    var body: some View {
        Text(text)
            .lgText(LGTextStyle(size: 11, weight: .semibold, relativeTo: .caption2, tracking: 1.76), color: LGColor.inkMuted)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity)
    }
}

/// The round − / + face used where a screen draws its own stepper (the start year): white, softly lit from the top
/// left, with a small shadow. From iOS 26 it is a glass circle like every other round control.
struct LGStepCircle: View {
    let systemName: String
    var diameter: CGFloat = 56
    var dimmed = false
    @Environment(\.lgFlat) private var flat

    var body: some View {
        let glyph = Image(systemName: systemName)
            .font(.system(size: diameter > 40 ? 22 : 15, weight: .semibold))
            .foregroundStyle(dimmed ? LGColor.stepperGlyphLimit : LGColor.ink)
            .frame(width: diameter, height: diameter)
        if #available(iOS 26, macOS 26, *), !flat {
            glyph.glassEffect(.regular.interactive(), in: .circle).opacity(dimmed ? 0.55 : 1)
        } else {
            glyph.background {
                Circle()
                    .fill(dimmed ? AnyShapeStyle(LGColor.stepperButtonLimit)
                                 : AnyShapeStyle(RadialGradient(colors: [.white, LGColor.stepperFace],
                                                                center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: diameter * 0.7)))
                    .shadow(color: LGColor.ink.opacity(dimmed ? 0 : 0.1), radius: diameter > 40 ? 8 : 4, y: diameter > 40 ? 6 : 3)
            }
        }
    }
}

// MARK: Buttons

struct LGButtonStyle: ButtonStyle {
    /// `quiet` is a secondary action (Add past hours, Discard): a plain text button before iOS 26, a 48 pt clear
    /// glass capsule from iOS 26.
    enum Kind { case primary, secondary, light, translucent, text, quiet }
    var kind: Kind = .primary
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.lgFlat) private var flat
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityShowButtonShapes) private var showButtonShapes

    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        if #available(iOS 26, macOS 26, *), !flat, kind != .text {
            glassBody(configuration)
        } else {
            flatBody(configuration)
        }
    }

    /// Liquid Glass: capsules. Primary is ink-tinted (56 pt), secondary clear glass with navy text (48 pt); on the
    /// Timer, Pause and Resume are clear glass with white text and Finish is bright glass with navy text.
    @available(iOS 26, macOS 26, *)
    private func glassBody(_ configuration: Configuration) -> some View {
        let height: CGFloat = (kind == .quiet || kind == .secondary) ? 48 : 56
        return configuration.label
            .lgText(.button, color: foreground)
            .frame(maxWidth: .infinity)
            .frame(minHeight: height)
            .glassEffect(glass, in: .capsule)
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.4)
            .contentShape(Capsule())
    }

    @available(iOS 26, macOS 26, *)
    private var glass: Glass {
        switch kind {
        case .primary: .regular.tint(LGColor.ink).interactive()
        case .light: .regular.tint(.white).interactive()
        case .translucent: .clear.interactive()
        default: .regular.interactive()
        }
    }

    private func flatBody(_ configuration: Configuration) -> some View {
        let isText = kind == .text || kind == .quiet
        let label = configuration.label
            .lgText(isText ? .rowStrong : .button, color: foreground)
            .frame(maxWidth: .infinity)
            .frame(minHeight: isText ? 48 : 56)
        return Group {
            switch kind {
            case .text, .quiet:
                // Settings > Accessibility > Button Shapes: plain text buttons get an underline.
                label.underline(showButtonShapes)
            case .secondary:
                label.lgCard(radius: 16)
            default:
                label.background(background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.4)
        .contentShape(Rectangle())
    }

    private var foreground: Color {
        switch kind {
        case .primary: .white
        case .translucent: .white
        default: LGColor.ink
        }
    }

    private var background: Color {
        switch kind {
        case .primary: LGColor.ink
        case .light: .white
        case .translucent: .white.opacity(reduceTransparency || contrast == .increased ? 0.28 : 0.12)
        default: .clear
        }
    }
}

extension ButtonStyle where Self == LGButtonStyle {
    static func lg(_ kind: LGButtonStyle.Kind = .primary) -> LGButtonStyle { LGButtonStyle(kind: kind) }
}

/// Round icon buttons: back, close, calendar, plus (44 pt touch target).
/// True where a screen's title area sits on the dark dawn sky (The long game): its text and icons turn white.
private struct LGOnDarkKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    var lgOnDark: Bool {
        get { self[LGOnDarkKey.self] }
        set { self[LGOnDarkKey.self] = newValue }
    }
}

struct LGIconButton: View {
    let systemName: String
    let label: String
    var tint: Color?
    var size: CGFloat = 18
    var weight: Font.Weight = .medium
    let action: () -> Void
    @Environment(\.lgFlat) private var flat
    @Environment(\.lgOnDark) private var onDark

    var body: some View {
        Button(action: action) {
            icon
        }
        .accessibilityLabel(label)
    }

    private var image: some View {
        Image(systemName: systemName)
            .font(.system(size: size, weight: weight))
            .foregroundStyle(tint ?? (onDark ? .white : LGColor.ink))
            .frame(width: 44, height: 44)
    }

    /// A 44 pt glass circle from iOS 26; the plain icon before.
    @ViewBuilder private var icon: some View {
        if #available(iOS 26, macOS 26, *), !flat {
            image.glassEffect(.regular.interactive(), in: .circle).contentShape(Circle())
        } else {
            image.contentShape(Rectangle())
        }
    }
}

// MARK: Section label and pills

struct LGSectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).lgText(.label, color: LGColor.inkMuted)
            .accessibilityAddTraits(.isHeader)
    }
}

struct LGPill: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .lgText(.row, color: selected ? .white : LGColor.ink)
                .padding(.horizontal, 16)
                .frame(minHeight: 40)
                .background(selected ? LGColor.ink : LGColor.surface, in: Capsule())
                .overlay(Capsule().stroke(selected ? Color.clear : LGColor.chipBorder, lineWidth: 1))
                .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

/// Step dots at the top of onboarding.
struct LGStepBar: View {
    let step: Int
    let of: Int
    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...of, id: \.self) { i in
                // Done steps are the sun's gold running to amber; the rest are the quiet track.
                RoundedRectangle(cornerRadius: 2)
                    .fill(i <= step ? AnyShapeStyle(LinearGradient(colors: [LGColor.sunBody, LGColor.amber], startPoint: .leading, endPoint: .trailing))
                                    : AnyShapeStyle(LGColor.chipBorder))
                    .frame(width: 22, height: 4)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(step) of \(of)")
    }
}

// MARK: Segmented control

/// Two or more segments on a warm track with a white pill under the chosen one: Home's Today | This week | The long
/// game, History's Calendar | Growth, Your year's Sunrise | Evening | Photos. From iOS 26 the track is a glass
/// capsule and the chosen tab a brighter, interactive glass lens that morphs between tabs.
struct LGSegmentedControl<Item: Hashable>: View {
    let items: [Item]
    let selection: Item
    /// What VoiceOver calls the group.
    let label: LocalizedStringKey
    let title: (Item) -> LocalizedStringKey
    let onSelect: (Item) -> Void

    @Environment(\.lgFlat) private var flat
    @Environment(\.lgOnDark) private var onDark
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var lens

    var body: some View {
        Group {
            if #available(iOS 26, macOS 26, *), !flat {
                glassTabs
            } else {
                flatTabs
            }
        }
        // A tab list for VoiceOver: "Today, tab, 1 of 3, selected".
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isTabBar)
    }

    /// The flat tabs (before iOS 26) have a white chosen pill, so its title stays navy even on the dark sky.
    private var isFlat: Bool {
        if #available(iOS 26, macOS 26, *) { return flat }
        return true
    }

    private func segmentTitle(_ item: Item, selected: Bool) -> some View {
        Text(title(item))
            .lgText(LGTextStyle(size: 14, weight: selected ? .semibold : .medium, relativeTo: .subheadline),
                    color: onDark && !(selected && isFlat) ? .white : LGColor.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            // Like the system's own tab bars, the three tab names stop growing at the largest accessibility sizes so
            // they stay whole; everything else on the screen keeps growing.
            .dynamicTypeSize(...DynamicTypeSize.xLarge)
            .frame(maxWidth: .infinity, minHeight: 36)
    }

    private var flatTabs: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.self) { item in
                let selected = item == selection
                Button { onSelect(item) } label: {
                    segmentTitle(item, selected: selected)
                        .background {
                            if selected {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(.white)
                                    .shadow(color: LGColor.ink.opacity(0.1), radius: 1.5, y: 1)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? [.isSelected] : [])
            }
        }
        .padding(3)
        .background(onDark ? Color.white.opacity(0.16) : LGColor.segmentTrack, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @available(iOS 26, macOS 26, *)
    private var glassTabs: some View {
        GlassEffectContainer(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(items, id: \.self) { item in
                    let selected = item == selection
                    Button { onSelect(item) } label: {
                        segmentTitle(item, selected: selected)
                            .background { if selected { lensView } }
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? [.isSelected] : [])
                }
            }
            .padding(3)
            .glassEffect(.regular, in: .capsule)
        }
    }

    /// The lens: with Reduce Motion it just appears under the chosen tab instead of stretching across.
    @available(iOS 26, macOS 26, *)
    @ViewBuilder private var lensView: some View {
        if reduceMotion {
            Color.clear.glassEffect(.regular.interactive(), in: .capsule)
        } else {
            Color.clear.glassEffect(.regular.interactive(), in: .capsule).glassEffectID("lens", in: lens)
        }
    }
}

// MARK: Hold-to-repeat step button

/// A round − or + button. One tap steps once; keeping a finger on it keeps stepping, faster the longer it is held,
/// until the finger lifts or the button becomes disabled (the value hit its limit).
struct LGRepeatButton: View {
    let systemName: String
    let label: String
    let enabled: Bool
    var diameter: CGFloat = 44
    let action: () -> Void

    @State private var repeatTask: Task<Void, Never>?
    @State private var pressed = false

    var body: some View {
        LGStepCircle(systemName: systemName, diameter: diameter, dimmed: !enabled)
            .scaleEffect(pressed ? 0.92 : 1)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in if !pressed { begin() } }
                    .onEnded { _ in stop() }
            )
            .onChange(of: enabled) { _, now in if !now { stop() } }
            .onDisappear { stop() }
            .accessibilityElement()
            .accessibilityLabel(label)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { if enabled { action() } }
    }

    private func begin() {
        pressed = true
        guard enabled else { return }
        action()
        repeatTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            var interval = 160.0
            while !Task.isCancelled {
                action()
                try? await Task.sleep(for: .milliseconds(Int(interval)))
                interval = max(40, interval * 0.9)
            }
        }
    }

    private func stop() {
        pressed = false
        repeatTask?.cancel()
        repeatTask = nil
    }
}
