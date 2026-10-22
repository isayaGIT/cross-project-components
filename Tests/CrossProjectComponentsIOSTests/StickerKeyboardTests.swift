import XCTest
@testable import CrossProjectComponentsIOS

final class StickerKeyboardTests: XCTestCase {
    func testStandardConfigurationHasExpectedLayoutContract() {
        let configuration = StickerKeyboard.Configuration.standard
        XCTAssertEqual(configuration.height, 286)
        XCTAssertEqual(configuration.columns, 5)
        XCTAssertEqual(StickerKeyboard.defaultHeight, configuration.height)
    }

    func testConfigurationClampsUnsafeLayoutValues() {
        let configuration = StickerKeyboard.Configuration(height: 20, columns: 1)
        XCTAssertEqual(configuration.height, 180)
        XCTAssertEqual(configuration.columns, 3)

        let wideConfiguration = StickerKeyboard.Configuration(height: 320, columns: 30)
        XCTAssertEqual(wideConfiguration.height, 320)
        XCTAssertEqual(wideConfiguration.columns, 10)
        XCTAssertEqual(configuration.stickerSize, 58)
        XCTAssertEqual(configuration.categoryBarHeight, 48)
    }
}
