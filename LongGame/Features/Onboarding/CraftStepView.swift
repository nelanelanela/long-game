import SwiftUI

struct CraftStepView: View {
    @Bindable var model: OnboardingModel
    var onBack: (() -> Void)?
    let onContinue: () -> Void

    @FocusState private var focused: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var matchedCraft: String? { CraftSuggestions.match(model.craftName)?.craft }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingHeader(step: 1, showsBack: onBack != nil, onBack: onBack)

            Text("What’s your game?").lgText(.setupTitle)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, 18)

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .lgIcon(16, weight: .medium)
                    .foregroundStyle(LGColor.inkMuted)
                    .accessibilityHidden(true)
                TextField("Search or type your own", text: $model.craftName)
                    .lgText(.bodyLarge)
                    .focused($focused)
                    .submitLabel(.done)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .onChange(of: model.craftName) { _, new in
                        if let hit = CraftSuggestions.match(new) { model.category = hit.group }
                        else { model.category = CraftSuggestions.customCategory }
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
            .padding(.top, 14)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    let groups = CraftSuggestions.filtered(model.craftName == matchedCraft ? "" : model.craftName)
                    ForEach(groups) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(group.name)
                                .lgText(LGTextStyle(size: 12, weight: .semibold, relativeTo: .caption), color: LGColor.inkMuted)
                                .accessibilityAddTraits(.isHeader)
                            if dynamicTypeSize.isAccessibilitySize {
                                VStack(alignment: .leading, spacing: 6) {
                                    ForEach(group.crafts, id: \.self) { craft in chip(craft, in: group) }
                                }
                            } else {
                                FlowLayout(spacing: 6) {
                                    ForEach(group.crafts, id: \.self) { craft in chip(craft, in: group) }
                                }
                            }
                        }
                    }
                    if groups.isEmpty && CraftSuggestions.isValidName(model.craftName) {
                        Text("“\(model.craftName.trimmingCharacters(in: .whitespaces))” will be your craft.")
                            .lgText(.row, color: LGColor.inkMuted)
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

            Button("Continue") {
                focused = false
                onContinue()
            }
            .buttonStyle(.lg(.primary))
            .disabled(!CraftSuggestions.isValidName(model.craftName))
            .padding(.top, 14)
            LGBrandLine().padding(.top, 12)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 10)
        .lgScreen()
    }

    /// Tapping selects the chip and fills the search field; tapping it again clears both.
    private func chip(_ craft: String, in group: CraftGroup) -> some View {
        let selected = craft == matchedCraft
        return Button {
            if selected {
                model.craftName = ""
            } else {
                model.craftName = craft
                model.category = group.name
                focused = false
            }
        } label: {
            Text(verbatim: craft)
                .lgText(LGTextStyle(size: 14, weight: selected ? .semibold : .medium, relativeTo: .subheadline),
                        color: selected ? Color.white : LGColor.ink)
                .padding(.horizontal, 13)
                .padding(.vertical, 8)
                .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil, alignment: .leading)
                .background(selected ? LGColor.ink : LGColor.surface, in: Capsule())
                .shadow(color: LGColor.ink.opacity(selected ? 0.2 : 0), radius: 6, y: 4)
                // The pills are 6 pt apart as on the board; the touch area reaches into the gaps.
                .contentShape(Rectangle().inset(by: -3))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
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

#Preview("Craft · AX5") {
    CraftStepView(model: OnboardingModel(), onContinue: {})
        .environment(\.dynamicTypeSize, .accessibility5)
}
