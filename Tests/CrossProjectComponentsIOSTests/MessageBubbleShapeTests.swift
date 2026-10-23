import SwiftUI
import XCTest

@testable import CrossProjectComponentsIOS

final class MessageBubbleShapeTests: XCTestCase {
    private let bounds = CGRect(x: 0, y: 0, width: 100, height: 60)

    func testBottomTrailingCornerIsSquareOnlyWhenSelected() {
        let square = MessageBubbleShape(cornerRadius: 18, sharpCorner: .bottomTrailing)
            .path(in: bounds)
        let rounded = MessageBubbleShape(cornerRadius: 18, sharpCorner: .none)
            .path(in: bounds)

        let nearBottomTrailing = CGPoint(x: 99, y: 59)
        XCTAssertTrue(square.contains(nearBottomTrailing))
        XCTAssertFalse(rounded.contains(nearBottomTrailing))
    }

    func testEachCornerCanBeMadeSquare() {
        let probes: [(MessageBubbleShape.SharpCorner, CGPoint)] = [
            (.topLeading, CGPoint(x: 1, y: 1)),
            (.topTrailing, CGPoint(x: 99, y: 1)),
            (.bottomLeading, CGPoint(x: 1, y: 59)),
            (.bottomTrailing, CGPoint(x: 99, y: 59)),
        ]

        for (corner, point) in probes {
            let squarePath = MessageBubbleShape(cornerRadius: 18, sharpCorner: corner).path(in: bounds)
            let roundedPath = MessageBubbleShape(cornerRadius: 18, sharpCorner: .none).path(in: bounds)
            XCTAssertTrue(squarePath.contains(point), "Expected \(corner) to be square")
            XCTAssertFalse(roundedPath.contains(point), "Expected \(corner) to be rounded in the baseline shape")
        }
    }

    func testNegativeRadiusIsClampedToZero() {
        let path = MessageBubbleShape(cornerRadius: -10, sharpCorner: .none).path(in: bounds)
        XCTAssertTrue(path.contains(CGPoint(x: 1, y: 1)))
        XCTAssertTrue(path.contains(CGPoint(x: 99, y: 59)))
    }

    func testRadiusIsClampedToHalfTheSmallerDimension() {
        let path = MessageBubbleShape(cornerRadius: 500, sharpCorner: .none).path(in: bounds)
        XCTAssertFalse(path.contains(CGPoint(x: 1, y: 1)))
        XCTAssertTrue(path.contains(CGPoint(x: 50, y: 30)))
    }

    func testRoundedTailExtendsToLeadingAndTrailingEdges() {
        let leading = MessageBubbleShape(
            cornerRadius: 16, sharpCorner: .bottomLeading, style: .roundedTail
        ).path(in: bounds)
        let trailing = MessageBubbleShape(
            cornerRadius: 16, sharpCorner: .bottomTrailing, style: .roundedTail
        ).path(in: bounds)

        XCTAssertTrue(leading.contains(CGPoint(x: 13, y: 59)))
        XCTAssertTrue(trailing.contains(CGPoint(x: 87, y: 59)))
        XCTAssertLessThan(leading.boundingRect.minX, bounds.minX)
        XCTAssertGreaterThan(trailing.boundingRect.maxX, bounds.maxX)
    }

    func testRoundedTailFallsBackForUnsupportedCorner() {
        let actual = MessageBubbleShape(
            cornerRadius: 16, sharpCorner: .topLeading, style: .roundedTail
        ).path(in: bounds)
        let expected = MessageBubbleShape(
            cornerRadius: 16, sharpCorner: .topLeading, style: .tailLess
        ).path(in: bounds)

        XCTAssertEqual(actual.boundingRect, expected.boundingRect)
    }

    func testTailLessStylePreservesExistingShapeGeometry() {
        let actual = MessageBubbleShape(
            cornerRadius: 18, sharpCorner: .bottomTrailing, style: .tailLess
        ).path(in: bounds)
        let expected = MessageBubbleShape(
            cornerRadius: 18, sharpCorner: .bottomTrailing
        ).path(in: bounds)

        XCTAssertEqual(actual.boundingRect, expected.boundingRect)
        XCTAssertTrue(actual.contains(CGPoint(x: 99, y: 59)))
    }

