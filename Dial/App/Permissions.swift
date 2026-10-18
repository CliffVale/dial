import AppKit
import ApplicationServices

/// Accessibility, which Dial needs to post keys, scrolls and media keys and to
/// bring apps forward. macOS ties the grant to the code signature.
enum Permissions {
    private static var hasPrompted = false
    private static var pollTimer: Timer?

    static var isAccessibilityTrusted: Bool { AXIsProcessTrusted() }

    /// True when Dial may post events. Otherwise asks (the system prompt shows
    /// once per launch) and returns false.
    static func ensureAccessibility(reason: String) -> Bool {
        if isAccessibilityTrusted { return true }
        requestAccessibility(reason: reason)
        return false
    }

    static func requestAccessibility(reason: String) {
        log("perm", "Accessibility is needed to \(reason). Turn on Dial in System Settings → Privacy & Security → Accessibility.")
        if !hasPrompted {
            hasPrompted = true
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        }
        watchForGrant()
    }

    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Logs the moment the grant arrives, so a test can carry on without a relaunch.
    private static func watchForGrant() {
        guard pollTimer == nil else { return }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            guard isAccessibilityTrusted else { return }
            log("perm", "Accessibility granted")
            timer.invalidate()
            pollTimer = nil
        }
    }
}
