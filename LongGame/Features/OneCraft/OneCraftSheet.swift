import SwiftUI
import SwiftData

struct OneCraftSheet: View {
    let craft: Craft
    let totalHours: Int

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(TimerStore.self) private var timer
    @State private var confirmReplace = false

    var body: some View {
        VStack(spacing: 20) {
            SunView(face: .happy).frame(width: 104, height: 104)
            VStack(spacing: 10) {
                Text("One craft at a time").lgText(.sheetTitle)
                    .accessibilityAddTraits(.isHeader)
                Text("Splitting your hours across several crafts slows every one of them down, so Long Game keeps you focused on one.")
                    .lgText(LGTextStyle(size: 15, weight: .regular, relativeTo: .subheadline), color: LGColor.inkMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(spacing: 4) {
                Button("Keep my focus") { dismiss() }.buttonStyle(.lg(.primary))
                Button("Replace my craft") { confirmReplace = true }.buttonStyle(.lg(.text))
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .presentationDetents([.height(440), .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(32)
        .alert("Replace \(craft.name)?", isPresented: $confirmReplace) {
            Button("Cancel", role: .cancel) {}
            Button("Archive and replace", role: .destructive, action: replace)
        } message: {
            Text("Your \(totalHours.formatted()) hours of \(craft.name) will be archived. This can't be undone.")
        }
    }

    private func replace() {
        timer.clear()
        craft.archivedAt = Date()
        try? context.save()
        dismiss()
    }
}
