import XCTest
@testable import ImgPolaroid

final class PolaroidRotationMathTests: XCTestCase {
    func testNoMovementKeepsStartingAngle() {
        let pivot = CGPoint(x: 100, y: 100)
        let finger = CGPoint(x: 40, y: 20)
        let start = PolaroidRotationMath.polarAngle(point: finger, center: pivot)
        XCTAssertEqual(27 + PolaroidRotationMath.shortestAngularDelta(from: start, to: start), 27, accuracy: 0.0001)
    }

    func testPointerAngleDeterminesRotationAroundCardCenter() {
        let pivot = CGPoint(x: 200, y: 200)
        let startPoint = CGPoint(x: 300, y: 200)
        let startPointerAngle = PolaroidRotationMath.polarAngle(point: startPoint, center: pivot)

        for degrees in [30.0, 90.0, 180.0, -90.0] {
            let radians = degrees * .pi / 180
            let currentPoint = CGPoint(x: pivot.x + 100 * cos(radians), y: pivot.y + 100 * sin(radians))
            let currentPointerAngle = PolaroidRotationMath.polarAngle(point: currentPoint, center: pivot)
            XCTAssertEqual(
                PolaroidRotationMath.shortestAngularDelta(from: startPointerAngle, to: currentPointerAngle),
                degrees == -90 ? -90 : degrees,
                accuracy: 0.001
            )
        }
    }

    func testAngularDeltaRemainsContinuousAcrossPiBoundary() {
        let pivot = CGPoint.zero
        let previous = CGPoint(x: -100, y: -0.1)
        let current = CGPoint(x: -100, y: 0.1)
        let start = PolaroidRotationMath.polarAngle(point: previous, center: pivot)
        let end = PolaroidRotationMath.polarAngle(point: current, center: pivot)
        XCTAssertLessThan(abs(PolaroidRotationMath.shortestAngularDelta(from: start, to: end)), 1)
    }

}
