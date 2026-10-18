import AppKit
import Carbon.HIToolbox

/// The user's own keyboard shortcuts from System Settings → Keyboard →
/// Keyboard Shortcuts, so Dial posts whatever they've set.
enum SymbolicHotKey: Int {
    case missionControl = 32
    case showDesktop = 36
    case moveLeftASpace = 79
    case moveRightASpace = 81

    /// macOS's defaults, used when the user hasn't changed a shortcut.
    private var fallback: KeyEmitter.Shortcut {
        switch self {
        case .missionControl: return KeyEmitter.Shortcut(kVK_UpArrow, .maskControl)
        case .showDesktop: return KeyEmitter.Shortcut(kVK_F11, .maskSecondaryFn)
        case .moveLeftASpace: return KeyEmitter.Shortcut(kVK_LeftArrow, .maskControl)
        case .moveRightASpace: return KeyEmitter.Shortcut(kVK_RightArrow, .maskControl)
        }
    }

    private var entry: [String: Any]? {
        let defaults = UserDefaults(suiteName: "com.apple.symbolichotkeys")
        let all = defaults?.dictionary(forKey: "AppleSymbolicHotKeys")
        return all?[String(rawValue)] as? [String: Any]
    }

    /// Off only when the user turned it off; a missing entry means the default, which is on.
    var isEnabled: Bool {
        (entry?["enabled"] as? Bool) ?? true
    }

    var shortcut: KeyEmitter.Shortcut {
        guard let value = entry?["value"] as? [String: Any],
              let parameters = value["parameters"] as? [Int], parameters.count == 3,
              parameters[1] != 65535 else { return fallback }
        // Stored modifiers use the same bits as CGEventFlags.
        return KeyEmitter.Shortcut(parameters[1], CGEventFlags(rawValue: UInt64(parameters[2])))
    }

    /// Re-reads System Settings' changes, which are cached per process.
    static func reload() {
        CFPreferencesAppSynchronize("com.apple.symbolichotkeys" as CFString)
    }
}

/// Which desktop is showing, through the window server's private Spaces
/// calls. Returns nil if they're unavailable; the HUD then shows a direction.
enum Spaces {
    private typealias MainConnection = @convention(c) () -> Int32
    private typealias CopyDisplaySpaces = @convention(c) (Int32) -> Unmanaged<CFArray>?

    private static let functions: (MainConnection, CopyDisplaySpaces)? = {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_NOW),
              let main = dlsym(handle, "SLSMainConnectionID") ?? dlsym(handle, "CGSMainConnectionID"),
              let copy = dlsym(handle, "SLSCopyManagedDisplaySpaces") ?? dlsym(handle, "CGSCopyManagedDisplaySpaces") else { return nil }
        return (unsafeBitCast(main, to: MainConnection.self), unsafeBitCast(copy, to: CopyDisplaySpaces.self))
    }()

    /// The current desktop's position and the number of desktops on the main
    /// display, counting full-screen apps as desktops, as Mission Control does.
    static var position: (current: Int, count: Int)? {
        guard let (main, copy) = functions,
              let displays = copy(main())?.takeRetainedValue() as? [[String: Any]] else { return nil }
        let mainUUID = NSScreen.main.flatMap(uuid(of:))
        let display = displays.first { ($0["Display Identifier"] as? String) == mainUUID }
            ?? displays.first { ($0["Display Identifier"] as? String) == "Main" }
            ?? displays.first
        guard let display,
              let spaces = display["Spaces"] as? [[String: Any]],
              let current = display["Current Space"] as? [String: Any],
              let currentID = current["ManagedSpaceID"] as? Int,
              let index = spaces.firstIndex(where: { ($0["ManagedSpaceID"] as? Int) == currentID }) else { return nil }
        return (index + 1, spaces.count)
    }

    private static func uuid(of screen: NSScreen) -> String? {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
              let uuid = CGDisplayCreateUUIDFromDisplayID(number.uint32Value)?.takeRetainedValue() else { return nil }
        return CFUUIDCreateString(nil, uuid) as String
    }
}
