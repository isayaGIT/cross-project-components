import XCTest
@testable import Animated

final class AnimatedTests: XCTestCase {

    func testSwipeCancellationChoosesNearestDetent() {
        XCTAssertEqual(SwipeCancellation.target(offset: 50, leadingWidth: 80, trailingWidth: 120), 80)
        XCTAssertEqual(SwipeCancellation.target(offset: -80, leadingWidth: 80, trailingWidth: 120), -120)
        XCTAssertEqual(SwipeCancellation.target(offset: 20, leadingWidth: 80, trailingWidth: 120), 0)
    }

    func testSwipeOffsetPhysicsKeepsFingerTrackingInsideFreeRange() {
        XCTAssertEqual(
            SwipeOffsetPhysics.offset(72, hasActions: true, fullSwipeThreshold: 180, revealedWidth: 156),
            72,
            accuracy: 0.001
        )
        let resisted = SwipeOffsetPhysics.offset(260, hasActions: true, fullSwipeThreshold: 180, revealedWidth: 156)
        XCTAssertGreaterThan(resisted, 180)
        XCTAssertLessThan(resisted, 260)
    }

    func testFullSwipeTriggerUsesRowAndActionWidthThresholds() {
        XCTAssertEqual(FullSwipeTrigger.threshold(rowWidth: 300, tileWidth: 78), 180)
        XCTAssertTrue(FullSwipeTrigger.isTriggered(offset: -181, threshold: 180))
        XCTAssertFalse(FullSwipeTrigger.isTriggered(offset: 180, threshold: 180))
    }

    func testSwipeDismissalOnlyCarriesOutwardVelocity() {
        XCTAssertEqual(SwipeDismissalMotion.target(offset: -30, rowWidth: 320, fade: 20), -364)
        XCTAssertEqual(SwipeDismissalMotion.outwardVelocity(target: -364, velocity: 500), 0)
        XCTAssertEqual(SwipeDismissalMotion.outwardVelocity(target: -364, velocity: -500), -500)
    }

    func testMenuActivationClosesBeforeRunningAction() {
        var events: [String] = []
        SwipeMenuActivation.perform(close: { events.append("close") }, action: { events.append("action") })
        XCTAssertEqual(events, ["close", "action"])
    }

    func testPressedDownConfigurationClampsScale() {
        XCTAssertEqual(PressedDownConfiguration(scale: 2).scale, 1)
        XCTAssertEqual(PressedDownConfiguration(scale: 0.1).scale, 0.5)
    }

    func testElasticButtonConfigurationClampsInvalidAndOutOfRangeValues() {
        let configuration = ElasticButtonConfiguration(
            pressedScaleX: 2,
            pressedScaleY: .nan,
            pressDuration: -1,
            releaseDuration: 4,
            releaseBounce: 2
        )

        XCTAssertEqual(configuration.pressedScaleX, 1.2, accuracy: 0.001)
        XCTAssertEqual(configuration.pressedScaleY, 0.88, accuracy: 0.001)
        XCTAssertEqual(configuration.pressDuration, 0, accuracy: 0.001)
        XCTAssertEqual(configuration.releaseDuration, 2, accuracy: 0.001)
        XCTAssertEqual(configuration.releaseBounce, 1, accuracy: 0.001)
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
