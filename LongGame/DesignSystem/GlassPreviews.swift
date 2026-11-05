import SwiftUI

#if DEBUG
/// Every control style, on a warm light background and over the Timer's night sky. On an iOS 26 simulator each
/// preview shows the glass look; the "flat" one beside it forces the iOS 17-25 look, so the two can be compared.
private struct ControlGallery: View {
    var dark = false

    var body: some View {
        VStack(spacing: 14) {
            LGSegmentedControl(items: ["Today", "This week", "The long game"], selection: "This week",
                               label: "Home view", title: { LocalizedStringKey($0) }, onSelect: { _ in })
            HStack(spacing: 8) {
                LGIconButton(systemName: "calendar", label: "History", tint: dark ? .white : LGColor.ink) {}
                LGIconButton(systemName: "plus", label: "Add", tint: dark ? .white : LGColor.ink) {}
                LGIconButton(systemName: "gearshape", label: "Settings", tint: dark ? .white : LGColor.ink) {}
            }
            if dark {
                HStack(spacing: 10) {
                    Button("Pause") {}.buttonStyle(.lg(.translucent))
                    Button("Finish") {}.buttonStyle(.lg(.light))
                }
            } else {
                Button("Start session") {}.buttonStyle(.lg(.primary))
                Button("Add past hours") {}.buttonStyle(.lg(.quiet))
                Button("Save") {}.buttonStyle(.lg(.primary)).disabled(true)
            }
        }
        .padding(24)
        .frame(width: 390)
        .background {
            if dark {
                LinearGradient(colors: [Color(hex: 0x16244A), Color(hex: 0x3A2F6B)], startPoint: .top, endPoint: .bottom)
            } else {
                LGColor.background
            }
        }
        .lgWarmScreen()
    }
}

#Preview("Glass · light") {
    HStack(alignment: .top, spacing: 0) {
        ControlGallery()
        ControlGallery().environment(\.lgFlat, true)
    }
}

#Preview("Glass · over the night sky") {
    HStack(alignment: .top, spacing: 0) {
        ControlGallery(dark: true)
        ControlGallery(dark: true).environment(\.lgFlat, true)
    }
}
#endif
