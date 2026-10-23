import Foundation
import XCTest
@testable import InteractiveAssets

final class InteractiveAssetModelsTests: XCTestCase {
    func testManifestRoundTripsWithStableProtocolVersion() throws {
        let manifest = InteractiveAssetManifest(
            contentID: "cute-animals", contentType: .stickerPack, contentVersion: "3",
            files: [AssetFile(id: "cat-gif", fileName: "cat.gif", mediaType: "image/gif", byteCount: 1024, sha256: String(repeating: "a", count: 64))],
            metadataFileID: "pack-json"
        )
        let data = try JSONEncoder().encode(manifest)
        let decoded = try JSONDecoder().decode(InteractiveAssetManifest.self, from: data)
        XCTAssertEqual(decoded, manifest)
        XCTAssertEqual(decoded.protocolVersion, "1.0")
    }

    func testStickerLibraryRoundTripsPackCatalog() throws {
        let library = StickerLibraryDocument(id: "community", name: "Community Stickers", packIDs: ["animals", "food"], updatedAt: "2026-10-24T00:00:00Z")
        let data = try JSONEncoder().encode(library)
        let decoded = try JSONDecoder().decode(StickerLibraryDocument.self, from: data)
        XCTAssertEqual(decoded.packIDs, ["animals", "food"])
        XCTAssertEqual(decoded.updatedAt, "2026-10-24T00:00:00Z")
    }

    func testStickerPackReferencesIndependentMediaAndParameters() throws {
        let pack = StickerPackDocument(
            id: "animals", name: "Animals",
            stickers: [StickerEntry(id: "cat-wave", media: AssetReference(assetID: "cat-gif"), parameters: AssetReference(assetID: "cat-json"))]
        )
        let data = try JSONEncoder().encode(pack)
        let decoded = try JSONDecoder().decode(StickerPackDocument.self, from: data)
        XCTAssertEqual(decoded.stickers.first?.media.assetID, "cat-gif")
        XCTAssertEqual(decoded.stickers.first?.parameters?.assetID, "cat-json")
    }

    func testStandaloneStickerAllowsOptionalMetadata() throws {
        let data = Data("{\"protocolVersion\":\"1.0\",\"id\":\"cat-wave\",\"media\":{\"assetID\":\"cat-gif\"}}".utf8)
        let decoded = try JSONDecoder().decode(StickerDocument.self, from: data)
        XCTAssertEqual(decoded.id, "cat-wave")
        XCTAssertEqual(decoded.tags, [])
        XCTAssertNil(decoded.name)
    }

    func testBubbleAndFullscreenEnumsUseProtocolWireValues() throws {
        XCTAssertEqual(try JSONEncoder().encode(BubbleRenderer.ninePatchFrames), Data("\"nine-patch-frames\"".utf8))
        XCTAssertEqual(try JSONEncoder().encode(FullscreenRenderer.imageSequence), Data("\"image-sequence\"".utf8))
        XCTAssertEqual(try JSONEncoder().encode(DecorationPlacement.overlapping), Data("\"overlapping\"".utf8))
    }

    func testNinePatchStudioV1FormatRemainsCompatible() throws {
        let export = NinePatchAnimationExport(
            sourceFileName: "bubble.png", sourceWidth: 320, sourceHeight: 180,
            frameCount: 1, totalDuration: 0.12,
            frames: [NinePatchFrame(fileName: "frame_0000.png", duration: 0.12)],
            stretchInsets: SliceInsets(top: 24, left: 24, bottom: 24, right: 24),
            contentInsets: SliceInsets(top: 12, left: 14, bottom: 12, right: 14),
            integrationNote: "Keep frame names in the asset catalog."
        )
        let data = try JSONEncoder().encode(export)
        let decoded = try JSONDecoder().decode(NinePatchAnimationExport.self, from: data)
        XCTAssertEqual(decoded.format, "ninepatch-studio/animation-v1")
        XCTAssertEqual(decoded.frames.count, decoded.frameCount)
        XCTAssertEqual(decoded.integrationNote, "Keep frame names in the asset catalog.")
    }
}
