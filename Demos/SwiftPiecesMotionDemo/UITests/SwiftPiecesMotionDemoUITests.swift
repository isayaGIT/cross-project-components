import XCTest

final class SwiftPiecesMotionDemoUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func testFlipCardCanFlip() {
        openDemo("flipCard")
        XCTAssertTrue(app.buttons["demo.flip-card.flip"].waitForExistence(timeout: 5))
        app.buttons["demo.flip-card.flip"].tap()
        XCTAssertTrue(app.staticTexts["Back face"].waitForExistence(timeout: 3))
    }

    func testParallaxCardActionResponds() {
        openDemo("parallaxCard")
        let count = app.staticTexts["demo.parallax-count"]
        XCTAssertTrue(count.waitForExistence(timeout: 5))
        let before = count.label
        let card = app.buttons["demo.parallax-card"]
        XCTAssertTrue(card.waitForExistence(timeout: 3))
        card.tap()
        XCTAssertNotEqual(count.label, before)
    }

    func testTextRevealCanReplayAndChangePreset() {
        openDemo("textReveal")
        let replay = app.buttons["demo.text-reveal.replay"]
        XCTAssertTrue(replay.waitForExistence(timeout: 5))
        replay.tap()
        let blur = app.buttons["Blur"]
        if blur.waitForExistence(timeout: 2) {
            blur.tap()
        }
        XCTAssertTrue(app.otherElements["demo.text-reveal"].exists || app.staticTexts["Good things take the time they need."].exists)
    }

    func testStatusMorphChangesState() {
        openDemo("statusMorph")
        let success = app.buttons["demo.status-morph.success"]
        XCTAssertTrue(success.waitForExistence(timeout: 5))
        success.tap()
        XCTAssertTrue(app.staticTexts["Success"].waitForExistence(timeout: 3))
    }

    func testDragToDismissCanRestore() {
        openDemo("dragToDismiss")
        let title = app.staticTexts["Hold. Pull. Let go."]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        let start = title.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = start.withOffset(CGVector(dx: 230, dy: 0))
        start.press(forDuration: 0.12, thenDragTo: end)
        let restore = app.buttons["demo.drag-dismiss.restore"]
        XCTAssertTrue(restore.waitForExistence(timeout: 5), "A long drag should invoke the dismiss callback")
        restore.tap()
        XCTAssertTrue(title.waitForExistence(timeout: 3))
    }

    func testDepthCarouselRespondsToSwipe() {
        openDemo("depthCarousel")
        let selection = app.staticTexts["demo.depth-carousel.selection"]
        XCTAssertTrue(selection.waitForExistence(timeout: 5))
        let before = selection.label
        let nextPage = app.otherElements["demo.depth-carousel.page.2"]
        XCTAssertTrue(nextPage.waitForExistence(timeout: 3))
        nextPage.tap()
        let changed = NSPredicate(format: "label != %@", before)
        expectation(for: changed, evaluatedWith: selection)
        waitForExpectations(timeout: 4)
    }

    func testSilkControlsAreInteractive() {
        openDemo("silk")
        let pause = app.switches["demo.silk.pause"]
        XCTAssertTrue(pause.waitForExistence(timeout: 5))
        pause.tap()
        app.buttons["demo.silk.tint.2"].tap()
        XCTAssertTrue(app.otherElements["demo.silk.preview"].exists)
    }

    private func openDemo(_ rawValue: String) {
        let row = app.buttons["demo.row.\(rawValue)"]
        if !row.exists { app.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Missing demo entry: \(rawValue)")
        row.tap()
    }
}
