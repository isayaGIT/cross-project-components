import SwiftUI
import XCTest
@testable import ScreenMiniature

final class ScreenMiniatureTests: XCTestCase {
    func testCanConstructMiniatureWithFixedSourceAndTargetSizes() {
        let view = ScreenMiniature(
            sourceSize: CGSize(width: 390, height: 844),
            size: CGSize(width: 117, height: 253.2)
        ) {
            Text("Preview")
        }
        XCTAssertNotNil(view)
    }
}
