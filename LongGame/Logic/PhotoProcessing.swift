import Foundation
import ImageIO
import UniformTypeIdentifiers
import CoreGraphics

// A photo of what was made, attached to a session (section 16). Pure image work, no UI, so it can be tested.

enum PhotoProcessing {
    /// The longest side of a saved photo, in pixels.
    static let maxSide = 2048
    static let jpegQuality = 0.8

    /// Resizes to at most `maxSide` on the longest side (never enlarging), turns the picture upright, and encodes it
    /// as JPEG at quality 0.8 *without* any metadata: location, camera, date and orientation tags are all left out.
    /// Returns nil when the data is not an image.
    static func prepare(_ data: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let size = pixelSize(source) else { return nil }
        let side = min(maxSide, Int(max(size.width, size.height)))
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,   // applies the orientation to the pixels
            kCGImageSourceThumbnailMaxPixelSize: side,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return jpeg(image)
    }

    /// A small picture for lists, from the saved photo (decoded straight at the small size, never the full one).
    static func thumbnail(_ data: Data, maxPixel: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// JPEG without metadata: only the quality is passed, so nothing is copied from the source.
    static func jpeg(_ image: CGImage) -> Data? {
        let out = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(out, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: jpegQuality] as CFDictionary)
        return CGImageDestinationFinalize(destination) ? out as Data : nil
    }

    /// Pixel width and height of an image file, without decoding it.
    static func pixelSize(_ data: Data) -> CGSize? {
        CGImageSourceCreateWithData(data as CFData, nil).flatMap(pixelSize)
    }

    private static func pixelSize(_ source: CGImageSource) -> CGSize? {
        guard let p = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let w = p[kCGImagePropertyPixelWidth] as? Int, let h = p[kCGImagePropertyPixelHeight] as? Int else { return nil }
        return CGSize(width: w, height: h)
    }

    /// The identifying details present in an image file: location, camera, dates, comments. Empty for a photo that
    /// went through `prepare`. (Plain structure such as the pixel size or resolution is not counted.)
    static func metadataKeys(_ data: Data) -> Set<String> {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let p = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else { return [] }
        var found = Set<String>()
        for group in [kCGImagePropertyGPSDictionary, kCGImagePropertyIPTCDictionary, kCGImagePropertyMakerAppleDictionary] where p[group] != nil {
            found.insert(group as String)
        }
        if let tiff = p[kCGImagePropertyTIFFDictionary] as? [CFString: Any],
           [kCGImagePropertyTIFFMake, kCGImagePropertyTIFFModel, kCGImagePropertyTIFFSoftware, kCGImagePropertyTIFFDateTime]
            .contains(where: { tiff[$0] != nil }) { found.insert(kCGImagePropertyTIFFDictionary as String) }
        if let exif = p[kCGImagePropertyExifDictionary] as? [CFString: Any],
           [kCGImagePropertyExifUserComment, kCGImagePropertyExifDateTimeOriginal, kCGImagePropertyExifDateTimeDigitized,
            kCGImagePropertyExifLensModel, kCGImagePropertyExifBodySerialNumber]
            .contains(where: { exif[$0] != nil }) { found.insert(kCGImagePropertyExifDictionary as String) }
        return found
    }
}

/// Days with a photo (the white dot in the calendar) and the words for a session's part of the day.
enum SessionPhotos {
    /// The start of each day that has at least one session with a photo.
    static func daysWithPhoto(_ sessions: [(start: Date, hasPhoto: Bool)], calendar: Calendar = .current) -> Set<Date> {
        Set(sessions.filter(\.hasPhoto).map { calendar.startOfDay(for: $0.start) })
    }

    enum DayPart: String, Equatable {
        case morning, afternoon, evening, night

        var title: String {
            switch self {
            case .morning: String(localized: "Morning")
            case .afternoon: String(localized: "Afternoon")
            case .evening: String(localized: "Evening")
            case .night: String(localized: "Night")
            }
        }

        /// Lower case, for "Photo from Thursday 22 October, evening session".
        var lowercased: String { title.lowercased() }
    }

    /// Morning 05:00–11:59, afternoon 12:00–16:59, evening 17:00–21:59, night 22:00–04:59.
    static func dayPart(_ date: Date, calendar: Calendar = .current) -> DayPart {
        switch calendar.component(.hour, from: date) {
        case 5..<12: .morning
        case 12..<17: .afternoon
        case 17..<22: .evening
        default: .night
        }
    }

    /// "Evening · 1 h 15" for the top of the viewer.
    static func caption(start: Date, durationSec: Double, calendar: Calendar = .current) -> String {
        let minutes = Int((durationSec / 60).rounded())
        let h = minutes / 60, m = minutes % 60
        let length = h > 0 ? (m > 0 ? String(format: "%d h %02d", h, m) : "\(h) h") : "\(m) m"
        return "\(dayPart(start, calendar: calendar).title) · \(length)"
    }

    /// "Thursday 22 October"
    static func dayName(_ date: Date, calendar: Calendar = .current) -> String {
        CachedFormatter.pattern("EEEE d MMMM", calendar: calendar).string(from: date)
    }

    /// "Photo from Thursday 22 October, evening session"
    static func spokenLabel(start: Date, calendar: Calendar = .current) -> String {
        String(localized: "Photo from \(dayName(start, calendar: calendar)), \(dayPart(start, calendar: calendar).lowercased) session")
    }
}
