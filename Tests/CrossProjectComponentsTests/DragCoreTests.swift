import CoreGraphics
import XCTest
@testable import CrossProjectComponents

final class DragCoreTests: XCTestCase {
    func testPointTranslationPreservesGrabOffset() {
        let result = DragCore.translated(
            CGPoint(x: 100, y: 40),
            by: CGSize(width: 12, height: -6)
        )
        XCTAssertEqual(result, CGPoint(x: 112, y: 34))
    }

    func testPointTranslationAccountsForCanvasZoom() {
        let result = DragCore.translated(
            CGPoint(x: 100, y: 40),
            by: CGSize(width: 20, height: 10),
            scale: 2
        )
        XCTAssertEqual(result, CGPoint(x: 110, y: 45))
    }

    func testTimelineTranslationUsesFixedStartAndCumulativeDelta() {
        let firstUpdate = DragCore.translated(
            2.0, horizontalTranslation: 12, trackWidth: 240, visibleUnits: 8
        )
        let repeatedUpdate = DragCore.translated(
            2.0, horizontalTranslation: 12, trackWidth: 240, visibleUnits: 8
        )
        XCTAssertEqual(firstUpdate, 2.4, accuracy: 0.000001)
        XCTAssertEqual(repeatedUpdate, firstUpdate, accuracy: 0.000001)
    }

    func testIncrementalDeltaConvertsCumulativeTranslations() {
        let previous = CGSize(width: 8, height: -3)
        let current = CGSize(width: 13, height: 5)
        XCTAssertEqual(DragCore.incrementalDelta(from: previous, to: current), CGSize(width: 5, height: 8))
        XCTAssertEqual(DragCore.incrementalDelta(from: current, to: current), .zero)
    }

    func testTimelineTranslationHandlesZeroWidthAndClamping() {
        let result = DragCore.translated(
            1.0, horizontalTranslation: 10, trackWidth: 0, visibleUnits: 8
        )
        XCTAssertTrue(result.isFinite)
        XCTAssertEqual(DragCore.clamped(-1, to: 0...5), 0)
        XCTAssertEqual(DragCore.clamped(6, to: 0...5), 5)
    }
}
