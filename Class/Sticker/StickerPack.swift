import Foundation

/// Metadata for a distributable pack of stickers.
///
/// A library stores stable sticker IDs rather than embedding sticker objects,
/// avoiding duplicated records when a catalog and a user's configuration refer
/// to the same library.
public struct StickerPack: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public var name: String
    public var shortDescription: String
    public var tags: [String]
    public var coverAssetID: String?
    public var version: String
    public var stickerIDs: [String]
    public var publisher: String?
    public var authorNickname: String?
    public var authorUUID: String?
    public var updatedAt: Date?

    public init(
        id: String,
        name: String,
        shortDescription: String = "",
        tags: [String] = [],
        coverAssetID: String? = nil,
        version: String = "1",
        stickerIDs: [String] = [],
        publisher: String? = nil,
        authorNickname: String? = nil,
        authorUUID: String? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.shortDescription = shortDescription
        self.tags = tags
        self.coverAssetID = coverAssetID
        self.version = version
        self.stickerIDs = Self.uniquePreservingOrder(stickerIDs)
        self.publisher = publisher
        self.authorNickname = authorNickname
        self.authorUUID = authorUUID
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, shortDescription, tags, coverAssetID, version, stickerIDs, publisher, authorNickname, authorUUID, updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        shortDescription = try container.decodeIfPresent(String.self, forKey: .shortDescription) ?? ""
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        coverAssetID = try container.decodeIfPresent(String.self, forKey: .coverAssetID)
        version = try container.decodeIfPresent(String.self, forKey: .version) ?? "1"
        stickerIDs = Self.uniquePreservingOrder(try container.decodeIfPresent([String].self, forKey: .stickerIDs) ?? [])
        publisher = try container.decodeIfPresent(String.self, forKey: .publisher)
        authorNickname = try container.decodeIfPresent(String.self, forKey: .authorNickname)
        authorUUID = try container.decodeIfPresent(String.self, forKey: .authorUUID)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }

    private static func uniquePreservingOrder(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
}
