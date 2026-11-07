import SwiftUI
import PhotosUI
#if os(iOS)
import UIKit
#endif
import UniformTypeIdentifiers

/// The two optional fields of section 16: a photo square and a soft note field. Nothing opens or focuses by
/// itself, and nothing is ever required. Used in the Finish sheet and when a session is edited later.
struct NotePhotoRow: View {
    @Binding var photo: Data?
    @Binding var note: String
    /// The photo gets a stable id for its thumbnail cache.
    var photoID = UUID()

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

    private var photoSquare: some View {
        ZStack(alignment: .topTrailing) {
            Button { choosing = true } label: {
                Group {
                    if let photo {
                        PhotoThumb(id: photoID, data: photo, side: squareSize, radius: 14)
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
            .accessibilityLabel(photo == nil ? "Add a photo" : "Photo, double-tap to change")
            // A picture dragged in from Photos or Files (iPad, Mac) goes through the same processing as the picker's.
            .dropDestination(for: Data.self) { items, _ in
                guard let data = items.first else { return false }
                prepare(data)
                return true
            } isTargeted: { dropping = $0 }
            .overlay {
                if dropping {
                    RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(LGColor.ink, lineWidth: 2)
                }
            }

            if photo != nil {
                Button { photo = nil } label: {
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
                .accessibilityLabel("Remove photo")
            }
        }
        .frame(width: squareSize, height: squareSize)
    }

    private func prepare(_ data: Data) {
        Task {
            let prepared = await Task.detached(priority: .userInitiated) { PhotoProcessing.prepare(data) }.value
            if let prepared { photo = prepared }
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
