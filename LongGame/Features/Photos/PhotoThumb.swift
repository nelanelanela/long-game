import SwiftUI

/// Small pictures made on the fly from a saved photo and kept in memory only (never stored).
@MainActor
enum ThumbnailCache {
    private static let cache: NSCache<NSString, PlatformImage> = {
        let c = NSCache<NSString, PlatformImage>()
        c.countLimit = 200
        return c
    }()

    /// Bumped for a session each time its photo is set or removed (`Session.photoChanged`), so its old thumbnail
    /// is never shown again.
    private static var generations: [UUID: Int] = [:]
    private static var observing = false

    static func generation(_ id: UUID) -> Int {
        startObserving()
        return generations[id, default: 0]
    }

    private static func startObserving() {
        guard !observing else { return }
        observing = true
        // Handled at once on the main thread, so the very next redraw already asks for the new photo.
        NotificationCenter.default.addObserver(forName: Session.photoChanged, object: nil, queue: nil) { note in
            guard let id = note.userInfo?["id"] as? UUID else { return }
            if Thread.isMainThread {
                MainActor.assumeIsolated { generations[id, default: 0] += 1 }
            } else {
                Task { @MainActor in generations[id, default: 0] += 1 }
            }
        }
    }

    private static func key(_ id: UUID, _ pixels: Int, _ version: Int) -> NSString { "\(id.uuidString)-\(pixels)-\(version)" as NSString }

    static func cached(_ id: UUID, pixels: Int, version: Int) -> PlatformImage? { cache.object(forKey: key(id, pixels, version)) }

    /// The thumbnail, from memory if it was made before. Only on a miss is the photo itself read (`load`, which
    /// may read the photo's file) and made small in the background.
    static func image(_ id: UUID, pixels: Int, version: Int, load: () -> Data?) async -> PlatformImage? {
        if let hit = cached(id, pixels: pixels, version: version) { return hit }
        guard let data = Signposts.measure("Photo read", load) else { return nil }
        let cg = await Task.detached(priority: .utility) {
            Signposts.measure("Photo thumbnail") { PhotoProcessing.thumbnail(data, maxPixel: pixels) }
        }.value
        guard let cg else { return nil }
        let image = PlatformImage.make(cgImage: cg)
        cache.setObject(image, forKey: key(id, pixels, version))
        return image
    }
}

/// A square thumbnail of a session's photo.
///
/// Made from a session, it never reads the photo while the screen is drawn: it looks in the thumbnail cache first
/// and only reads the photo's file (about half a megabyte) when the thumbnail isn't there yet, after drawing.
struct PhotoThumb: View {
    let id: UUID
    var side: CGFloat = 56
    var radius: CGFloat = 12
    /// Tells a photo apart from an earlier one for the same id: the data's size for a photo in hand, the
    /// session's photo generation otherwise.
    private let version: Int
    private let load: @MainActor () -> Data?

    @Environment(\.displayScale) private var scale
    @State private var image: PlatformImage?

    /// A photo already in hand (being chosen or edited, not yet saved).
    init(id: UUID, data: Data, side: CGFloat = 56, radius: CGFloat = 12) {
        self.id = id
        self.side = side
        self.radius = radius
        self.version = -data.count
        self.load = { data }
    }

    /// A session's saved photo.
    init(session: Session, side: CGFloat = 56, radius: CGFloat = 12) {
        self.id = session.id
        self.side = side
        self.radius = radius
        self.version = ThumbnailCache.generation(session.id)
        self.load = { [session] in session.photo }
    }

    var body: some View {
        let pixels = Int(side * scale * 2)
        Group {
            if let image = image ?? ThumbnailCache.cached(id, pixels: pixels, version: version) {
                Image(platformImage: image).resizable().scaledToFill().accessibilityIgnoresInvertColors()
            } else {
                LGColor.chipFill
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .task(id: version) { image = await ThumbnailCache.image(id, pixels: pixels, version: version, load: load) }
    }
}
