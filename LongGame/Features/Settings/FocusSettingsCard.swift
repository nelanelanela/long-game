import SwiftUI

/// Settings card for the "Practising" Focus: which Shortcuts to run when a session starts and finishes.
struct FocusSettingsCard: View {
    @State private var focus = FocusMode.shared

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
