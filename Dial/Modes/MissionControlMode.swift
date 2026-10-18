import AppKit

/// The first turn opens Mission Control; later turns send arrow keys to move
/// between windows, and press sends Return to bring one forward. Whether the
/// arrows move the selection in native Mission Control is Phase 4's test; the
/// fallback picker comes then if they don't.
final class MissionControlMode: Mode {
    let id = ModeID.missionControl
    var onReadingChange: (() -> Void)?

    private static let app = URL(fileURLWithPath: "/System/Applications/Mission Control.app")
    private var isOpen = false
    private var tally = StepTally()

    var reading: HUDReading {
        guard isOpen else { return HUDReading(level: nil, text: "Turn to open") }
        return HUDReading(level: nil, text: tally.net == 0 ? "Open" : tally.text(forward: "Window →", backward: "← Window"))
    }

    func turn(_ steps: Int) {
        if !isOpen {
            open()
            return
        }
        tally.add(steps)
        KeyEmitter.post(steps: steps, forward: KeyEmitter.right, backward: KeyEmitter.left)
    }

    func press() -> String {
        guard isOpen else {
            open()
            return "Open"
        }
        KeyEmitter.post(KeyEmitter.returnKey)
        isOpen = false
        return "Bring forward"
    }

    func deactivate() {
        if isOpen {
            KeyEmitter.post(KeyEmitter.escape)
            isOpen = false
        }
    }

    private func open() {
        NSWorkspace.shared.openApplication(at: Self.app, configuration: NSWorkspace.OpenConfiguration())
        isOpen = true
        tally = StepTally()
        log("mode", "Mission Control: opened")
    }
}
