import XCTest
@testable import Dial

final class DialModelTests: XCTestCase {
    private func makeModel() -> DialModel {
        DialModel(settings: DialSettings(order: ModeID.allCases, disabled: []))
    }

    func testStartsAtRestPointingAtVolume() {
        let model = makeModel()
        XCTAssertEqual(model.phase, .rest)
        XCTAssertEqual(model.selectedMode, .volume)
        XCTAssertEqual(model.highlightAngle, DialGeometry.centreAngle(0), accuracy: 0.001)
    }

    func testDoublePressPicksAndPressEntersAMode() {
        let model = makeModel()
        model.handle(.doublePress, from: "hotkey")
        XCTAssertTrue(model.isPicking)
        model.handle(.turn(1), from: "hotkey")
        XCTAssertEqual(model.selectedMode, .brightness)
        model.handle(.press, from: "hotkey")
        XCTAssertEqual(model.phase, .inMode(.brightness))
    }

    func testTurningAllTheWayAroundAccumulatesTheAngle() {
        let model = makeModel()
        model.handle(.doublePress, from: "hotkey")
        for _ in 0..<9 { model.handle(.turn(1), from: "hotkey") }
        XCTAssertEqual(model.selectedMode, .volume)
        let expected = DialGeometry.centreAngle(0)
            + 9 * DialGeometry.segmentDegrees
            + DialGeometry.ringGapDegrees
        XCTAssertEqual(model.highlightAngle, expected, accuracy: 0.001)
    }

    func testBackwardStepCrossesTheGap() {
        let model = makeModel()
        model.handle(.doublePress, from: "hotkey")
        model.handle(.turn(-1), from: "hotkey")
        XCTAssertEqual(model.selectedMode, .slides)
        let expected = DialGeometry.centreAngle(0)
            - DialGeometry.segmentDegrees
            - DialGeometry.ringGapDegrees
        XCTAssertEqual(model.highlightAngle, expected, accuracy: 0.001)
    }

    func testEnabledModesFallsBackToVolumeWhenAllDisabled() {
        let model = DialModel(settings: DialSettings(order: ModeID.allCases, disabled: Set(ModeID.allCases)))
        XCTAssertEqual(model.selectedMode, .volume)
        XCTAssertEqual(model.highlightAngle, DialGeometry.centreAngle(0), accuracy: 0.001)
        XCTAssertEqual(model.phase, .rest)
    }

    func testTurningOffTheActiveModeReturnsToRest() {
        let model = makeModel()
        model.handle(.doublePress, from: "hotkey")
        model.handle(.press, from: "hotkey")
        XCTAssertEqual(model.phase, .inMode(.volume))
        var settings = DialSettings(order: ModeID.allCases, disabled: [])
        settings.setEnabled(false, for: .volume)
        model.apply(settings)
        XCTAssertEqual(model.phase, .rest)
        XCTAssertEqual(model.selectedMode, .brightness)
    }
}
