import XCTest
@testable import Animated

final class AnimatedTests: XCTestCase {
    func testPressedDownConfigurationClampsScale() {
        XCTAssertEqual(PressedDownConfiguration(scale: 2).scale, 1)
        XCTAssertEqual(PressedDownConfiguration(scale: 0.1).scale, 0.5)
    }

    func testDragToDismissStyleStoresConfiguration() {
        let style = DragToDismiss.Style(scrimOpacity: 0.7, shrink: 0.2, hint: "Release to close")

        XCTAssertEqual(style.scrimOpacity, 0.7, accuracy: 0.001)
        XCTAssertEqual(style.shrink, 0.2, accuracy: 0.001)
        XCTAssertEqual(style.hint, "Release to close")
    }

    func testPopInInterpolationClampsProgressToItsEndpoints() {
        let source = CGRect(x: 12, y: 24, width: 80, height: 120)
        let target = CGRect(x: 0, y: 0, width: 390, height: 844)

        XCTAssertEqual(interpolatePopInRect(from: source, to: target, progress: -1), source)
        XCTAssertEqual(interpolatePopInRect(from: source, to: target, progress: 0), source)
        XCTAssertEqual(interpolatePopInRect(from: source, to: target, progress: 1), target)
        XCTAssertEqual(interpolatePopInRect(from: source, to: target, progress: 2), target)
    }

    func testAspectFitDestinationRectKeepsImageRatio() {
        let fitted = aspectFitRect(in: CGRect(x: 0, y: 0, width: 390, height: 844), aspectRatio: 2.0 / 3.0)
        XCTAssertEqual(fitted.width, 390, accuracy: 0.001)
        XCTAssertEqual(fitted.height, 585, accuracy: 0.001)
        XCTAssertEqual(fitted.minY, 129.5, accuracy: 0.001)
        XCTAssertEqual(fitted.midX, 195, accuracy: 0.001)
    }

    func testPopInInterpolatesAllFourEdgesIndependently() {
        let source = CGRect(x: 30, y: 520, width: 120, height: 180)
        let target = CGRect(x: 0, y: 0, width: 390, height: 844)

        let halfway = interpolatePopInRect(from: source, to: target, progress: 0.5)

        XCTAssertEqual(halfway.minX, 15, accuracy: 0.001)
        XCTAssertEqual(halfway.minY, 260, accuracy: 0.001)
        XCTAssertEqual(halfway.maxX, 270, accuracy: 0.001)
        XCTAssertEqual(halfway.maxY, 772, accuracy: 0.001)
    }
}
