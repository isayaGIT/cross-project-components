import Foundation

public struct MomentThumbnail: Sendable, Equatable {
    public let id: String
    public let images: [String]
    public let text: String

    public init(id: String, images: [String] = [], text: String = "") {
        self.id = id
        self.images = images
        self.text = text
    }

    /// Adapts the common dictionary representation used by the Python service.
    /// Non-string image values are ignored, matching its string conversion for ordinary inputs.
    public init(dictionary: [String: Any]) {
        id = dictionary["id"] as? String ?? ""
        text = dictionary["text"] as? String ?? ""
        if let values = dictionary["images"] as? [Any] {
            images = values.map { value in
                if value is NSNull { return "" }
                return String(describing: value)
            }
        } else {
            images = []
        }
    }
}

public struct ReadyMomentThumbnail: Sendable, Equatable, Codable {
    public let id: String
    public let file: String

    public init(id: String, file: String) {
        self.id = id
        self.file = file
    }
}

public struct ThumbnailGradient: Sendable, Equatable {
    public let start: (red: UInt8, green: UInt8, blue: UInt8)
    public let end: (red: UInt8, green: UInt8, blue: UInt8)

    public init(start: (UInt8, UInt8, UInt8), end: (UInt8, UInt8, UInt8)) {
        self.start = start
        self.end = end
    }

    public static func == (lhs: ThumbnailGradient, rhs: ThumbnailGradient) -> Bool {
        lhs.start.red == rhs.start.red && lhs.start.green == rhs.start.green && lhs.start.blue == rhs.start.blue &&
        lhs.end.red == rhs.end.red && lhs.end.green == rhs.end.green && lhs.end.blue == rhs.end.blue
    }
}

public enum MomentThumbnailError: Error, LocalizedError, Sendable {
    case invalidConfiguration(String)
    case filesystem(String)
    case invalidPNG(String)
    case imageProcessingUnavailable
    case imageProcessing(String)

    public var errorDescription: String? {
        switch self {
        case .invalidConfiguration(let message): return "Invalid thumbnail configuration: \(message)"
        case .filesystem(let message): return "Thumbnail filesystem error: \(message)"
        case .invalidPNG(let message): return "PNG encoding error: \(message)"
        case .imageProcessingUnavailable: return "No native image processor is available on this platform."
        case .imageProcessing(let message): return "Thumbnail image processing failed: \(message)"
        }
    }
}

public enum MomentThumbnailConstants {
    public static let size = 256
    public static let userImagePrefix = "image_moment_user_"
    public static let thumbnailDirectoryName = "缩略图"
    public static let emojiCacheDirectoryName = "_emoji_cache"
    public static let twemojiURLTemplate = "https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/{cp}.png"

    public static let gradients: [ThumbnailGradient] = [
        .init(start: (255, 154, 158), end: (254, 207, 239)),
        .init(start: (161, 140, 209), end: (251, 194, 235)),
        .init(start: (250, 208, 196), end: (255, 209, 255)),
        .init(start: (255, 236, 210), end: (252, 182, 159)),
        .init(start: (161, 196, 253), end: (194, 233, 251)),
        .init(start: (212, 252, 121), end: (150, 230, 161)),
        .init(start: (132, 250, 176), end: (143, 211, 244)),
        .init(start: (207, 217, 223), end: (226, 235, 240)),
        .init(start: (246, 211, 101), end: (253, 160, 133)),
        .init(start: (252, 203, 144), end: (213, 126, 235)),
        .init(start: (224, 195, 252), end: (142, 197, 252)),
        .init(start: (240, 147, 251), end: (245, 87, 108))
    ]
}
