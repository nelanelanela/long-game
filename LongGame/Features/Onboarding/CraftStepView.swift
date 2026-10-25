import SwiftUI

struct CraftStepView: View {
    @Bindable var model: OnboardingModel
    let onContinue: () -> Void

    @FocusState private var focused: Bool

    private var matchedCraft: String? { CraftCatalog.match(model.craftName)?.craft }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            OnboardingHeader(step: 1, showsBack: false)

            VStack(alignment: .leading, spacing: 8) {
                Text("What is your craft?").lgText(.screenTitle)
                    .accessibilityAddTraits(.isHeader)
                Text("Pick one, or type your own.").lgText(.body, color: LGColor.inkMuted)
            }

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(LGColor.inkMuted)
                    .accessibilityHidden(true)
                TextField("Your craft", text: $model.craftName)
                    .lgText(.bodyLarge)
                    .focused($focused)
                    .submitLabel(.done)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .onChange(of: model.craftName) { _, new in
                        if let hit = CraftCatalog.match(new) { model.category = hit.group }
                        else { model.category = CraftCatalog.customCategory }
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
            .frame(minHeight: 52)
            .lgCard(radius: 14)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    let groups = CraftCatalog.filtered(model.craftName == matchedCraft ? "" : model.craftName)
                    ForEach(groups) { group in
                        VStack(alignment: .leading, spacing: 10) {
                            LGSectionLabel(group.name)
                            FlowLayout(spacing: 8) {
                                ForEach(group.crafts, id: \.self) { craft in
                                    LGPill(title: craft, selected: craft == matchedCraft) {
                                        model.craftName = craft
                                        model.category = group.name
                                        focused = false
                                    }
                                }
                            }
                        }
                    }
                    if groups.isEmpty && CraftCatalog.isValidName(model.craftName) {
                        Text("“\(model.craftName.trimmingCharacters(in: .whitespaces))” will be your craft.")
                            .lgText(.row, color: LGColor.inkMuted)
                    }
                }
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDismissesKeyboard(.interactively)

            Button("Continue") {
                focused = false
                onContinue()
            }
            .buttonStyle(.lg(.primary))
            .disabled(!CraftCatalog.isValidName(model.craftName))
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .overlay(alignment: .topTrailing) {
            SunView(face: .happy).frame(width: 96, height: 96)
                .offset(x: 18, y: 8)
                .allowsHitTesting(false)
        }
        .lgScreen()
    }
}
