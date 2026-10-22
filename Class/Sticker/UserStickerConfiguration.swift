import Foundation

/// User-owned sticker preferences. This does not contain or mutate public
/// library metadata; it only stores references and presentation preferences.
public struct UserStickerConfiguration: Codable, Hashable, Sendable {
    /// Selected sticker pack IDs in the exact order shown in the keyboard.
    public var selectedPackIDs: [String]
    public var favoriteStickerIDs: [String]
    /// Most recently used sticker IDs, newest first.
    public var recentStickerIDs: [String]

    public init(
        selectedPackIDs: [String] = [],
        favoriteStickerIDs: [String] = [],
        recentStickerIDs: [String] = []
    ) {
        self.selectedPackIDs = Self.uniquePreservingOrder(selectedPackIDs)
        self.favoriteStickerIDs = Self.uniquePreservingOrder(favoriteStickerIDs)
        self.recentStickerIDs = Self.uniquePreservingOrder(recentStickerIDs)
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
