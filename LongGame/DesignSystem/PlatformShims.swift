import SwiftUI

// iPhone-only SwiftUI modifiers, given harmless Mac versions so the shared screens compile for both.
#if os(macOS)
extension View {
    /// The Mac has no full-screen covers; a big sheet, about the size of the window, is the nearest thing. (A sheet
    /// keeps `dismiss` working for the screens inside, the Timer included.)
    func fullScreenCover<Content: View>(isPresented: Binding<Bool>, onDismiss: (() -> Void)? = nil,
                                        @ViewBuilder content: @escaping () -> Content) -> some View {
        sheet(isPresented: isPresented, onDismiss: onDismiss) { content().lgWindowSizedSheet() }
    }

    func fullScreenCover<Item: Identifiable, Content: View>(item: Binding<Item?>, onDismiss: (() -> Void)? = nil,
                                                            @ViewBuilder content: @escaping (Item) -> Content) -> some View {
        sheet(item: item, onDismiss: onDismiss) { content($0).lgWindowSizedSheet() }
    }

    func lgWindowSizedSheet() -> some View {
        frame(minWidth: 820, idealWidth: 1100, maxWidth: .infinity, minHeight: 540, idealHeight: 690, maxHeight: .infinity)
    }

    func textInputAutocapitalization(_ style: MacAutocapitalization?) -> some View { self }
    func keyboardType(_ type: MacKeyboardType) -> some View { self }
}

struct MacAutocapitalization { static let words = MacAutocapitalization() }
struct MacKeyboardType { static let decimalPad = MacKeyboardType(); static let numberPad = MacKeyboardType() }
#endif

extension View {
    /// Hides the system navigation bar (every screen draws its own title). The Mac has no such bar to hide.
    @ViewBuilder
    func lgHidesNavigationBar() -> some View {
        #if os(iOS)
        toolbar(.hidden, for: .navigationBar)
        #else
        self
        #endif
    }
}
