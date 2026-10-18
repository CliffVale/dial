import ServiceManagement

/// Launch at login through SMAppService. macOS may ask the user to approve it
/// in System Settings → General → Login Items.
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static var needsApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    static func set(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            log("app", "launch at login \(enabled ? "on" : "off")")
        } catch {
            log("app", "could not turn launch at login \(enabled ? "on" : "off"): \(error.localizedDescription)")
        }
    }

    static func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
