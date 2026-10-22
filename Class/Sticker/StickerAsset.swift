import Foundation

/// Describes where a sticker's original and optional thumbnail can be read.
/// The actual file/network loading and caching are handled by a storage layer.
public struct StickerAsset: Identifiable, Codable, Hashable, Sendable {
    public enum MediaType: String, Codable, CaseIterable, Sendable {
        case png
        case jpeg
        case webp
        case gif
        case apng
        case heic
        case unknown
    }

    public let id: String
    public var originalLocation: URL
    public var thumbnailLocation: URL?
    public var mediaType: MediaType
    public var pixelWidth: Int?
    public var pixelHeight: Int?

    public init(
        id: String,
        originalLocation: URL,
        thumbnailLocation: URL? = nil,
        mediaType: MediaType = .unknown,
        pixelWidth: Int? = nil,
        pixelHeight: Int? = nil
    ) {
        self.id = id
        self.originalLocation = originalLocation
        self.thumbnailLocation = thumbnailLocation
        self.mediaType = mediaType
        self.pixelWidth = Self.validDimension(pixelWidth)
        self.pixelHeight = Self.validDimension(pixelHeight)
    }

    private static func validDimension(_ value: Int?) -> Int? {
        guard let value, value > 0 else { return nil }
        return value
    }
}
