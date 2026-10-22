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

    func testMutatingRadiusCannotMakeItNegative() {
        var shape = MessageBubbleShape(cornerRadius: 12)
        shape.cornerRadius = -8

        XCTAssertEqual(shape.cornerRadius, 0)
        XCTAssertTrue(shape.path(in: bounds).contains(CGPoint(x: 1, y: 1)))
    }
}
