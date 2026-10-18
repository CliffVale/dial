import AppKit
import ApplicationServices

/// Running apps, most recently used first, from NSWorkspace activations.
final class AppSwitcher {
    private var order: [pid_t] = []
    private var observer: NSObjectProtocol?

    func start() {
        let workspace = NSWorkspace.shared
        // Seed with what's running, the frontmost app first.
        if let front = workspace.frontmostApplication { order.append(front.processIdentifier) }
        for app in workspace.runningApplications where app.activationPolicy == .regular && !order.contains(app.processIdentifier) {
            order.append(app.processIdentifier)
        }
        observer = workspace.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self?.order.removeAll { $0 == app.processIdentifier }
            self?.order.insert(app.processIdentifier, at: 0)
        }
    }

    /// Regular apps still running, most recent first, without Dial.
    var recentApps: [NSRunningApplication] {
        let running = Dictionary(
            NSWorkspace.shared.runningApplications
                .filter { $0.activationPolicy == .regular && $0.processIdentifier != getpid() }
                .map { ($0.processIdentifier, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let known = order.compactMap { running[$0] }
        let rest = running.values.filter { !order.contains($0.processIdentifier) }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
        return known + rest
    }

    /// Brings an app forward, unhiding it. Dial is never active, so the
    /// Accessibility "frontmost" attribute is the reliable way in.
    static func activate(_ app: NSRunningApplication) {
        if app.isHidden { app.unhide() }
        let element = AXUIElementCreateApplication(app.processIdentifier)
        let result = AXUIElementSetAttributeValue(element, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
        if result != .success {
            app.activate()
        }
    }
}
