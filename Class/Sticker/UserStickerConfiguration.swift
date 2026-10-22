import Foundation

/// User-owned sticker preferences. This does not contain or mutate public
/// library metadata; it only stores references and presentation preferences.
public struct UserStickerConfiguration: Codable, Hashable, Sendable {
    /// Selected sticker pack IDs in the exact order shown in the keyboard.
    public var selectedPackIDs: [String]
    public var favoriteStickerIDs: [String]
    /// Sticker pack IDs liked by the user.
    public var likedPackIDs: [String]
    /// Most recently used sticker IDs, newest first.
    public var recentStickerIDs: [String]

    public init(
        selectedPackIDs: [String] = [],
        favoriteStickerIDs: [String] = [],
        likedPackIDs: [String] = [],
        recentStickerIDs: [String] = []
    ) {
        self.selectedPackIDs = Self.uniquePreservingOrder(selectedPackIDs)
        self.favoriteStickerIDs = Self.uniquePreservingOrder(favoriteStickerIDs)
        self.likedPackIDs = Self.uniquePreservingOrder(likedPackIDs)
        self.recentStickerIDs = Self.uniquePreservingOrder(recentStickerIDs)
    }

    private enum CodingKeys: String, CodingKey {
        case selectedPackIDs, favoriteStickerIDs, likedPackIDs, recentStickerIDs
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        selectedPackIDs = Self.uniquePreservingOrder(try container.decodeIfPresent([String].self, forKey: .selectedPackIDs) ?? [])
        favoriteStickerIDs = Self.uniquePreservingOrder(try container.decodeIfPresent([String].self, forKey: .favoriteStickerIDs) ?? [])
        likedPackIDs = Self.uniquePreservingOrder(try container.decodeIfPresent([String].self, forKey: .likedPackIDs) ?? [])
        recentStickerIDs = Self.uniquePreservingOrder(try container.decodeIfPresent([String].self, forKey: .recentStickerIDs) ?? [])
    }

    public mutating func addPack(id: String) {
        guard !selectedPackIDs.contains(id) else { return }
        selectedPackIDs.append(id)
    }

    public mutating func removePack(id: String) {
        selectedPackIDs.removeAll { $0 == id }
    }

    public mutating func movePack(from sourceIndex: Int, to destinationIndex: Int) {
        guard selectedPackIDs.indices.contains(sourceIndex),
              selectedPackIDs.indices.contains(destinationIndex),
              sourceIndex != destinationIndex else { return }
        let packID = selectedPackIDs.remove(at: sourceIndex)
        selectedPackIDs.insert(packID, at: destinationIndex)
    }

    public mutating func setPackLiked(_ isLiked: Bool, packID: String) {
        if isLiked {
            guard !likedPackIDs.contains(packID) else { return }
            likedPackIDs.append(packID)
        } else {
            likedPackIDs.removeAll { $0 == packID }
        }
    }

    public mutating func setFavorite(_ isFavorite: Bool, stickerID: String) {
        if isFavorite {
            guard !favoriteStickerIDs.contains(stickerID) else { return }
            favoriteStickerIDs.append(stickerID)
        } else {
            favoriteStickerIDs.removeAll { $0 == stickerID }
        }
    }

    public mutating func recordUse(stickerID: String, limit: Int = 50) {
        guard limit > 0 else {
            recentStickerIDs = []
            return
        }
        recentStickerIDs.removeAll { $0 == stickerID }
        recentStickerIDs.insert(stickerID, at: 0)
        if recentStickerIDs.count > limit {
            recentStickerIDs.removeSubrange(limit..<recentStickerIDs.count)
        }
    }

    private static func uniquePreservingOrder(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
}
