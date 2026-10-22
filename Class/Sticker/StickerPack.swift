import Foundation

/// Metadata for a distributable pack of stickers.
///
/// A library stores stable sticker IDs rather than embedding sticker objects,
/// avoiding duplicated records when a catalog and a user's configuration refer
/// to the same library.
public struct StickerPack: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public var name: String
    public var coverAssetID: String?
    public var version: String
    public var stickerIDs: [String]
    public var publisher: String?
    public var updatedAt: Date?

    public init(
        id: String,
        name: String,
        coverAssetID: String? = nil,
        version: String = "1",
        stickerIDs: [String] = [],
        publisher: String? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.coverAssetID = coverAssetID
        self.version = version
        self.stickerIDs = Self.uniquePreservingOrder(stickerIDs)
        self.publisher = publisher
        self.updatedAt = updatedAt
    }

    private static func uniquePreservingOrder(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
}
