import XCTest
@testable import Dial

final class DialSettingsTests: XCTestCase {
    private let defaults = UserDefaults(suiteName: "DialSettingsTests")!

    override func tearDown() {
        defaults.removePersistentDomain(forName: "DialSettingsTests")
        super.tearDown()
    }

    func testMoveToFrontKeepsEveryMode() {
        var settings = DialSettings.standard
        settings.move(fromOffsets: IndexSet(integer: 2), toOffset: 0)
        XCTAssertEqual(settings.order, [.apps, .volume, .brightness, .missionControl, .desktops, .tabs, .scroll, .undoRedo, .slides])
    }

    func testMoveToTheEndAppends() {
        var settings = DialSettings.standard
        settings.move(fromOffsets: IndexSet(integer: 0), toOffset: 9)
        XCTAssertEqual(settings.order, Array(ModeID.allCases.dropFirst()) + [.volume])
    }

    func testLoadAppendsModesAddedSinceTheSave() {
        defaults.set(["volume", "apps"], forKey: "modeOrder")
        let loaded = DialSettings.load(from: defaults)
        XCTAssertEqual(Array(loaded.order.prefix(2)), [.volume, .apps])
        XCTAssertEqual(loaded.order.count, ModeID.allCases.count)
    }

    func testLoadIgnoresUnknownModes() {
        defaults.set(["volume", "teleport"], forKey: "modeOrder")
        let loaded = DialSettings.load(from: defaults)
        XCTAssertEqual(loaded.order.first, .volume)
        XCTAssertFalse(loaded.order.contains(where: { $0.rawValue == "teleport" }))
    }

    func testTheLastEnabledModeStaysOn() {
        var settings = DialSettings.standard
        for mode in ModeID.allCases where mode != .volume {
            settings.setEnabled(false, for: mode)
        }
        settings.setEnabled(false, for: .volume)
        XCTAssertEqual(settings.enabledModes, [.volume])
    }

    func testPressActionFallsBackWhenTheChoiceIsGone() {
        var settings = DialSettings.standard
        settings.setPressAction(.showDesktop, for: .volume)
        XCTAssertEqual(settings.pressAction(for: .volume), ModeID.volume.pressOptions[0])
    }

    func testSaveAndLoadRoundTrip() {
        var settings = DialSettings.standard
        settings.move(fromOffsets: IndexSet(integer: 2), toOffset: 0)
        settings.setEnabled(false, for: .tabs)
        settings.setPressAction(.mute, for: .volume)
        settings.save(to: defaults)
        XCTAssertEqual(DialSettings.load(from: defaults), settings)
    }
}
