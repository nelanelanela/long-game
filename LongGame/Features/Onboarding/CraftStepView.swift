import SwiftUI

struct CraftStepView: View {
    @Bindable var model: OnboardingModel
    var onBack: (() -> Void)?
    let onContinue: () -> Void

    @FocusState private var focused: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let choice = model.craftChoice
        VStack(alignment: .leading, spacing: 0) {
            OnboardingHeader(step: 1, showsBack: onBack != nil, onBack: onBack)

            Text("What’s your game?").lgText(.setupTitle)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, 18)

            field.padding(.top, 14)

            // Update 54: every group and every choice is always shown; the typed name is added on top, never
            // filtered down. The top stays in view when the own chip appears.
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if let own = choice.own {
                            VStack(alignment: .leading, spacing: 8) {
                                groupLabel(String(localized: "Your own"))
                                ownChip(own, selected: choice.ownSelected)
                                Text("Not on the list? It’s your game, call it anything.")
                                    .lgText(.caption, color: LGColor.inkMuted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        ForEach(choice.groups) { group in
                            VStack(alignment: .leading, spacing: 8) {
                                groupLabel(group.name)
                                chips {
                                    ForEach(group.crafts, id: \.self) { craft in chip(craft, selected: craft == choice.selectedChoice) }
                                }
                            }
                        }
                    }
                    .padding(.top, 14)
                    .id("top")
                    // Room at the end so the last chips scroll fully clear of the fade.
                    .padding(.bottom, 52)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: choice.own != nil) { _, shown in
                    if shown { proxy.scrollTo("top", anchor: .top) }
                }
            }
            .overlay(alignment: .bottom) {
                // A soft fade so it is clear the list scrolls.
                LinearGradient(colors: [LGColor.background.opacity(0), LGColor.background],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 48)
                    .allowsHitTesting(false)
            }

            Button(CraftSuggestions.playTitle(choice.selected) ?? String(localized: "Continue"), action: play)
                .buttonStyle(.lg(.primary))
                .disabled(choice.selected == nil)
                .padding(.top, 14)
            LGBrandLine().padding(.top, 12)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 10)
        .lgScreen()
    }

    /// Typing is a real way to answer, not only a search: a pencil, a navy ring while there is text, and ✕ to clear.
    private var field: some View {
        HStack(spacing: 10) {
            Image(systemName: "pencil")
                .lgIcon(16, weight: .medium)
                .foregroundStyle(LGColor.inkMuted)
                .accessibilityHidden(true)
            TextField("Type any craft, or pick one below", text: $model.craftName)
                .lgText(.body)
                .focused($focused)
                .submitLabel(.done)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .onSubmit(play)
                .onChange(of: model.craftName) { _, new in
                    if new.count > 40 { model.craftName = String(new.prefix(40)) }
                }
            if !model.craftName.isEmpty {
                Button { model.craftName = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(LGColor.inkMuted)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Clear")
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 48)
        .lgCard(radius: 14)
        .overlay {
            if !model.craftName.isEmpty {
                RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(LGColor.selectedFill, lineWidth: 1.5)
            }
        }
    }

    /// Return on the keyboard does the same as the button.
    private func play() {
        guard model.chosenCraft != nil else { return }
        focused = false
        onContinue()
    }

    private func groupLabel(_ name: String) -> some View {
        Text(verbatim: name)
            .lgText(LGTextStyle(size: 12, weight: .semibold, relativeTo: .caption), color: LGColor.inkMuted)
            .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private func chips<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 6) { content() }
        } else {
            FlowLayout(spacing: 6) { content() }
        }
    }

    /// The typed name as a chip, "+ Calligraphy": selected until a choice is tapped; tapping it selects it back.
    private func ownChip(_ name: String, selected: Bool) -> some View {
        Button { model.pickedCraft = nil } label: {
            label(Text(verbatim: "+  " + name), selected: selected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Your own: \(name)"))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    /// Tapping a choice selects it instead of the typed name; the field keeps what was typed. With nothing typed,
    /// the choice fills the field as before. Tapping the selected choice again lets it go.
    private func chip(_ craft: String, selected: Bool) -> some View {
        Button {
            if selected {
                if model.pickedCraft == craft { model.pickedCraft = nil } else { model.craftName = "" }
            } else if model.craftName.trimmingCharacters(in: .whitespaces).count >= 2 {
                model.pickedCraft = craft
                focused = false
            } else {
                model.craftName = craft
                focused = false
            }
        } label: {
            label(Text(verbatim: craft), selected: selected)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func label(_ text: Text, selected: Bool) -> some View {
        text
            .lgText(LGTextStyle(size: 14, weight: selected ? .semibold : .medium, relativeTo: .subheadline),
                    color: selected ? LGColor.selectedLabel : LGColor.ink)
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil, alignment: .leading)
            .background(selected ? LGColor.selectedFill : LGColor.surface, in: Capsule())
            .shadow(color: LGColor.navy.opacity(selected ? 0.2 : 0), radius: 6, y: 4)
            // The pills are 6 pt apart as on the board; the touch area reaches into the gaps.
            .contentShape(Rectangle().inset(by: -3))
    }
}

#Preview("Craft · empty") {
    CraftStepView(model: OnboardingModel(), onContinue: {})
}

#Preview("Craft · “pa”") {
    let m = OnboardingModel(); m.craftName = "pa"
    return CraftStepView(model: m, onContinue: {})
}

#Preview("Craft · “Calligraphy”") {
    let m = OnboardingModel(); m.craftName = "Calligraphy"
    return CraftStepView(model: m, onContinue: {})
}

#Preview("Craft · “piano”") {
    let m = OnboardingModel(); m.craftName = "piano"
    return CraftStepView(model: m, onContinue: {})
}

#Preview("Craft · “Calligraphy”, dark") {
    let m = OnboardingModel(); m.craftName = "Calligraphy"
    return CraftStepView(model: m, onContinue: {}).preferredColorScheme(.dark)
}

#Preview("Craft · AX5") {
    let m = OnboardingModel(); m.craftName = "Calligraphy"
    return CraftStepView(model: m, onContinue: {}).environment(\.dynamicTypeSize, .accessibility5)
}
