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

/// The built-in display's brightness, read through the system's private
/// DisplayServices framework. Returns nil where it isn't available (external
/// displays, or if the framework changes), and the HUD then shows no meter.
enum DisplayBrightness {
    private typealias GetBrightness = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32

    private static let getBrightness: GetBrightness? = {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_NOW),
              let symbol = dlsym(handle, "DisplayServicesGetBrightness") else { return nil }
        return unsafeBitCast(symbol, to: GetBrightness.self)
    }()

    static var builtInDisplay: CGDirectDisplayID? {
        var count: UInt32 = 0
        CGGetOnlineDisplayList(0, nil, &count)
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetOnlineDisplayList(count, &displays, &count)
        return displays.first { CGDisplayIsBuiltin($0) != 0 }
    }

    static var level: Double? {
        guard let getBrightness, let display = builtInDisplay else { return nil }
        var value: Float = 0
        guard getBrightness(display, &value) == 0 else { return nil }
        return Double(value)
    }
}

/// Night Shift through the system's private CoreBrightness framework.
enum NightShift {
    private typealias GetStatus = @convention(c) (AnyObject, Selector, UnsafeMutableRawPointer) -> Bool
    private typealias SetEnabled = @convention(c) (AnyObject, Selector, Bool) -> Bool

    private static let client: NSObject? = {
        guard dlopen("/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness", RTLD_NOW) != nil,
              let type = NSClassFromString("CBBlueLightClient") as? NSObject.Type else { return nil }
        return type.init()
    }()

    /// Turns Night Shift on or off; returns the new state, or nil if unavailable.
    static func toggle() -> Bool? {
        let getSelector = NSSelectorFromString("getBlueLightStatus:")
        let setSelector = NSSelectorFromString("setEnabled:")
        guard let client, client.responds(to: getSelector), client.responds(to: setSelector) else { return nil }

        // The status struct starts { BOOL active; BOOL enabled; ... }.
        var status = [UInt8](repeating: 0, count: 64)
        let get = unsafeBitCast(client.method(for: getSelector), to: GetStatus.self)
        guard status.withUnsafeMutableBytes({ get(client, getSelector, $0.baseAddress!) }) else { return nil }
        let enabled = status[1] != 0

        let set = unsafeBitCast(client.method(for: setSelector), to: SetEnabled.self)
        guard set(client, setSelector, !enabled) else { return nil }
        return !enabled
    }
}
