import XCTest
@testable import ImgView

final class ImgViewImageTests: XCTestCase {
    func testImageKeepsOriginalAndPreviewURLs() throws {
        let original = try XCTUnwrap(URL(string: "https://example.test/original.jpg"))
        let preview = try XCTUnwrap(URL(string: "https://example.test/preview.jpg"))
        let image = ImgViewImage(id: "fixture", url: original, previewURL: preview)

        XCTAssertEqual(image.id, "fixture")
        XCTAssertEqual(image.url, original)
        XCTAssertEqual(image.previewURL, preview)
    }

    func testPreviewIsOptional() throws {
        let original = try XCTUnwrap(URL(string: "https://example.test/original.jpg"))
        let image = ImgViewImage(url: original)

        XCTAssertEqual(image.url, original)
        XCTAssertNil(image.previewURL)
    }
}
