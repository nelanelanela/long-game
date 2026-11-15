import SwiftUI
import SwiftData

// A letter to your future self (update 49, `design/redesign/LetterToFutureSelf.dc.html`).

/// The lined paper of a letter: warm white, radius 6, faint navy rules.
struct LetterPaper<Content: View>: View {
    var tilt: Double = 0
    @ViewBuilder var content: Content
    /// The letter's text size (15 pt, growing with Dynamic Type): the rules follow it, so they sit under the words.
    @ScaledMetric(relativeTo: .body) private var fontSize: CGFloat = 15

    var body: some View {
        content
            .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 14)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(LGColor.letterPaper)
                    .overlay {
                        Canvas { context, size in
                            // Just under each line's descenders: 16 pt padding, then one line (the font's own
                            // height plus the letter's line spacing) after another.
                            let step = LetterLines.lineHeight(fontSize)
                            var y: CGFloat = 16 + fontSize * 1.23
                            while y < size.height - 6 {
                                context.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)),
                                             with: .color(LGColor.paperRule))
                                y += step
                            }
                        }
                        .accessibilityHidden(true)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .shadow(color: LGColor.navy.opacity(0.1), radius: 9, y: 6)
            }
            .rotationEffect(.degrees(tilt))
    }
}

/// The letter's line spacing, matched to the paper's rules (22.4 pt lines at 15 pt, as on the board).
struct LetterLines: ViewModifier {
    @ScaledMetric(relativeTo: .body) private var fontSize: CGFloat = 15

    static func spacing(_ fontSize: CGFloat) -> CGFloat { fontSize * 0.3 }
    static func lineHeight(_ fontSize: CGFloat) -> CGFloat { fontSize * 1.193 + spacing(fontSize) }

    func body(content: Content) -> some View {
        content.lineSpacing(Self.spacing(fontSize))
    }
}

/// The sealed envelope: warm paper, tilted −3°, an amber seal carrying the sun. Decorative.
struct SealedEnvelope: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(LGColor.letterPaper)
                .shadow(color: LGColor.navy.opacity(0.16), radius: 15, y: 14)
            // The flap.
            Path { p in
                p.move(to: CGPoint(x: 0, y: 0))
                p.addLine(to: CGPoint(x: 110, y: 84))
                p.addLine(to: CGPoint(x: 220, y: 0))
            }
            .stroke(LGColor.paperRule, lineWidth: 1.5)
            Circle()
                .fill(LGColor.amber)
                .frame(width: 56, height: 56)
                .overlay(Circle().inset(by: 2).stroke(.white.opacity(0.18), lineWidth: 4))
                .shadow(color: LGColor.ember.opacity(0.4), radius: 4, y: 3)
                .overlay { SunView(idle: false, face: .happy).frame(width: 34, height: 34) }
                .offset(y: 9)
        }
        .frame(width: 220, height: 150)
        .rotationEffect(.degrees(-3))
        .accessibilityHidden(true)
    }
}

/// Writing a letter, then the sealed envelope. A sheet. Leaving with text asks first.
struct LetterWriteSheet: View {
    let craft: Craft
    let milestone: Int
    let total: Double
    let weeklyHours: Double?
    /// Rewrite: the letter this one replaces, only once the new one is sealed.
    var replacing: Letter?
    /// Started from the end of setup: the total there is what was just entered.
    var onDone: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var text = ""
    @State private var sealed = false
    @State private var confirmLeave = false
    @FocusState private var focused: Bool

