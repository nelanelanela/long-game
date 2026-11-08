import SwiftUI
import SwiftData
import PhotosUI

/// Full-screen, dark viewer for the photos of all days, oldest first and newest last. Swipe left and right to move
/// (a cross-fade with Reduce Motion), pinch to zoom. ··· offers Change photo, Edit note and Remove photo.
struct PhotoViewer: View {
    /// Every session with a photo, oldest first.
    let sessions: [Session]
    @State var currentID: PersistentIdentifier

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var zoom: CGFloat = 1
    @State private var committedZoom: CGFloat = 1
    @State private var pan: CGSize = .zero
    @State private var committedPan: CGSize = .zero
    @State private var forward = true
    @State private var confirmRemove = false
    @State private var editingNote = false
    @State private var changingPhoto = false
    @State private var pickingFromLibrary = false
    @State private var takingPhoto = false
    @State private var pickerItem: PhotosPickerItem?

    init(sessions: [Session], startAt: Session) {
        self.sessions = sessions
        _currentID = State(initialValue: startAt.persistentModelID)
    }

    private var index: Int? { sessions.firstIndex { $0.persistentModelID == currentID } }
    private var current: Session? { index.map { sessions[$0] } }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let session = current, let data = session.photo {
                VStack(spacing: 0) {
                    header(session)
                    ZStack {
                        photoPage(session, data: data)
                            .id(session.persistentModelID)
                            .transition(reduceMotion ? .opacity
                                        : .asymmetric(insertion: .move(edge: forward ? .trailing : .leading),
                                                      removal: .move(edge: forward ? .leading : .trailing)))
                    }
                    .clipped()
                    if let note = session.note, !note.isEmpty {
                        ScrollView {
                            Text(note)
                                .lgText(.body, color: .white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 24).padding(.vertical, 12)
                        }
                        .frame(maxHeight: 130)
                    }
                    strip
                }
            }
        }
        .preferredColorScheme(.dark)
        .confirmationDialog("Remove this photo?", isPresented: $confirmRemove, titleVisibility: .visible) {
            Button("Remove photo", role: .destructive) { remove() }
        } message: {
            Text("The session and its hours stay.")
        }
        .confirmationDialog("Photo", isPresented: $changingPhoto, titleVisibility: .hidden) {
            #if os(iOS)
            if CameraPicker.isAvailable { Button("Take photo") { takingPhoto = true } }
            #endif
            Button("Choose from library") { pickingFromLibrary = true }
        }
        .photosPicker(isPresented: $pickingFromLibrary, selection: $pickerItem, matching: .images)
        #if os(iOS)
        .fullScreenCover(isPresented: $takingPhoto) {
            CameraPicker { data in
                takingPhoto = false
                if let data { replace(with: data) }
            }
            .ignoresSafeArea()
        }
        #endif
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) { replace(with: data) }
                pickerItem = nil
            }
        }
        .sheet(isPresented: $editingNote) {
            if let session = current { NoteEditor(session: session).lgSheetCard() }
        }
        .onChange(of: sessions.count) { _, _ in
            if index == nil { dismiss() }
        }
        // An open counts once the photo has been on screen for a second (and at most once an hour, see `PhotoViews`).
        // Moving to another photo cancels this, so a quick swipe past counts nothing.
        .task(id: currentID) {
            try? await Task.sleep(for: .seconds(PhotoViews.dwell))
            guard !Task.isCancelled, let session = current else { return }
            session.countPhotoView()
            try? context.save()
        }
    }

    // MARK: Pieces

    private func header(_ session: Session) -> some View {
        HStack(spacing: 8) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Close")
            Spacer(minLength: 0)
            VStack(spacing: 2) {
                Text(SessionPhotos.dayName(session.start)).lgText(.rowStrong, color: .white)
                Text(SessionPhotos.caption(start: session.start, durationSec: session.durationSec))
                    .lgText(.caption, color: .white.opacity(0.7))
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            Menu {
                Button("Change photo") { changingPhoto = true }
                Button("Edit note") { editingNote = true }
                Button("Remove photo", role: .destructive) { confirmRemove = true }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("More")
        }
        .padding(.horizontal, 12)
    }

    private func photoPage(_ session: Session, data: Data) -> some View {
        ZoomablePhoto(data: data, id: session.id, zoom: $zoom, committedZoom: $committedZoom,
                      pan: $pan, committedPan: $committedPan, onSwipe: { step($0) })
            .accessibilityLabel(SessionPhotos.spokenLabel(start: session.start))
            .accessibilityAddTraits(.isImage)
            // VoiceOver: swipe up or down to move between photos.
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: step(1)
                case .decrement: step(-1)
                @unknown default: break
                }
            }
    }

    /// A strip of the most recent photos; the one on show is outlined.
    private var strip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(sessions, id: \.persistentModelID) { s in
                        if let data = s.photo {
                            Button { go(to: s) } label: {
                                PhotoThumb(id: s.id, data: data, side: 48, radius: 8)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .stroke(.white, lineWidth: s.persistentModelID == currentID ? 2 : 0)
                                    }
                                    .opacity(s.persistentModelID == currentID ? 1 : 0.6)
                                    .frame(minWidth: 44, minHeight: 44)
                            }
                            .buttonStyle(.plain)
                            .id(s.persistentModelID)
                            .accessibilityLabel(SessionPhotos.spokenLabel(start: s.start))
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            .frame(height: 64)
            .onAppear { proxy.scrollTo(currentID, anchor: .center) }
            .onChange(of: currentID) { _, id in withAnimation(reduceMotion ? nil : .easeInOut) { proxy.scrollTo(id, anchor: .center) } }
        }
        .padding(.bottom, 8)
    }

    // MARK: Moving and changing

    private func step(_ delta: Int) {
        guard let index else { return }
        let next = index + delta
        guard sessions.indices.contains(next) else { return }
        go(to: sessions[next])
    }

    private func go(to session: Session) {
        guard session.persistentModelID != currentID, let from = index,
              let to = sessions.firstIndex(where: { $0.persistentModelID == session.persistentModelID }) else { return }
        forward = to > from
        zoom = 1; committedZoom = 1; pan = .zero; committedPan = .zero
        withAnimation(.easeInOut(duration: reduceMotion ? 0.25 : 0.3)) { currentID = session.persistentModelID }
    }

    private func replace(with data: Data) {
        guard let session = current else { return }
        Task {
            let prepared = await Task.detached(priority: .userInitiated) { PhotoProcessing.prepare(data) }.value
            if let prepared {
                session.setPhoto(prepared)
                session.editedAt = Date()
                try? context.save()
            }
        }
    }

    private func remove() {
        guard let session = current, let i = index else { return }
        // Move to a neighbour first so the viewer has something to show; close when this was the last photo.
        let neighbour = sessions.indices.contains(i + 1) ? sessions[i + 1] : (i > 0 ? sessions[i - 1] : nil)
        session.setPhoto(nil)
        session.editedAt = Date()
        try? context.save()
        if let neighbour { currentID = neighbour.persistentModelID } else { dismiss() }
    }
}

