import Foundation

/// Moves between desktops with the user's "Move left/right a space"
/// shortcuts; press shows the desktop.
final class DesktopsMode: Mode {
    let id = ModeID.desktops
    var onReadingChange: (() -> Void)?

    /// Spaces slide for a moment before the new one counts as current.
    private static let readBackDelay: TimeInterval = 0.45
    private var lastDirection = 0
    private var shortcutsOff = false

    var reading: HUDReading {
        if shortcutsOff { return HUDReading(level: nil, text: "Turn on Space shortcuts") }
        if let position = Spaces.position { return HUDReading(level: nil, text: "\(position.current) / \(position.count)") }
        return HUDReading(level: nil, text: lastDirection > 0 ? "Next →" : lastDirection < 0 ? "← Previous" : "—")
    }

    func activate() {
        checkShortcuts()
    }

    func turn(_ steps: Int) {
        lastDirection = steps > 0 ? 1 : -1
        let hotKey: SymbolicHotKey = steps > 0 ? .moveRightASpace : .moveLeftASpace
        checkShortcuts()
        guard hotKey.isEnabled else { return }
        for _ in 0..<abs(steps) { KeyEmitter.post(hotKey.shortcut) }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.readBackDelay) { [weak self] in
            self?.onReadingChange?()
        }
    }

    func press() -> String {
        let hotKey = SymbolicHotKey.showDesktop
        guard hotKey.isEnabled else {
            log("mode", "Desktops: the Show Desktop shortcut is off in Keyboard Shortcuts → Mission Control")
            return "Show Desktop is off"
        }
        KeyEmitter.post(hotKey.shortcut)
        return "Show desktop"
    }

    private func checkShortcuts() {
        SymbolicHotKey.reload()
        let off = !SymbolicHotKey.moveLeftASpace.isEnabled || !SymbolicHotKey.moveRightASpace.isEnabled
        if off && !shortcutsOff {
            log("mode", "Desktops: turn on \"Move left a space\" and \"Move right a space\" in System Settings → Keyboard → Keyboard Shortcuts → Mission Control")
        }
        shortcutsOff = off
    }
}
