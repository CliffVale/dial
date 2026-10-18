import AppKit

/// Moves through running apps, most recently used first; press opens the one
/// under the cursor. The card fan arrives in Phase 4.
final class AppsMode: Mode {
    let id = ModeID.apps
    var onReadingChange: (() -> Void)?

    private let switcher: AppSwitcher
    private(set) var apps: [NSRunningApplication] = []
    private(set) var selection = 0

    init(switcher: AppSwitcher) {
        self.switcher = switcher
    }

    var selectedApp: NSRunningApplication? {
        apps.indices.contains(selection) ? apps[selection] : nil
    }

    var reading: HUDReading {
        HUDReading(level: nil, text: selectedApp?.localizedName ?? "No apps")
    }

    func activate() {
        refresh()
    }

    func turn(_ steps: Int) {
        if apps.isEmpty { refresh() }
        guard !apps.isEmpty else { return }
        // The list wraps.
        selection = ((selection + steps) % apps.count + apps.count) % apps.count
    }

    func press() -> String {
        guard let app = selectedApp else { return "No apps" }
        AppSwitcher.activate(app)
        log("mode", "Apps: opened \(app.localizedName ?? "?")")
        // The opened app is now first; start the next turn from it.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in self?.refresh() }
        return "Open"
    }

    private func refresh() {
        apps = switcher.recentApps
        selection = 0
    }
}
