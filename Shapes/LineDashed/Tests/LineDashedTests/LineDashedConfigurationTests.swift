import XCTest
import SwiftUI
@testable import LineDashed

final class LineDashedConfigurationTests: XCTestCase {
    func testDefaults() {
        let value = DashedLineConfiguration()
        XCTAssertEqual(value.lineWidth, 2)
        XCTAssertEqual(value.dashLength, 8)
        XCTAssertEqual(value.dashSpacing, 4)
        XCTAssertEqual(value.cornerRadius, 1)
        XCTAssertEqual(value.closedPathMode, .evenlyDistributed)
    }

    func testInvalidValuesNormalizeSafely() {
        let value = DashedLineConfiguration(lineWidth: .nan, dashLength: -2, dashSpacing: -10, cornerRadius: .infinity)
        XCTAssertEqual(value.lineWidth, 0)
        XCTAssertEqual(value.dashLength, 0)
        XCTAssertEqual(value.dashSpacing, 0)
        XCTAssertEqual(value.cornerRadius, 0)
    }

    func testStraightPathProducesSegments() {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 10))
        path.addLine(to: CGPoint(x: 100, y: 10))
        let segments = DashedLinePathEngine().segments(path: path, configuration: .init(lineWidth: 4, dashLength: 10, dashSpacing: 5))
        XCTAssertEqual(segments.count, 7)
        XCTAssertEqual(segments.first?.length ?? 0, 10, accuracy: 0.001)
        XCTAssertEqual(segments.first?.center.y ?? 0, 10, accuracy: 0.001)
        XCTAssertEqual(segments.first?.angle ?? 0, 0, accuracy: 0.001)
    }

    func testEmptyPathProducesNoSegments() {
        XCTAssertTrue(DashedLinePathEngine().segments(path: Path(), configuration: .init()).isEmpty)
    }
}
