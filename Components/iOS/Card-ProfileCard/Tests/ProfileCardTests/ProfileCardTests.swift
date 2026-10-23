import XCTest
import SwiftUI
@testable import ProfileCard

final class ProfileCardTests: XCTestCase {
    func testProfileStoresCommonPersonAndCharacterFields() {
        let profile = ProfileCard.Profile(
            name: "林知夏",
            signature: "把日常过成喜欢的样子"
        )
        XCTAssertEqual(profile.name, "林知夏")
        XCTAssertEqual(profile.signature, "把日常过成喜欢的样子")
        XCTAssertNil(profile.profileImage)
        XCTAssertNil(profile.profileBackgroundImage)
        XCTAssertNil(profile.cardBackgroundImage)
    }

    func testStyleClampsInvalidDimensionsAndFontSizes() {
        let style = ProfileCard.Style(
            nameFontSize: 0,
            signatureFontSize: -1,
            cornerRadius: -4,
            coverHeight: -2,
            avatarSize: 0
        )
        XCTAssertEqual(style.nameFontSize, 1)
        XCTAssertEqual(style.signatureFontSize, 1)
        XCTAssertEqual(style.cornerRadius, 0)
        XCTAssertEqual(style.coverHeight, 0)
        XCTAssertEqual(style.avatarSize, 1)
    }
}
