import SwiftUI

/// The sun remembers (`design/redesign/SunRemembers.dc.html`): one quiet card under Today's number. Peach, radius 14,
/// the opening words in ember bold, an optional 40 pt photo on the left and a small chevron. A tap opens that day in
/// History, or the photo. No sound, haptic or notification.
struct MemoryCard: View {
    let memory: Memory
    /// The photo of a photo's anniversary.
    var photo: (id: UUID, data: Data)?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                if let photo {
                    PhotoThumb(id: photo.id, data: photo.data, side: 40, radius: 8)
                        .accessibilityHidden(true)
                }
                (Text(verbatim: memory.parts.lead).fontWeight(.bold).foregroundColor(LGColor.ember)
                 + Text(verbatim: " " + memory.parts.rest).foregroundColor(LGColor.ink))
                    .lgText(LGTextStyle(size: 13, weight: .regular, relativeTo: .footnote))
                    .lineSpacing(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .lgIcon(12, weight: .semibold)
                    .foregroundStyle(LGColor.ember)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .frame(minHeight: 44)
            .background(LGColor.anniversaryPill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: memory.text))
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(photo != nil ? Text("Opens the photo") : Text("Opens that day in History"))
    }
}

#Preview("A year ago today") {
    MemoryCard(memory: .yearAgo(years: 1, seconds: 1_200, today: 3_900, day: .now)) {}
        .padding(16)
        .background(LGColor.background)
}
