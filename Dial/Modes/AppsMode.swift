import AppKit
import Observation

/// Moves through running apps, most recently used first; press opens the one
/// under the cursor. The card fan (FanView) reads `apps` and `selection`.
@Observable
final class AppsMode: Mode {
    let id = ModeID.apps
    @ObservationIgnored var onReadingChange: (() -> Void)?

    @ObservationIgnored private let switcher: AppSwitcher
    private(set) var apps: [NSRunningApplication] = []
    /// Index into `apps`; 0 is the app in front, so one detent is usually the
    /// app you want.
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

    /// Fresh list with the front app selected, each time the fan opens.
    func refresh() {
        apps = switcher.recentApps
        selection = 0
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
        return "Open"
    }
}
