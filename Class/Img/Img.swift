import Foundation

/// A logical image resource with zero or more fetchable quality variants.
///
/// `id` is an opaque, stable identifier supplied by the owning application or
/// media service. Keep original files and derived variants outside this model;
/// this value only describes how they can be addressed and displayed.
public struct Img: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public var variants: [ImgVariant]
    public var altText: String?

    public init(
        id: String,
        variants: [ImgVariant] = [],
        altText: String? = nil
    ) {
        self.id = id
        self.variants = Self.uniqueVariantsPreservingOrder(variants)
        self.altText = altText
    }

    /// Returns the requested representation, if the service has supplied it.
    public func variant(for kind: ImgVariant.Kind) -> ImgVariant? {
        variants.first { $0.kind == kind }
    }

    /// Returns the best available fallback for the initial viewer display.
    /// This does not start a network request or imply that the original is cheap.
    public var bestPreviewVariant: ImgVariant? {
        variant(for: .preview)
            ?? variant(for: .thumbnail)
            ?? variant(for: .highResolution)
            ?? variant(for: .original)
    }

    /// The preserved original file, if one is available.
    public var originalVariant: ImgVariant? {
        variant(for: .original)
    }

    private static func uniqueVariantsPreservingOrder(_ variants: [ImgVariant]) -> [ImgVariant] {
        var seen = Set<ImgVariant.Kind>()
        return variants.filter { seen.insert($0.kind).inserted }
    }
}
