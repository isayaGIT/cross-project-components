import Foundation
import XCTest
@testable import StickerData

final class StickerDataTests: XCTestCase {
    func testConfigurationKeepsPackOrderAndPreventsDuplicates() {
        var configuration = UserStickerConfiguration(selectedPackIDs: ["animals", "food", "animals"])
        XCTAssertEqual(configuration.selectedPackIDs, ["animals", "food"])

        configuration.movePack(from: 0, to: 1)
        XCTAssertEqual(configuration.selectedPackIDs, ["food", "animals"])

        configuration.removePack(id: "food")
        XCTAssertEqual(configuration.selectedPackIDs, ["animals"])
    }

    func testRecentStickersAreUniqueNewestFirstAndBounded() {
        var configuration = UserStickerConfiguration()
        configuration.recordUse(stickerID: "cat", limit: 2)
        configuration.recordUse(stickerID: "dog", limit: 2)
        configuration.recordUse(stickerID: "cat", limit: 2)

        XCTAssertEqual(configuration.recentStickerIDs, ["cat", "dog"])
    }

    func testModelsRoundTripThroughCodable() throws {
        let sticker = Sticker(id: "cat-wave", packID: "animals", assetID: "cat-wave-image", tags: ["cat", "hello"])
        let data = try JSONEncoder().encode(sticker)
        let decoded = try JSONDecoder().decode(Sticker.self, from: data)
        XCTAssertEqual(decoded, sticker)
    }

    func testPackDeduplicatesStickerIDsWithoutChangingOrder() {
        let pack = StickerPack(id: "animals", name: "Animals", stickerIDs: ["cat", "dog", "cat"])
        XCTAssertEqual(pack.stickerIDs, ["cat", "dog"])
    }

    func testCatalogDeduplicatesPackIDsWithoutChangingOrder() {
        let catalog = StickerLibrary(id: "community", name: "Community", packIDs: ["animals", "food", "animals"])
        XCTAssertEqual(catalog.packIDs, ["animals", "food"])
    }
}

