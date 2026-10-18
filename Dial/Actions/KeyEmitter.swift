import CoreGraphics
import Carbon.HIToolbox

/// Posts key presses to the frontmost app. Needs Accessibility.
enum KeyEmitter {
    struct Shortcut: CustomStringConvertible {
        let keyCode: CGKeyCode
        let flags: CGEventFlags

        init(_ keyCode: Int, _ flags: CGEventFlags = []) {
            self.keyCode = CGKeyCode(keyCode)
            self.flags = flags
        }

        var description: String {
            var text = ""
            if flags.contains(.maskControl) { text += "⌃" }
            if flags.contains(.maskAlternate) { text += "⌥" }
            if flags.contains(.maskShift) { text += "⇧" }
            if flags.contains(.maskCommand) { text += "⌘" }
            return text + (Self.names[Int(keyCode)] ?? "key \(keyCode)")
        }

        private static let names: [Int: String] = [
            kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
            kVK_Tab: "⇥", kVK_Return: "↩", kVK_Escape: "⎋", kVK_ANSI_Z: "Z", kVK_ANSI_S: "S",
            kVK_ANSI_T: "T", kVK_ANSI_P: "P", kVK_F11: "F11",
        ]
    }

    static let left = Shortcut(kVK_LeftArrow)
    static let right = Shortcut(kVK_RightArrow)
    static let returnKey = Shortcut(kVK_Return)
    static let escape = Shortcut(kVK_Escape)

    private static let arrowKeys: Set<Int> = [kVK_LeftArrow, kVK_RightArrow, kVK_UpArrow, kVK_DownArrow]

    static func post(_ shortcut: Shortcut) {
        let source = CGEventSource(stateID: .hidSystemState)
        var flags = shortcut.flags
        // A real arrow key carries these; some shortcuts (switching Spaces)
        // only fire when they're present.
        if arrowKeys.contains(Int(shortcut.keyCode)) {
            flags.formUnion([.maskSecondaryFn, .maskNumericPad])
        }
        for isDown in [true, false] {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: shortcut.keyCode, keyDown: isDown) else { continue }
            event.flags = flags
            event.post(tap: .cghidEventTap)
        }
    }

    /// Posts `forward` for positive steps and `backward` for negative, once per detent.
    static func post(steps: Int, forward: Shortcut, backward: Shortcut) {
        let shortcut = steps > 0 ? forward : backward
        for _ in 0..<abs(steps) { post(shortcut) }
    }
}
