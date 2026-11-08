import SwiftUI
import PhotosUI
#if os(iOS)
import UIKit
#endif
import UniformTypeIdentifiers

/// The two optional fields of section 16: a photo square and a soft note field. Nothing opens or focuses by
/// itself, and nothing is ever required. Used in the Finish sheet and when a session is edited later.
/// What the app draws for a session without a photo (see `SessionPictureThumb`).
struct DefaultPictureInfo: Equatable {
    var id: UUID
    var start: Date
    var durationSec: Double
    var progress: Double
}

struct NotePhotoRow: View {
    @Binding var photo: Data?
    @Binding var note: String
    /// The photo gets a stable id for its thumbnail cache.
    var photoID = UUID()
    /// When the session already exists, the picture drawn for it shows in the square until a photo is added or the
    /// picture is removed. Tapping it opens it large, and it can be replaced with a photo or removed, like a photo.
    var defaultPicture: DefaultPictureInfo?
    @Binding var hidesDefaultPicture: Bool

    init(photo: Binding<Data?>, note: Binding<String>, photoID: UUID = UUID(), defaultPicture: DefaultPictureInfo? = nil,
         hidesDefaultPicture: Binding<Bool> = .constant(false)) {
        _photo = photo
        _note = note
        self.photoID = photoID
        self.defaultPicture = defaultPicture
        _hidesDefaultPicture = hidesDefaultPicture
    }

    @State private var viewingDefault = false
    @State private var confirmRemoveDefault = false

    @State private var choosing = false
    @State private var pickingFromLibrary = false
    @State private var takingPhoto = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var dropping = false

