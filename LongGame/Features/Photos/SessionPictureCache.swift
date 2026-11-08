import SwiftUI
import Foundation

/// Thumbnails of the default session pictures, kept in the Caches folder (never in the database, never in iCloud).
/// The system may empty that folder at any time, and "Clear" in Settings does too: a missing file just means the
/// picture is drawn again. Photos the user added are never involved.
enum SessionPictureCache {
    struct Key: Hashable, Sendable {
        var seed: UInt32
        var startMinute: Int
        var minutes: Int
        var progress: Double
        var pixels: Int

        /// The file's name: every number that changes the picture is in it.
        var fileName: String { "\(seed)-\(startMinute)-\(minutes)-\(Int((progress * 1000).rounded()))-\(pixels).png" }
    }

    // NSCache is thread-safe on its own.
    nonisolated(unsafe) private static let memoryCache: NSCache<NSString, PlatformImage> = {
        let c = NSCache<NSString, PlatformImage>()
        c.countLimit = 300
        return c
    }()

    static var directory: URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("SessionPictures", isDirectory: true)
    }

    static func memory(_ key: Key) -> PlatformImage? { memoryCache.object(forKey: key.fileName as NSString) }

    /// The thumbnail: from memory, then from the file, else drawn now and saved.
    @MainActor
    static func image(for key: Key, layout: SessionPictureLayout, side: CGFloat, scale: CGFloat) async -> PlatformImage? {
        if let hit = memory(key) { return hit }
        let url = directory.appendingPathComponent(key.fileName)
        let onDisk: PlatformImage? = await Task.detached(priority: .utility) { PlatformImage.make(contentsOf: url) }.value
        if let onDisk {
            memoryCache.setObject(onDisk, forKey: key.fileName as NSString)
            return onDisk
        }
        guard let drawn = render(layout: layout, side: side, scale: scale) else { return nil }
        memoryCache.setObject(drawn, forKey: key.fileName as NSString)
        if let data = drawn.pngData() {
            Task.detached(priority: .utility) {
                try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                try? data.write(to: url, options: .atomic)
            }
        }
        return drawn
    }

    @MainActor
    private static func render(layout: SessionPictureLayout, side: CGFloat, scale: CGFloat) -> PlatformImage? {
        let renderer = ImageRenderer(content: SessionPictureCanvas(layout: layout).frame(width: side, height: side))
        renderer.scale = scale
        #if canImport(UIKit)
        return renderer.uiImage
        #else
        return renderer.nsImage
        #endif
    }

    // MARK: Size and clearing (Settings › iCloud & storage › Default pictures)

    /// How many bytes the cached pictures take, worked out off the main thread by the caller.
    static func sizeOnDisk() -> Int {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey])) ?? []
        return files.reduce(0) { $0 + ((try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
    }

    /// Empties only this cache and returns the bytes freed. Photos live in the database and are not touched.
    @discardableResult
    static func clear() -> Int {
        let freed = sizeOnDisk()
        try? FileManager.default.removeItem(at: directory)
        memoryCache.removeAllObjects()
        return freed
    }
}
