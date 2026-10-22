import Foundation

/// A concrete, fetchable representation of an image at a particular quality level.
///
/// This model describes the resource only. Downloading, decoding, caching, and
/// generating variants belong to the image-loading and server-side layers.
public struct ImgVariant: Identifiable, Codable, Hashable, Sendable {
    public enum Kind: String, Codable, CaseIterable, Sendable {
        /// Small image for grids, lists, and message bubbles.
        case thumbnail
        /// Fast-loading image used for the initial image-viewer presentation.
        case preview
        /// Larger derivative intended for zooming on common displays.
        case highResolution
        /// The preserved, unmodified uploaded file.
        case original
    }

    public enum MediaType: String, Codable, CaseIterable, Sendable {
        case jpeg
        case png
        case webp
        case avif
        case heic
        case gif
        case tiff
        case unknown
    }

    /// The variant's role is stable and unique within an `Img`.
    public var id: Kind { kind }
    public let kind: Kind
    public var url: URL
    public var pixelWidth: Int?
    public var pixelHeight: Int?
    /// Encoded file size in bytes, if known.
    public var byteCount: Int64?
    public var mediaType: MediaType

    public init(
        kind: Kind,
        url: URL,
        pixelWidth: Int? = nil,
        pixelHeight: Int? = nil,
        byteCount: Int64? = nil,
        mediaType: MediaType = .unknown
    ) {
        self.kind = kind
        self.url = url
        self.pixelWidth = Self.validDimension(pixelWidth)
        self.pixelHeight = Self.validDimension(pixelHeight)
        self.byteCount = byteCount.flatMap { $0 >= 0 ? $0 : nil }
        self.mediaType = mediaType
    }

    private static func validDimension(_ value: Int?) -> Int? {
        guard let value, value > 0 else { return nil }
        return value
    }
}
