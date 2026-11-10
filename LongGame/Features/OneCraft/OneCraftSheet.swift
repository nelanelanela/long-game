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
        VStack(spacing: 0) {
            // The day scene, edge to edge under the grabber.
            SceneHero(tone: .day, height: 195, skyHeight: 150, horizon: 0.8, landTop: 75, sunSize: 110, sunTop: 14, hidden: true)
                .padding(.top, 6)
            VStack(spacing: 10) {
                Text("One craft at a time")
                    .lgText(LGTextStyle(size: 26, weight: .bold, relativeTo: .title, tracking: -0.52))
                    .accessibilityAddTraits(.isHeader)
                Text("Long Game follows one craft, so every hour lifts the same sun. You can switch, but your hours stay with \(craft.name).")
                    .lgText(LGTextStyle(size: 15, weight: .regular, relativeTo: .subheadline), color: LGColor.inkMuted)
                    .lineSpacing(4)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)
            .padding(.top, 10)
            Spacer(minLength: 16)
            VStack(spacing: 2) {
                Button("Keep playing") { dismiss() }.buttonStyle(.lg(.primary))
                Button { confirmReplace = true } label: {
                    Text("Switch to a new game").lgText(.rowStrong, color: LGColor.ember)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(LGColor.background)
        .presentationDetents([.height(500), .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(30)
        .alert("Replace \(craft.name)?", isPresented: $confirmReplace) {
            Button("Cancel", role: .cancel) {}
            Button("Archive and replace", role: .destructive, action: replace)
        } message: {
            Text("Your \(Labels.hours(totalHours)) of \(craft.name) will be archived. This can't be undone.")
        }
    }

    private func replace() {
        timer.clear()
        craft.archivedAt = Date()
        try? context.save()
        // The new craft starts at zero, so the icon goes back to the start (the new craft's own stage is set later).
        if let settings = (try? context.fetch(FetchDescriptor<AppSettings>()))?.first {
            AppIconManager.apply(.start, settings: settings, context: context, timerRunning: false)
        }
        dismiss()
    }
}
