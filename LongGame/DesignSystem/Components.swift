import SwiftUI

// MARK: Card

struct LGCardModifier: ViewModifier {
    var radius: CGFloat = 20
    func body(content: Content) -> some View {
        content
            .background(LGColor.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .shadow(color: LGColor.ink.opacity(0.04), radius: 1, y: 1)
            .shadow(color: LGColor.ink.opacity(0.05), radius: 10, y: 6)
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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(LGColor.ink)
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
