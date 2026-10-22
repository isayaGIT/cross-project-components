import Foundation

/// Discoverable catalog of sticker packs.
///
/// A library describes which packs are available from a source; each pack owns
/// its ordered sticker IDs. User selection and ordering live in
/// `UserStickerConfiguration`, not in this catalog model.
public struct StickerLibrary: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public var name: String
    public var version: String
    public var packIDs: [String]
    public var publisher: String?
    public var updatedAt: Date?

    public init(
        id: String,
        name: String,
        version: String = "1",
        packIDs: [String] = [],
        publisher: String? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.version = version
        self.packIDs = Self.uniquePreservingOrder(packIDs)
        self.publisher = publisher
        self.updatedAt = updatedAt
    }

    private static func uniquePreservingOrder(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
}
