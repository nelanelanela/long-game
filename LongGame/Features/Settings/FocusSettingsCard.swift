import SwiftUI
#if canImport(FamilyControls)
import FamilyControls
#endif

/// Settings card for the "Practising" Focus: which Shortcuts to run and which apps to mute during a session.
struct FocusSettingsCard: View {
    @State private var focus = FocusMode.shared
    @State private var choosingApps = false
    #if canImport(FamilyControls)
    @State private var draft = FamilyActivitySelection()
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Toggle("Practising Focus", isOn: Binding(get: { focus.settings.switchFocus }, set: { focus.setSwitchFocus($0) }))
                .lgText(.row).tint(LGColor.ink).frame(minHeight: 54)
            Text("When you start a session, Long Game runs a Shortcut of yours that turns on your Practising Focus, and another when you finish. iOS only lets Shortcuts switch a Focus on.")
                .lgText(.caption, color: LGColor.inkMuted)
                .padding(.bottom, 10)
            if focus.settings.switchFocus {
                Divider().overlay(LGColor.divider)
                shortcutField("Start Shortcut", text: Binding(get: { focus.settings.startShortcut }, set: { focus.setStartShortcut($0) }))
                Divider().overlay(LGColor.divider)
                shortcutField("Finish Shortcut", text: Binding(get: { focus.settings.stopShortcut }, set: { focus.setStopShortcut($0) }))
                Text("In the Shortcuts app, make two shortcuts with the “Set Focus” action: one turning Practising on, one turning it off. Use the names above.")
                    .lgText(.caption, color: LGColor.inkMuted)
                    .padding(.vertical, 10)
            }
            #if canImport(FamilyControls)
            Divider().overlay(LGColor.divider)
            Toggle("Mute chosen apps", isOn: Binding(
                get: { focus.settings.muteApps },
                set: { on in Task { await focus.setMuteApps(on) } }))
                .lgText(.row).tint(LGColor.ink).frame(minHeight: 54)
            Text("Chosen apps are blocked with Screen Time until you finish the session.")
                .lgText(.caption, color: LGColor.inkMuted)
                .padding(.bottom, 10)
            if let problem = focus.permissionProblem {
                Text(problem).lgText(.caption, color: LGColor.danger).padding(.bottom, 10)
            }
            if focus.settings.muteApps {
                Divider().overlay(LGColor.divider)
                Button {
                    draft = focus.selection
                    choosingApps = true
                } label: {
                    HStack {
                        Text("Choose apps").lgText(.row)
                        Spacer()
                        Text(focus.chosenSummary).lgText(.row, color: LGColor.inkMuted)
                        Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(LGColor.inkMuted)
                    }
                    .frame(minHeight: 54)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the list of apps to mute during a session")
                .familyActivityPicker(isPresented: $choosingApps, selection: $draft)
                .onChange(of: choosingApps) { _, showing in
                    if !showing { focus.setSelection(draft) }
                }
            }
            #endif
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lgCard()
    }

    private func shortcutField(_ title: String, text: Binding<String>) -> some View {
        HStack {
            Text(title).lgText(.row)
            Spacer()
            TextField(title, text: text)
                .multilineTextAlignment(.trailing)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .foregroundStyle(LGColor.inkMuted)
        }
        .frame(minHeight: 54)
    }
}
