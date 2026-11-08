import SwiftUI

struct CraftStepView: View {
    @Bindable var model: OnboardingModel
    let onContinue: () -> Void

    @FocusState private var focused: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var matchedCraft: String? { CraftSuggestions.match(model.craftName)?.craft }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            OnboardingHeader(step: 1, showsBack: false)

            Text("What's your game?").lgText(.screenTitle)
                .accessibilityAddTraits(.isHeader)

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
            .padding(.horizontal, 16)
            .frame(minHeight: 48)
            .lgCard(radius: 14)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    let groups = CraftSuggestions.filtered(model.craftName == matchedCraft ? "" : model.craftName)
                    ForEach(groups) { group in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(group.name)
                                .font(.system(.caption, weight: .semibold))
                                .foregroundStyle(Color(hex: 0x8A93AB))
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
                .padding(.top, 4)
                // Room at the end so the last chips scroll fully clear of the fade.
                .padding(.bottom, 44)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDismissesKeyboard(.interactively)
            .overlay(alignment: .bottom) {
                // A soft fade so it is clear the list scrolls.
                LinearGradient(colors: [LGColor.background.opacity(0), LGColor.background],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 32)
                    .allowsHitTesting(false)
            }

            Button("Continue") {
                focused = false
                onContinue()
            }
            .buttonStyle(.lg(.primary))
            .disabled(!CraftSuggestions.isValidName(model.craftName))
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .overlay(alignment: .topTrailing) {
            SunView(idle: false, face: .happy).frame(width: 96, height: 96)
                .offset(x: 18, y: 8)
                .allowsHitTesting(false)
        }
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
                .font(.system(.subheadline, weight: .medium))
                .foregroundStyle(selected ? Color.white : LGColor.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil, alignment: .leading)
                .background(selected ? LGColor.ink : LGColor.surface, in: Capsule())
                .frame(minHeight: 44)
                .contentShape(Rectangle())
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