    func testEnhancedShapeUsesSingleContourWithMirroredTails() {
        let leading = RoundedRectSmoothed(cornerRadius: 16, tail: .leading, tailWidth: 6, tailHeight: 10).path(in: bounds)
        let trailing = RoundedRectSmoothed(cornerRadius: 16, tail: .trailing, tailWidth: 6, tailHeight: 10).path(in: bounds)

        XCTAssertGreaterThan(trailing.boundingRect.maxX, bounds.maxX - 0.5)
        XCTAssertLessThan(leading.boundingRect.minX, bounds.minX + 0.5)
        XCTAssertEqual(trailing.boundingRect.width, leading.boundingRect.width, accuracy: 0.01)
        XCTAssertEqual(trailing.boundingRect.height, leading.boundingRect.height, accuracy: 0.01)
        XCTAssertTrue(trailing.contains(CGPoint(x: 50, y: 30)))
        XCTAssertTrue(leading.contains(CGPoint(x: 50, y: 30)))
    }

    func testEnhancedShapeWithoutTailUsesFullHeight() {
        let path = RoundedRectSmoothed(cornerRadius: 16).path(in: bounds)
        XCTAssertEqual(path.boundingRect.maxY, bounds.maxY, accuracy: 0.01)
        XCTAssertTrue(path.contains(CGPoint(x: 50, y: 59)))
    }


    func testNineSliceAdjustmentRoundTripsLegacyHexEncoding() {
        let adjustment = BubbleNineSliceAdjustment(encoded: 0x012045)
        XCTAssertNotNil(adjustment)
        XCTAssertEqual(adjustment?.encoded, 0x012045)
        XCTAssertEqual(adjustment?.scaleZ, .addDifference)
        XCTAssertEqual(adjustment?.scaleY, .subtractDifference)
        XCTAssertEqual(adjustment?.scaleX, .multiplyRatio)
        XCTAssertEqual(adjustment?.positionY, .adjustImageScale)
        XCTAssertEqual(adjustment?.positionX, .adjustImageScale)
        XCTAssertEqual(adjustment?.encoded, 73_797)
    }

    func testNineSliceRejectsUnknownOperations() {
        XCTAssertNil(BubbleNineSliceAdjustment(encoded: 0x067000))
        XCTAssertNil(BubbleNineSliceAdjustment(encoded: 0x1_000000))
    }

    func testNineSliceOperationsUseDocumentedFormulas() {
        XCTAssertEqual(BubbleNineSliceOperation.addDifference.apply(value: 10, difference: 4, ratio: 2, sourceDimension: 20), 14)
        XCTAssertEqual(BubbleNineSliceOperation.subtractHalfDifference.apply(value: 10, difference: 4, ratio: 2, sourceDimension: 20), 8)
        XCTAssertEqual(BubbleNineSliceOperation.multiplyRatio.apply(value: 10, difference: 4, ratio: 2, sourceDimension: 20), 20)
        XCTAssertEqual(BubbleNineSliceOperation.adjustImageScale.apply(value: 100, difference: 20, ratio: 2, sourceDimension: 40), 150)
        XCTAssertEqual(BubbleNineSliceOperation.adjustImageScale.apply(value: 100, difference: 20, ratio: 2, sourceDimension: 0), 100)
    }

    func testNineSliceGridKeepsCornerInsetsAndExpandsCenter() {
        let grid = BubbleNineSliceGrid(
            sourceSize: CGSize(width: 100, height: 60),
            destinationSize: CGSize(width: 180, height: 100),
            insets: .init(top: 12, leading: 16, bottom: 12, trailing: 16)
        )
        XCTAssertEqual(grid.rect(for: .topLeading), CGRect(x: 0, y: 0, width: 16, height: 12))
        XCTAssertEqual(grid.rect(for: .topTrailing), CGRect(x: 164, y: 0, width: 16, height: 12))
        XCTAssertEqual(grid.rect(for: .center), CGRect(x: 16, y: 12, width: 148, height: 76))
        XCTAssertEqual(grid.rect(for: .bottomTrailing), CGRect(x: 164, y: 88, width: 16, height: 12))
    }


    func testMutatingRadiusCannotMakeItNegative() {
        var shape = MessageBubbleShape(cornerRadius: 12)
        shape.cornerRadius = -8

        XCTAssertEqual(shape.cornerRadius, 0)
        XCTAssertTrue(shape.path(in: bounds).contains(CGPoint(x: 1, y: 1)))
    }
}
