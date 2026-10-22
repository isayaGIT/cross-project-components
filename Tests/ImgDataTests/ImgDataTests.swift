import Foundation
import XCTest
@testable import ImgData

final class ImgDataTests: XCTestCase {
    func testVariantLookupAndPreviewFallback() {
        let thumbnail = ImgVariant(kind: .thumbnail, url: URL(string: "https://example.com/thumb.webp")!)
        let original = ImgVariant(kind: .original, url: URL(string: "https://example.com/original.jpg")!)
        let image = Img(id: "photo-1", variants: [thumbnail, original])

        XCTAssertEqual(image.variant(for: .thumbnail), thumbnail)
        XCTAssertEqual(image.bestPreviewVariant, thumbnail)
        XCTAssertEqual(image.originalVariant, original)
    }

    func testPreviewIsPreferredAndFallsBackWhenUnavailable() {
        let thumbnail = ImgVariant(kind: .thumbnail, url: URL(string: "https://example.com/thumb.webp")!)
        let preview = ImgVariant(kind: .preview, url: URL(string: "https://example.com/preview.webp")!)
        XCTAssertEqual(Img(id: "a", variants: [thumbnail, preview]).bestPreviewVariant, preview)
        XCTAssertEqual(Img(id: "b", variants: [thumbnail]).bestPreviewVariant, thumbnail)
        XCTAssertNil(Img(id: "empty").bestPreviewVariant)
    }

    func testDuplicateVariantKindsKeepFirstOccurrenceAndOrder() {
        let first = ImgVariant(kind: .preview, url: URL(string: "https://example.com/first.webp")!)
        let duplicate = ImgVariant(kind: .preview, url: URL(string: "https://example.com/second.webp")!)
        let thumbnail = ImgVariant(kind: .thumbnail, url: URL(string: "https://example.com/thumb.webp")!)
        let image = Img(id: "photo", variants: [first, duplicate, thumbnail])

        XCTAssertEqual(image.variants, [first, thumbnail])
        XCTAssertEqual(image.variant(for: .preview), first)
    }

    func testInvalidMetadataIsNormalizedToNil() {
        let variant = ImgVariant(
            kind: .original,
            url: URL(string: "https://example.com/original.jpg")!,
            pixelWidth: 0,
            pixelHeight: -10,
            byteCount: -1
        )

        XCTAssertNil(variant.pixelWidth)
        XCTAssertNil(variant.pixelHeight)
        XCTAssertNil(variant.byteCount)
    }

    func testModelsRoundTripThroughCodable() throws {
        let image = Img(
            id: "photo-42",
            variants: [
                ImgVariant(
                    kind: .original,
                    url: URL(string: "https://example.com/photo.jpg")!,
                    pixelWidth: 8000,
                    pixelHeight: 6000,
                    byteCount: 25_000_000,
                    mediaType: .jpeg
                )
            ],
            altText: "A mountain"
        )

        let data = try JSONEncoder().encode(image)
        let decoded = try JSONDecoder().decode(Img.self, from: data)
        XCTAssertEqual(decoded, image)
    }
}
