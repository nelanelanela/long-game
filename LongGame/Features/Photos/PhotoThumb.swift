import SwiftUI

/// Small pictures made on the fly from a saved photo and kept in memory only (never stored).
@MainActor
enum ThumbnailCache {
    private static let cache: NSCache<NSString, PlatformImage> = {
        let c = NSCache<NSString, PlatformImage>()
        c.countLimit = 200
        return c
    }()

    private static func key(_ id: UUID, _ pixels: Int, _ size: Int) -> NSString { "\(id.uuidString)-\(pixels)-\(size)" as NSString }

    static func cached(_ id: UUID, pixels: Int, dataSize: Int) -> PlatformImage? { cache.object(forKey: key(id, pixels, dataSize)) }

    static func image(_ id: UUID, data: Data, pixels: Int) async -> PlatformImage? {
        if let hit = cached(id, pixels: pixels, dataSize: data.count) { return hit }
        let cg = await Task.detached(priority: .utility) { PhotoProcessing.thumbnail(data, maxPixel: pixels) }.value
        guard let cg else { return nil }
        let image = PlatformImage.make(cgImage: cg)
        cache.setObject(image, forKey: key(id, pixels, data.count))
        return image
    }
}

/// A square thumbnail of a session's photo.
struct PhotoThumb: View {
    let id: UUID
    let data: Data
    var side: CGFloat = 56
    var radius: CGFloat = 12

    @Environment(\.displayScale) private var scale
    @State private var image: PlatformImage?

    var body: some View {
        let pixels = Int(side * scale * 2)
        Group {
            if let image = image ?? ThumbnailCache.cached(id, pixels: pixels, dataSize: data.count) {
                Image(platformImage: image).resizable().scaledToFill().accessibilityIgnoresInvertColors()
            } else {
                LGColor.chipFill
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .task(id: data.count) { image = await ThumbnailCache.image(id, data: data, pixels: pixels) }
    }
}