    var body: some View {
        Group {
            if sealed { sealedPage } else { writePage }
        }
        .background(alignment: .top) {
            LinearGradient(colors: [LGColor.anniversaryPill, LGColor.background], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.4))
                .ignoresSafeArea()
        }
        .background(LGColor.background.ignoresSafeArea())
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(30)
        .interactiveDismissDisabled(!sealed && !text.isEmpty)
        .confirmationDialog("Throw this letter away?", isPresented: $confirmLeave, titleVisibility: .visible) {
            Button("Throw away", role: .destructive) { close() }
            Button("Keep writing", role: .cancel) {}
        }
    }

    private var writePage: some View {
        VStack(spacing: 0) {
            HStack {
                Button { if text.isEmpty { close() } else { confirmLeave = true } } label: {
                    Text("Not now").lgText(LGTextStyle(size: 16, weight: .medium, relativeTo: .body))
                        .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Spacer()
                Text(verbatim: Letters.counter(text.count))
                    .lgText(LGTextStyle(size: 13, weight: .regular, relativeTo: .footnote), color: LGColor.inkMuted)
                    .monospacedDigit()
                    .accessibilityLabel(Text(verbatim: Letters.spokenCounter(text.count)))
            }
            .padding(.horizontal, 24).padding(.top, 8)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 12) {
                        SunView(idle: false, face: .happy, eyesOpen: 1).frame(width: 44, height: 44).accessibilityHidden(true)
                        Text("A letter to you at \(Letters.hoursName(milestone))")
                            .lgText(LGTextStyle(size: 22, weight: .bold, relativeTo: .title2, tracking: -0.44))
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                    }
                    Text(verbatim: Letters.invitation(arrival: Letters.arrival(milestone: milestone, total: total,
                                                                               weeklyHours: weeklyHours, now: Date())))
                        .lgText(.note, color: LGColor.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 12)
                    LetterPaper {
                        TextField("", text: $text, axis: .vertical)
                            .lgText(LGTextStyle(size: 15, weight: .regular, relativeTo: .body))
                            .modifier(LetterLines())
                            .lineLimit(8...)
                            .focused($focused)
                            .accessibilityLabel("Your letter")
                            .onChange(of: text) { _, new in
                                let clamped = Letters.clamped(new)
                                if clamped != new { text = clamped }
                            }
                    }
                    .padding(.top, 14)
                    .contentShape(Rectangle())
                    .onTapGesture { focused = true }
                    Text("Not sure what to say? What's hard right now. What you hope to be able to do.")
                        .lgText(.caption, color: LGColor.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 12)
                }
                .padding(.horizontal, 24).padding(.top, 8).padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            Button("Seal the letter", action: seal)
                .buttonStyle(.lg(.primary))
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .padding(.horizontal, 24).padding(.bottom, 10)
        }
    }

    private var sealedPage: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    SealedEnvelope().padding(.top, 48)
                    Text("Sealed.")
                        .lgText(LGTextStyle(size: 28, weight: .bold, relativeTo: .title, tracking: -0.56))
                        .accessibilityAddTraits(.isHeader)
                        .padding(.top, 36)
                    Text("The sun will bring it back at \(Letters.hoursName(milestone)). \(Letters.toGo(milestone: milestone, total: total))")
                        .lgText(.body, color: LGColor.inkMuted)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
            }
            Button("Done", action: close)
                .buttonStyle(.lg(.primary))
                .padding(.horizontal, 24).padding(.bottom, 10)
        }
    }

    private func seal() {
        let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty, Letters.canWrite(for: milestone, total: total) else { return }
        if let replacing { context.delete(replacing) }
        context.insert(Letter(craftId: craft.id, text: body, totalWhenWritten: total, milestone: milestone))
        try? context.save()
        Haptics.play(.letterSealed)
        focused = false
        withAnimation(.easeInOut(duration: 0.3)) { sealed = true }
        AccessibilityNotification.Announcement(String(localized: "Sealed.")).post()
    }

    private func close() {
        onDone()
        dismiss()
    }
}

/// A sealed letter from The long game: the envelope, when it opens, Rewrite and Throw away. Its text is never shown.
struct SealedLetterSheet: View {
    let letter: Letter
    let onRewrite: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var confirmThrow = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    SealedEnvelope().padding(.top, 48)
                    Text("A letter is waiting")
                        .lgText(LGTextStyle(size: 24, weight: .bold, relativeTo: .title2, tracking: -0.48))
                        .accessibilityAddTraits(.isHeader)
                        .padding(.top, 36)
                    Text(verbatim: LetterText.waitingLine(letter))
                        .lgText(.body, color: LGColor.inkMuted)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 8)
                    Text("No peeking. A sealed letter can't be opened early.")
                        .lgText(.caption, color: LGColor.inkMuted)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 12)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
            }
            VStack(spacing: 2) {
                Button("Rewrite") {
                    dismiss()
                    onRewrite()
                }
                .buttonStyle(.lg(.text))
                Button("Throw away") { confirmThrow = true }.buttonStyle(.lg(.text))
            }
            .padding(.horizontal, 24).padding(.bottom, 10)
        }
        .background(LGColor.background.ignoresSafeArea())
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(30)
        .confirmationDialog("Throw this letter away?", isPresented: $confirmThrow, titleVisibility: .visible) {
            Button("Throw away", role: .destructive) {
                context.delete(letter)
                try? context.save()
                dismiss()
            }
        } message: {
            Text("It hasn't been opened yet, and it can't be brought back.")
        }
    }
}

/// The letter offered at the end of setup: the button sets this, and Home opens the letter sheet once.
enum LetterOffer {
    static let afterSetupKey = "letter.afterSetup"

    /// "Write to yourself at 100 hours", or the next milestone when past hours already pass 100.
    static func title(total: Double) -> String? {
        Letters.next(after: total).map { String(localized: "Write to yourself at \(Letters.hoursName($0))") }
    }
}

enum LetterText {
    /// "Opens at 4,000 h · written 3 June 2026"
    static func waitingLine(_ letter: Letter) -> String {
        String(localized: "Opens at \(DurationFormat.grouped(letter.milestone)) h · written \(ThenAndNow.date(letter.writtenAt))")
    }
}

/// One delivered letter on its paper: the pill, the text, the date. One VoiceOver element.
struct DeliveredLetterCard: View {
    let letter: Letter

