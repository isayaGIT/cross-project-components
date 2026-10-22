import Foundation

/// A single sticker entry in a sticker pack.
///
/// `id` must remain stable across library updates. Asset bytes are intentionally
/// stored outside this value type and referenced through `assetID`.
public struct Sticker: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let packID: String
    public let assetID: String
    public var name: String?
    public var tags: [String]

    public init(
        id: String,
        packID: String,
        assetID: String,
        name: String? = nil,
        tags: [String] = []
    ) {
        self.id = id
        self.packID = packID
        self.assetID = assetID
        self.name = name
        self.tags = tags
    }
}
