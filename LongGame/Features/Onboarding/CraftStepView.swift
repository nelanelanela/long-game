import SwiftUI

struct CraftStepView: View {
    @Bindable var model: OnboardingModel
    var onBack: (() -> Void)?
    let onContinue: () -> Void

    @FocusState private var focused: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var choice: CraftSuggestions.Choice { CraftSuggestions.choice(model.craftName) }

    var body: some View {
        let choice = choice
        VStack(alignment: .leading, spacing: 0) {
            OnboardingHeader(step: 1, showsBack: onBack != nil, onBack: onBack)

            Text("What’s your game?").lgText(.setupTitle)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, 18)

            field.padding(.top, 14)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let own = choice.own {
                        group(name: CraftSuggestions.customCategory) { ownChip(own) }
                    }
                    ForEach(choice.groups) { group in
                        self.group(name: group.name) {
                            ForEach(group.crafts, id: \.self) { craft in chip(craft, in: group, selected: craft == choice.matched) }
                        }
                    }
                    if choice.showsNoMatchLine {
                        Text("Not on the list? It’s your game, call it anything.")
                            .lgText(.note, color: LGColor.inkMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.top, 14)
                // Room at the end so the last chips scroll fully clear of the fade.
                .padding(.bottom, 52)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDismissesKeyboard(.interactively)
            .overlay(alignment: .bottom) {
                // A soft fade so it is clear the list scrolls.
                LinearGradient(colors: [LGColor.background.opacity(0), LGColor.background],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 48)
                    .allowsHitTesting(false)
            }

            Button(CraftSuggestions.playTitle(model.craftName) ?? String(localized: "Continue"), action: play)
                .buttonStyle(.lg(.primary))
                .disabled(!CraftSuggestions.isValidName(model.craftName))
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
                    if let hit = CraftSuggestions.match(new) { model.category = hit.group }
                    else { model.category = CraftSuggestions.customCategory }
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
        guard CraftSuggestions.isValidName(model.craftName) else { return }
        if let hit = CraftSuggestions.match(model.craftName) { model.craftName = hit.craft }
        else { model.craftName = model.craftName.trimmingCharacters(in: .whitespacesAndNewlines) }
        focused = false
        onContinue()
    }

    private func group<Content: View>(name: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: name == CraftSuggestions.customCategory ? String(localized: "Your own") : name)
                .lgText(LGTextStyle(size: 12, weight: .semibold, relativeTo: .caption), color: LGColor.inkMuted)
                .accessibilityAddTraits(.isHeader)
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 6) { content() }
            } else {
                FlowLayout(spacing: 6) { content() }
            }
        }
    }

    /// The typed text as a chip, already selected: "+ Calligraphy".
    private func ownChip(_ name: String) -> some View {
        label(Text("+ ") + Text(verbatim: name), selected: true)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Your own: \(name)"))
            .accessibilityAddTraits(.isSelected)
    }

    /// Tapping selects the chip and fills the field (instead of the typed text); tapping it again clears both.
    private func chip(_ craft: String, in group: CraftGroup, selected: Bool) -> some View {
        Button {
            if selected {
                model.craftName = ""
            } else {
                model.craftName = craft
                model.category = group.name
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

#Preview("Craft · nothing selected") {
    CraftStepView(model: OnboardingModel(), onContinue: {})
}

#Preview("Craft · Piano selected") {
    let m = OnboardingModel(); m.craftName = "Piano"; m.category = "Music"
    return CraftStepView(model: m, onContinue: {})
}

#Preview("Craft · searching “pa”") {
    let m = OnboardingModel(); m.craftName = "pa"
    return CraftStepView(model: m, onContinue: {})
}

#Preview("Craft · “Calligraphy”") {
    let m = OnboardingModel(); m.craftName = "Calligraphy"
    return CraftStepView(model: m, onContinue: {})
}

#Preview("Craft · dark") {
    let m = OnboardingModel(); m.craftName = "pa"
    return CraftStepView(model: m, onContinue: {}).preferredColorScheme(.dark)
}

#Preview("Craft · AX5") {
    CraftStepView(model: OnboardingModel(), onContinue: {})
        .environment(\.dynamicTypeSize, .accessibility5)
}
