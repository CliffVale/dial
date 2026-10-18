import AppKit

/// System-defined key events: media and brightness keys.
enum SystemControls {
    /// NX_KEYTYPE_* values from IOKit's ev_keymap.h.
    enum MediaKey: Int {
        case soundUp = 0
        case soundDown = 1
        case brightnessUp = 2
        case brightnessDown = 3
        case mute = 7
        case playPause = 16
        case next = 17
        case previous = 18
    }

    /// Posts a key down and up as NX_SYSDEFINED subtype 8, like a keyboard's
    /// media keys. Needs Accessibility; without it macOS drops the events.
    static func postMediaKey(_ key: MediaKey) {
        for isDown in [true, false] {
            let state = isDown ? 0x0A : 0x0B
            let flags = NSEvent.ModifierFlags(rawValue: UInt(state << 8))
            let data1 = (key.rawValue << 16) | (state << 8)
            let event = NSEvent.otherEvent(
                with: .systemDefined,
                location: .zero,
                modifierFlags: flags,
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                subtype: 8,
                data1: data1,
                data2: -1
            )
            event?.cgEvent?.post(tap: .cghidEventTap)
        }
    }
}