    private let squareSize: CGFloat = 64

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            photoSquare
            noteField
        }
        .confirmationDialog("Photo", isPresented: $choosing, titleVisibility: .hidden) {
            #if os(iOS)
            if CameraPicker.isAvailable {
                Button("Take photo") { takingPhoto = true }
            }
            #endif
            Button("Choose from library") { pickingFromLibrary = true }
        }
        .photosPicker(isPresented: $pickingFromLibrary, selection: $pickerItem, matching: .images)
        .confirmationDialog("Remove this picture?", isPresented: $confirmRemoveDefault, titleVisibility: .visible) {
            Button("Remove picture", role: .destructive) { hidesDefaultPicture = true }
        } message: {
            Text("The session and its hours stay.")
        }
        .fullScreenCover(isPresented: $viewingDefault) {
            if let info = defaultPicture {
                DefaultPictureViewer(info: info,
                                     onReplace: { viewingDefault = false; Task { try? await Task.sleep(for: .seconds(0.4)); choosing = true } },
                                     onRemove: { viewingDefault = false; hidesDefaultPicture = true })
            }
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $takingPhoto) {
            CameraPicker { data in
                takingPhoto = false
                if let data { prepare(data) }
            }
            .ignoresSafeArea()
        }
        #endif
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) { prepare(data) }
                pickerItem = nil
            }
        }
    }

    // MARK: Photo

    /// The default picture is showing in the square (no photo of their own, none removed).
    private var showsDefault: Bool { photo == nil && defaultPicture != nil && !hidesDefaultPicture }

    private var photoSquare: some View {
        ZStack(alignment: .topTrailing) {
            Button { if showsDefault { viewingDefault = true } else { choosing = true } } label: {
                Group {
                    if let photo {
                        PhotoThumb(id: photoID, data: photo, side: squareSize, radius: 14)
                    } else if showsDefault, let info = defaultPicture {
                        SessionPictureThumb(id: info.id, start: info.start, durationSec: info.durationSec,
                                            progress: info.progress, side: squareSize, radius: 14)
                    } else {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color(hex: 0xCFC8BB), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                            .frame(width: squareSize, height: squareSize)
                            .overlay {
                                Image(systemName: "camera")
                                    .font(.system(size: 22, weight: .regular))
                                    .foregroundStyle(LGColor.gaugeLabel)
                            }
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(photo != nil ? "Photo, double-tap to change"
                                : showsDefault ? "Picture of this session, double-tap to open it" : "Add a photo")
            // A picture dragged in from Photos or Files (iPad, Mac) goes through the same processing as the picker's.
            .lgImageDrop(isTargeted: $dropping) { prepare($0) }
            .overlay {
                if dropping {
                    RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(LGColor.ink, lineWidth: 2)
                }
            }

            if photo != nil || showsDefault {
                Button { if photo != nil { photo = nil } else { confirmRemoveDefault = true } } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(LGColor.ink, in: Circle())
                        .frame(width: 44, height: 44, alignment: .topTrailing)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .offset(x: 14, y: -14)
                .accessibilityLabel(photo != nil ? "Remove photo" : "Remove picture")
            }
        }
        .frame(width: squareSize, height: squareSize)
    }

    private func prepare(_ data: Data) {
        Task {
            let prepared = await Task.detached(priority: .userInitiated) { PhotoProcessing.prepare(data) }.value
            if let prepared { photo = prepared; hidesDefaultPicture = false }
        }
    }

    // MARK: Note

    private var noteField: some View {
        ZStack(alignment: .topLeading) {
            if note.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("A note, if you like").lgText(.row, color: LGColor.inkMuted)
                    Text("What you made, what needs work")
                        .lgText(LGTextStyle(size: 12, weight: .regular, relativeTo: .caption), color: LGColor.inkMuted)
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            TextField("", text: $note, axis: .vertical)
                .lineLimit(1...4)
                .lgText(.row)
                .accessibilityLabel("A note, if you like")
                .accessibilityHint("What you made, what needs work")
                .onChange(of: note) { _, new in
                    let clamped = SessionRules.clampedNote(new)
                    if clamped != new { note = clamped }
                }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: squareSize, alignment: .topLeading)
        .background(Color(hex: 0xF6F3EE), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

#if os(iOS)
/// The system camera. The permission is asked by the system the first time it opens, never earlier.
struct CameraPicker: UIViewControllerRepresentable {
    var onFinish: (Data?) -> Void

    static var isAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onFinish: (Data?) -> Void
        init(onFinish: @escaping (Data?) -> Void) { self.onFinish = onFinish }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = info[.originalImage] as? UIImage
            onFinish(image?.jpegData(compressionQuality: 1))
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { onFinish(nil) }
    }
}
#endif

/// The default picture, large: the same dark full-screen look as the photo viewer, with the same two choices.
struct DefaultPictureViewer: View {
    let info: DefaultPictureInfo
    let onReplace: () -> Void
    let onRemove: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var confirmRemove = false

    private var layout: SessionPictureLayout {
        let minutes = max(1, Int((info.durationSec / 60).rounded()))
        let startMinute = SessionPictureSeed.startMinute(of: info.start)
        return SessionPictureLayout.make(seed: SessionPictureSeed.make(id: info.id, startMinute: startMinute, minutes: minutes),
                                         startMinute: startMinute, minutes: minutes, progress: info.progress)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                            .frame(width: 44, height: 44).contentShape(Rectangle())
                    }
                    .accessibilityLabel("Close")
                    Spacer()
                }
                .padding(.horizontal, 12)
                Spacer(minLength: 0)
                SessionPictureCanvas(layout: layout)
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .padding(.horizontal, 20)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(SessionPictureText.spoken(start: info.start, durationSec: info.durationSec))
                    .accessibilityAddTraits(.isImage)
                Text("Drawn from this session. Replace it with a photo, or remove it.")
                    .lgText(.note, color: .white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32).padding(.top, 16)
                Spacer(minLength: 0)
                VStack(spacing: 10) {
                    Button("Replace with a photo", action: onReplace).buttonStyle(.lg(.light))
                    Button("Remove picture") { confirmRemove = true }.buttonStyle(.lg(.translucent))
                }
                .padding(.horizontal, 24).padding(.bottom, 16)
            }
        }
        .preferredColorScheme(.dark)
        .confirmationDialog("Remove this picture?", isPresented: $confirmRemove, titleVisibility: .visible) {
            Button("Remove picture", role: .destructive, action: onRemove)
        } message: {
            Text("The session and its hours stay.")
        }
    }
}
