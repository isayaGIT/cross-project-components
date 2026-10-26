import XCTest
@testable import CrossProjectComponentsIOS

final class VoiceMessageTests: XCTestCase {
    func testBothDisplayModesAreAvailable() {
        XCTAssertEqual(VoiceMessageDisplayMode.allCases, [.compact, .waveform])
    }

    func testDisplayModesHaveStableIdentifiers() {
        XCTAssertEqual(VoiceMessageDisplayMode.compact.rawValue, "compact")
        XCTAssertEqual(VoiceMessageDisplayMode.waveform.rawValue, "waveform")
    }
}
