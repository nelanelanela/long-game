import SwiftUI

/// A scrolling sheet of every design-system piece. Shown on launch until the
/// real screens exist (and handy later for checking colours and the sun).
struct DesignGallery: View {
    @State private var face: SunFace = .happy
    private let faces: [(String, SunFace)] = [("Happy", .happy), ("Focus", .focus), ("Wink", .wink), ("Sleepy", .sleepy), ("Celebrate", .celebrate)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Design system").lgText(.screenTitle)

                VStack(alignment: .leading, spacing: 12) {
                    LGSectionLabel("Sun")
                    SunView(face: face).frame(height: 180).frame(maxWidth: .infinity)
                    HStack(spacing: 8) {
                        ForEach(faces, id: \.0) { name, f in
                            LGPill(title: name, selected: face == f) { face = f }
                        }
                    }
                    .scrollableRow()
                    SunView(face: .focus, litRays: 8, glowingRay: 8, unlitOpacity: 0.22, rayColor: LGColor.sunRaysBright)
                        .frame(height: 120).frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(LGColor.ink, in: RoundedRectangle(cornerRadius: 20))
                }

                VStack(alignment: .leading, spacing: 12) {
                    LGSectionLabel("Card and type")
                    VStack(spacing: 4) {
                        Text("3,294").lgNumber(.bigNumber)
                        Text("of 10,000 hours · 33%").lgText(.row, color: LGColor.inkMuted)
                    }
                    .frame(maxWidth: .infinity).padding(24).lgCard(radius: 24)
                }

                VStack(spacing: 10) {
                    Button("Start session") {}.buttonStyle(.lg(.primary))
                    Button("Add past hours") {}.buttonStyle(.lg(.secondary))
                    Button("Disabled") {}.buttonStyle(.lg(.primary)).disabled(true)
                    Button("Replace my craft") {}.buttonStyle(.lg(.text))
                }

                VStack(alignment: .leading, spacing: 10) {
                    LGSectionLabel("Calendar colours")
                    HStack(spacing: 6) {
                        ForEach(CalendarLevel.allCases, id: \.self) { level in
                            RoundedRectangle(cornerRadius: 4).fill(LGColor.calendar(level)).frame(width: 28, height: 28)
                        }
                    }
                }
            }
            .padding(24)
        }
        .lgScreen()
    }
}

private extension View {
    func scrollableRow() -> some View {
        ScrollView(.horizontal, showsIndicators: false) { self }
    }
}

#Preview { DesignGallery() }
