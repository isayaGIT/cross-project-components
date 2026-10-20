import XCTest
@testable import CrossProjectComponents

final class FilmstripMetricsTests: XCTestCase {
    func testPixelScrollIsContinuousAcrossFrameBoundaries() {
        let width: CGFloat = 510, frame: CGFloat = 54, gap: CGFloat = 3, count = 11
        XCTAssertEqual(FilmstripMetrics.maxScrollOffset(width: width, itemCount: count, frameWidth: frame, gap: gap), 114, accuracy: 0.001)
        XCTAssertEqual(FilmstripMetrics.scrollOffset(progress: 0.5, width: width, itemCount: count, frameWidth: frame, gap: gap), 57, accuracy: 0.001)
        for offset: CGFloat in [0, 0.5, 28.5, 56.9, 57, 57.1, 85.5, 113.9, 114] {
            let first = FilmstripMetrics.firstVisibleIndex(scrollOffset: offset, frameWidth: frame, gap: gap, itemCount: count)
            let partial = FilmstripMetrics.partialFrameOffset(scrollOffset: offset, frameWidth: frame, gap: gap)
            XCTAssertEqual(CGFloat(first) * (frame + gap) + partial, offset, accuracy: 0.001)
            XCTAssertGreaterThanOrEqual(partial, 0); XCTAssertLessThan(partial, frame + gap)
        }
    }
    func testDraggingSelectsEveryImageInOrder() {
        let width: CGFloat = 510, frame: CGFloat = 54, gap: CGFloat = 3, count = 11
        let indices = (Array(stride(from: CGFloat(0), through: width, by: 10)) + [width]).map { x in
            let p = min(max(x / width, 0), 1)
            let offset = FilmstripMetrics.scrollOffset(progress: p, width: width, itemCount: count, frameWidth: frame, gap: gap)
            return FilmstripMetrics.selectedIndex(contentX: x + offset, itemCount: count, frameWidth: frame, gap: gap)
        }
        XCTAssertEqual(indices.first, 0); XCTAssertEqual(indices.last, count - 1)
        XCTAssertEqual(indices, indices.sorted()); XCTAssertEqual(Set(indices), Set(0..<count))
    }
    func testEmptyAndShortCollectionsAreSafe() {
        XCTAssertEqual(FilmstripMetrics.contentWidth(itemCount: 0, frameWidth: 54, gap: 3), 0)
        XCTAssertEqual(FilmstripMetrics.visibleCount(width: 500, frameWidth: 54, gap: 3, itemCount: 0), 0)
        XCTAssertEqual(FilmstripMetrics.maxScrollOffset(width: 500, itemCount: 2, frameWidth: 54, gap: 3), 0)
    }
}