    var body: some View {
        VStack(spacing: 14) {
            Text(verbatim: Letters.agoLine(milestone: letter.milestone, totalWhenWritten: letter.totalWhenWritten))
                .lgText(LGTextStyle(size: 12, weight: .bold, relativeTo: .caption), color: LGColor.timerGold)
                .padding(.horizontal, 12)
                .frame(minHeight: 26)
                .background(LGColor.storyPill, in: Capsule())
            LetterPaper(tilt: -1) {
                Text(verbatim: letter.text)
                    .lgText(LGTextStyle(size: 15, weight: .regular, relativeTo: .body))
                    .modifier(LetterLines())
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(verbatim: Letters.writtenLine(date: letter.writtenAt, totalWhenWritten: letter.totalWhenWritten))
                .lgText(.caption, color: LGColor.inkMuted)
        }
        .accessibilityElement(children: .combine)
    }
}

/// The letter brought back at its milestone, once, right after the celebration.
struct LetterDeliveredView: View {
    let letter: Letter
    /// The milestone after this one, to write to next (nil at 10,000).
    let next: Int?
    let onWriteNext: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    SunView(idle: false, face: .celebrate).frame(width: 64, height: 64)
                        .accessibilityHidden(true)
                        .padding(.top, 28)
                    Text("A letter from you")
                        .lgText(LGTextStyle(size: 28, weight: .bold, relativeTo: .title, tracking: -0.56))
                        .accessibilityAddTraits(.isHeader)
                        .padding(.top, 10)
                    DeliveredLetterCard(letter: letter).padding(.top, 16)
                }
                .padding(.horizontal, 24).padding(.bottom, 16)
            }
            VStack(spacing: 2) {
                if let next {
                    Button("Write to you at \(Letters.hoursName(next))", action: onWriteNext).buttonStyle(.lg(.primary))
                }
                Button("Keep it and close", action: onClose).buttonStyle(.lg(.text))
            }
            .padding(.horizontal, 24).padding(.bottom, 10)
        }
        .background(alignment: .top) {
            LinearGradient(colors: [LGColor.anniversaryPill, LGColor.background], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.4))
                .ignoresSafeArea()
        }
        .background(LGColor.background.ignoresSafeArea())
        .onAppear { Haptics.play(.letterDelivered) }
    }
}

/// Your letters: the opened ones, oldest first, each can be deleted; sealed letters of an earlier craft read
/// "Never reached". At 10,000 hours the same list is shown as "All your letters", first to last.
struct YourLettersView: View {
    var title: LocalizedStringKey = "Your letters"
    var showsClose = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Letter.milestone) private var letters: [Letter]
    @Query private var crafts: [Craft]
    @State private var deleting: Letter?

    private var activeIds: Set<UUID> { Set(crafts.filter(\.isActive).map(\.id)) }

    /// Opened letters (any craft), then the sealed letters of archived crafts. Never a sealed letter of the active one.
    private var shown: [Letter] {
        letters.filter { !$0.isSealed || !activeIds.contains($0.craftId) }
            .sorted { ($0.openedAt ?? $0.writtenAt, $0.milestone) < ($1.openedAt ?? $1.writtenAt, $1.milestone) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if showsClose {
                    Color.clear.frame(width: 34, height: 44)
                } else {
                    LGIconButton(systemName: "chevron.left", label: "Back") { dismiss() }.padding(.leading, -10)
                }
                Spacer()
                Text(title).lgText(.navTitle).accessibilityAddTraits(.isHeader)
                Spacer()
                if showsClose {
                    Button("Done") { dismiss() }.buttonStyle(.lg(.text)).fixedSize()
                } else {
                    Color.clear.frame(width: 34, height: 44)
                }
            }
            .frame(minHeight: 44)
            .padding(.horizontal, 24)
            ScrollView {
                LazyVStack(spacing: 28) {
                    ForEach(shown) { letter in
                        if letter.isSealed {
                            VStack(spacing: 4) {
                                Text("A letter to \(Letters.hoursName(letter.milestone))").lgText(.rowStrong)
                                Text("Never reached").lgText(.caption, color: LGColor.inkMuted)
                            }
                            .frame(maxWidth: .infinity)
                            .accessibilityElement(children: .combine)
                        } else {
                            VStack(spacing: 0) {
                                DeliveredLetterCard(letter: letter)
                                Button("Delete") { deleting = letter }
                                    .buttonStyle(.lg(.text))
                                    .accessibilityLabel(Text("Delete this letter"))
                            }
                        }
                    }
                }
                .padding(.horizontal, 24).padding(.vertical, 20)
            }
        }
        .background(LGColor.background.ignoresSafeArea())
        .lgHidesNavigationBar()
        .confirmationDialog("Delete this letter?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let deleting { context.delete(deleting); try? context.save() }
                deleting = nil
            }
        } message: {
            Text("It can't be brought back.")
        }
    }
}
