import XCTest
@testable import ImgPolaroid

final class PolaroidRotationMathTests: XCTestCase {
    private let center = CGPoint(x: 100, y: 100)

    func testNoMovementKeepsStartingAngleForBothCorners() {
        let left = CGPoint(x: 50, y: 30)
        let right = CGPoint(x: 150, y: 30)
        XCTAssertEqual(angle(start: 12, from: left, to: left, direction: .leftCorner), 12, accuracy: 0.0001)
        XCTAssertEqual(angle(start: 12, from: right, to: right, direction: .rightCorner), 12, accuracy: 0.0001)
    }

    func testLeftAndRightCornersTrackTheSamePhysicalRotationWithOppositeDirectionParameters() {
        let leftStart = CGPoint(x: 50, y: 30)
        let leftEnd = CGPoint(x: 56.2, y: 26.0)
        let rightStart = CGPoint(x: 150, y: 30)
        let rightEnd = CGPoint(x: 155.8, y: 34.6)

        let leftDelta = angle(start: 0, from: leftStart, to: leftEnd, direction: .leftCorner)
        let rightDelta = angle(start: 0, from: rightStart, to: rightEnd, direction: .rightCorner)
        XCTAssertEqual(leftDelta, -rightDelta, accuracy: 0.15)
        XCTAssertLessThan(leftDelta, 0)
        XCTAssertGreaterThan(rightDelta, 0)
    }

    func testRotationUsesPointerAngleRatherThanLinearTranslationScale() {
        let start = CGPoint(x: 50, y: 30)
        let end = CGPoint(x: 56.2, y: 26.0)
        let result = angle(start: 5, from: start, to: end, direction: .leftCorner)
        XCTAssertEqual(result, 0, accuracy: 0.15)
    }

    func testAngularDeltaRemainsContinuousAcrossPiBoundary() {
        let start = CGPoint(x: 99, y: 80)
        let end = CGPoint(x: 101, y: 80)
        let result = angle(start: 7, from: start, to: end, direction: .rightCorner)
        XCTAssertLessThan(abs(result - 7), 10)
    }

    private func angle(start: Double, from startPoint: CGPoint, to currentPoint: CGPoint, direction: PolaroidRotationDirection) -> Double {
        PolaroidRotationMath.angle(
            startingAt: start,
            startPoint: startPoint,
            currentPoint: currentPoint,
            center: center,
            direction: direction
        )
    }
}
