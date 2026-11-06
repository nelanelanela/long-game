import SwiftUI
import CoreGraphics
import UniformTypeIdentifiers

// One name for "a picture" on iPhone (UIImage) and Mac (NSImage), so the photo code is written once.
#if canImport(UIKit)
import UIKit
typealias PlatformImage = UIImage

extension Image {
    init(platformImage: PlatformImage) { self.init(uiImage: platformImage) }
}

extension PlatformImage {
    static func make(cgImage: CGImage) -> PlatformImage { UIImage(cgImage: cgImage) }
    static func make(contentsOf url: URL) -> PlatformImage? { UIImage(contentsOfFile: url.path) }
    static var photoPlaceholder: PlatformImage { UIImage(systemName: "photo") ?? UIImage() }
    var pixelSize: CGSize { CGSize(width: size.width * scale, height: size.height * scale) }
}
#else
import AppKit
typealias PlatformImage = NSImage

extension Image {
    init(platformImage: PlatformImage) { self.init(nsImage: platformImage) }
}

extension PlatformImage {
    static func make(cgImage: CGImage) -> PlatformImage { NSImage(cgImage: cgImage, size: .zero) }
    static func make(contentsOf url: URL) -> PlatformImage? { NSImage(contentsOf: url) }
    static var photoPlaceholder: PlatformImage { NSImage(systemSymbolName: "photo", accessibilityDescription: nil) ?? NSImage() }

    var cgImage: CGImage? { cgImage(forProposedRect: nil, context: nil, hints: nil) }

    var pixelSize: CGSize {
        guard let cg = cgImage(forProposedRect: nil, context: nil, hints: nil) else { return size }
        return CGSize(width: cg.width, height: cg.height)
    }

    func pngData() -> Data? {
        guard let tiff = tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }

    func jpegData(compressionQuality: CGFloat) -> Data? {
        guard let tiff = tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality])
    }
}
#endif

extension ImageRenderer {
    /// The rendered picture as a UIImage (iPhone) or NSImage (Mac).
    @MainActor var platformImage: PlatformImage? {
        #if canImport(UIKit)
        uiImage
        #else
        nsImage
        #endif
    }
}
