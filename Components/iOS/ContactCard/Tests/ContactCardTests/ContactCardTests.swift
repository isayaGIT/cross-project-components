import XCTest
import SwiftUI
@testable import ContactCard

final class ContactCardTests: XCTestCase {
    func testProfileKeepsOptionalCompanionDetails() {
        let profile = ContactCard.Profile(
            name: "林知夏",
            subtitle: "AI 恋人",
            bio: "喜欢深夜聊天",
            isOnline: true,
            relationshipLabel: "相识 28 天",
            tags: ["温柔", "傲娇"],
            stats: [.init(value: "28 天", label: "相伴")]
        )

        XCTAssertEqual(profile.name, "林知夏")
        XCTAssertEqual(profile.subtitle, "AI 恋人")
        XCTAssertTrue(profile.isOnline)
        XCTAssertEqual(profile.tags.count, 2)
        XCTAssertEqual(profile.stats.first?.value, "28 天")
    }

    func testStyleClampsCornerRadiusAndPadding() {
        let style = ContactCard.Style(cornerRadius: 2, horizontalPadding: 0)
        XCTAssertEqual(style.cornerRadius, 12)
        XCTAssertEqual(style.horizontalPadding, 12)
    }
}
