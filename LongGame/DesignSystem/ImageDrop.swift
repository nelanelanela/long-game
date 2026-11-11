import SwiftUI
import UniformTypeIdentifiers

extension View {
    /// Accepts a picture dragged in from Photos, Files or the Finder (a picture itself, or a picture file), on the iPad
    /// and the Mac. The data goes through the same processing as the picker's.
    func lgImageDrop(isTargeted: Binding<Bool>, perform: @escaping @MainActor (Data) -> Void) -> some View {
        onDrop(of: [.image, .fileURL], isTargeted: isTargeted) { providers in
            guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) })
                    ?? providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else { return false }
            ImageDropLoader.load(provider, perform)
            return true
        }
    }
}

enum ImageDropLoader {
    static func load(_ provider: NSItemProvider, _ done: @escaping @MainActor (Data) -> Void) {
        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            _ = provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                guard let data else { return }
                Task { @MainActor in done(data) }
            }
        } else {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                let url = (item as? Data).flatMap { URL(dataRepresentation: $0, relativeTo: nil) } ?? (item as? URL)
                guard let url, let type = UTType(filenameExtension: url.pathExtension), type.conforms(to: .image),
                      let data = try? Data(contentsOf: url) else { return }
                Task { @MainActor in done(data) }
            }
        }
    }
}