/// A photo fitted to the screen. Pinch to zoom; drag to move when zoomed; swipe sideways when not zoomed.
private struct ZoomablePhoto: View {
    let data: Data
    let id: UUID
    @Binding var zoom: CGFloat
    @Binding var committedZoom: CGFloat
    @Binding var pan: CGSize
    @Binding var committedPan: CGSize
    var onSwipe: (Int) -> Void

    @State private var image: PlatformImage?

    var body: some View {
        GeometryReader { geo in
            Group {
                if let image {
                    Image(platformImage: image).resizable().scaledToFit().accessibilityIgnoresInvertColors()
                } else {
                    ProgressView().tint(.white)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .scaleEffect(zoom)
            .offset(pan)
            .gesture(
                MagnifyGesture()
                    .onChanged { zoom = min(5, max(1, committedZoom * $0.magnification)) }
                    .onEnded { _ in
                        committedZoom = zoom
                        if zoom == 1 { pan = .zero; committedPan = .zero }
                    }
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 12)
                    .onChanged { value in
                        if committedZoom > 1 {
                            pan = CGSize(width: committedPan.width + value.translation.width,
                                         height: committedPan.height + value.translation.height)
                        }
                    }
                    .onEnded { value in
                        if committedZoom > 1 {
                            committedPan = pan
                        } else if abs(value.translation.width) > 60, abs(value.translation.width) > abs(value.translation.height) {
                            onSwipe(value.translation.width < 0 ? 1 : -1)
                        }
                    }
            )
            .onTapGesture(count: 2) { toggleZoom() }
            .accessibilityAction(named: Text("Zoom in or out")) { toggleZoom() }
        }
        .task(id: data.count) { image = await Self.decode(data) }
    }

    private func toggleZoom() {
        withAnimation(.easeInOut(duration: 0.2)) {
            let target: CGFloat = committedZoom > 1 ? 1 : 2.5
            zoom = target; committedZoom = target
            if target == 1 { pan = .zero; committedPan = .zero }
        }
    }

    private static func decode(_ data: Data) async -> PlatformImage? {
        await Task.detached(priority: .userInitiated) {
            PhotoProcessing.thumbnail(data, maxPixel: PhotoProcessing.maxSide).map { PlatformImage.make(cgImage: $0) }
        }.value
    }
}

/// Edits one session's note, from the viewer.
private struct NoteEditor: View {
    let session: Session
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var text: String

    init(session: Session) {
        self.session = session
        _text = State(initialValue: session.note ?? "")
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Button("Cancel") { dismiss() }.buttonStyle(.lg(.text))
                Spacer()
                Text("Edit note").lgText(.navTitle).accessibilityAddTraits(.isHeader)
                Spacer()
                Button("Save") {
                    session.note = SessionRules.savedNote(text)
                    session.editedAt = Date()
                    try? context.save()
                    dismiss()
                }
                .buttonStyle(.lg(.text))
            }
            TextField("A note, if you like", text: $text, axis: .vertical)
                .lineLimit(3...8)
                .lgText(.row)
                .padding(14)
                .background(Color(hex: 0xF6F3EE), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .onChange(of: text) { _, new in
                    let clamped = SessionRules.clampedNote(new)
                    if clamped != new { text = clamped }
                }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24).padding(.top, 20)
        .background(LGColor.background)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
