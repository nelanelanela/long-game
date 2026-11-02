import SwiftUI

// MARK: Card

struct LGCardModifier: ViewModifier {
    var radius: CGFloat = 20
    func body(content: Content) -> some View {
        content
            .background(LGColor.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

extension View {
    func lgCard(radius: CGFloat = 20) -> some View { modifier(LGCardModifier(radius: radius)) }

    /// The warm-white screen background.
    func lgScreen() -> some View {
        background(LGColor.background.ignoresSafeArea())
    }
}

// MARK: Buttons

struct LGButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, light, translucent, text }
    var kind: Kind = .primary
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let label = configuration.label
            .lgText(kind == .text ? .rowStrong : .button, color: foreground)
            .frame(maxWidth: .infinity)
            .frame(minHeight: kind == .text ? 48 : 56)
        Group {
            switch kind {
            case .text:
                label
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
        case .translucent: .white.opacity(0.12)
        default: .clear
        }
    }
}

extension ButtonStyle where Self == LGButtonStyle {
    static func lg(_ kind: LGButtonStyle.Kind = .primary) -> LGButtonStyle { LGButtonStyle(kind: kind) }
}

/// Round icon buttons: back, close, calendar, plus (44 pt touch target).
struct LGIconButton: View {
    let systemName: String
    let label: String
    var tint: Color = LGColor.ink
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(label)
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
                RoundedRectangle(cornerRadius: 2)
                    .fill(i <= step ? LGColor.ink : LGColor.chipBorder)
                    .frame(width: 24, height: 4)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(step) of \(of)")
    }
}

// MARK: Segmented control

/// Two or more segments on a warm track with a white pill under the chosen one: Home's This week | The long game.
struct LGSegmentedControl<Item: Hashable>: View {
    let items: [Item]
    let selection: Item
    /// What VoiceOver calls the group.
    let label: LocalizedStringKey
    let title: (Item) -> LocalizedStringKey
    let onSelect: (Item) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.self) { item in
                let selected = item == selection
                Button { onSelect(item) } label: {
                    Text(title(item))
                        .lgText(LGTextStyle(size: 14, weight: selected ? .semibold : .medium, relativeTo: .subheadline))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, minHeight: 36)
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
        .background(LGColor.segmentTrack, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
    }
}

// MARK: Hold-to-repeat step button

/// A round − or + button. One tap steps once; keeping a finger on it keeps stepping, faster the longer it is held,
/// until the finger lifts or the button becomes disabled (the value hit its limit).
struct LGRepeatButton: View {
    let systemName: String
    let label: String
    let enabled: Bool
    let action: () -> Void

    @State private var repeatTask: Task<Void, Never>?
    @State private var pressed = false

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(LGColor.ink)
            .frame(width: 52, height: 52)
            .background(LGColor.chipFill, in: Circle())
            .scaleEffect(pressed ? 0.92 : 1)
            .contentShape(Circle())
            .opacity(enabled ? 1 : 0.4)
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
