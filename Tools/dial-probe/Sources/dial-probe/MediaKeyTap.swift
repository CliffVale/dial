import AppKit
import CoreGraphics

/// Listen-only CGEventTap on system-defined events (NX_SYSDEFINED, type 14).
/// Media keys arrive with subtype 8 (NX_SUBTYPE_AUX_CONTROL_BUTTONS) and pack
/// key type, key state and repeat into data1.
final class MediaKeyTap {
    private var tap: CFMachPort?
    private let verbose: Bool

    init(verbose: Bool) {
        self.verbose = verbose
    }

    /// Returns false when the tap can't be created, which almost always means
    /// Input Monitoring hasn't been granted to the terminal.
    func start() -> Bool {
        if !CGPreflightListenEventAccess() {
            Log.line("tap", "Input Monitoring not granted yet; requesting it (System Settings will list your terminal app)")
            CGRequestListenEventAccess()
        }

        let mask = CGEventMask(1) << 14 // NX_SYSDEFINED
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            let me = Unmanaged<MediaKeyTap>.fromOpaque(refcon!).takeUnretainedValue()
            me.handle(type: type, event: event)
            return Unmanaged.passUnretained(event)
        }
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }
        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    private func handle(type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            Log.line("tap", "tap disabled by system (\(type.rawValue)); re-enabling")
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        }
        guard let ns = NSEvent(cgEvent: event), ns.type == .systemDefined else { return }

        guard ns.subtype.rawValue == 8 else {
            // Subtype 7 fires on every mouse click; only show others on request.
            if verbose {
                Log.line("tap", "system-defined subtype=\(ns.subtype.rawValue) data1=0x\(String(ns.data1, radix: 16)) data2=0x\(String(ns.data2, radix: 16))")
            }
            return
        }

        let data1 = ns.data1
        let keyType = Int((data1 & 0xFFFF_0000) >> 16)
        let flags = data1 & 0xFFFF
        let state = (flags & 0xFF00) >> 8
        let isRepeat = (flags & 0x1) == 1
        let stateName: String
        switch state {
        case 0x0A: stateName = "down"
        case 0x0B: stateName = "up"
        default: stateName = String(format: "state=0x%02X", state)
        }
        let name = Self.keyName(keyType)
        Log.line("mediakey", "\(name.padding(toLength: 18, withPad: " ", startingAt: 0)) \(stateName.padding(toLength: 5, withPad: " ", startingAt: 0)) repeat=\(isRepeat ? "yes" : "no ") keyType=\(keyType) data1=0x\(String(data1, radix: 16))")
        Tally.bump("mediakey \(name) \(stateName)")
    }

    static func keyName(_ keyType: Int) -> String {
        let names: [Int: String] = [
            0: "SOUND_UP", 1: "SOUND_DOWN", 2: "BRIGHTNESS_UP", 3: "BRIGHTNESS_DOWN",
            4: "CAPS_LOCK", 5: "HELP", 6: "POWER_KEY", 7: "MUTE",
            8: "UP_ARROW", 9: "DOWN_ARROW", 10: "NUM_LOCK",
            11: "CONTRAST_UP", 12: "CONTRAST_DOWN", 13: "LAUNCH_PANEL", 14: "EJECT",
            15: "VIDMIRROR", 16: "PLAY", 17: "NEXT", 18: "PREVIOUS", 19: "FAST",
            20: "REWIND", 21: "ILLUMINATION_UP", 22: "ILLUMINATION_DOWN", 23: "ILLUMINATION_TOGGLE",
        ]
        return "NX_KEYTYPE_" + (names[keyType] ?? "UNKNOWN_\(keyType)")
    }
}
