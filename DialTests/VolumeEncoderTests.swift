import XCTest
@testable import Dial

final class VolumeEncoderTests: XCTestCase {
    func testParkedAlwaysOneStep() {
        XCTAssertEqual(VolumeEncoder.steps(forDelta: 0.5, parked: true), 1)
        XCTAssertEqual(VolumeEncoder.steps(forDelta: 0.01, parked: true), 1)
    }

    func testUnparkedMergedClickRoundsToTwoSteps() {
        XCTAssertEqual(VolumeEncoder.steps(forDelta: 0.118, parked: false), 2)
    }

    func testUnparkedMinimumOneStep() {
        XCTAssertEqual(VolumeEncoder.steps(forDelta: 0.01, parked: false), 1)
    }

    func testUnparkedHalfStepRoundsUp() {
        XCTAssertEqual(VolumeEncoder.steps(forDelta: 0.034, parked: false), 1)
    }
}
