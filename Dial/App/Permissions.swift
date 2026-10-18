import ApplicationServices

enum Permissions {
    /// True when Dial may post events. Otherwise shows the system prompt once
    /// and returns false. The full onboarding flow comes in Phase 3.
    static func ensureAccessibility(reason: String) -> Bool {
        if AXIsProcessTrusted() { return true }
        log("perm", "Accessibility is needed to \(reason). Grant Dial in System Settings → Privacy & Security → Accessibility, then try again.")
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        return false
    }
}
