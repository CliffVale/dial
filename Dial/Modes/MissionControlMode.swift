import AppKit

/// Choosing the mode opens Mission Control. Turning moves through its windows
/// in reading order; the pointer moves onto each one, so Mission Control draws
/// its own highlight and title. Press brings that window forward; double press
/// closes Mission Control without changing anything.
///
/// Phase 4 found arrow keys don't move Mission Control's selection, so this
/// drives its window buttons through the Dock's Accessibility tree instead of
/// building the fallback picker (see docs/phase0-findings.md).
final class MissionControlMode: Mode {
    let id = ModeID.missionControl
    var onReadingChange: (() -> Void)?

    private static let app = URL(fileURLWithPath: "/System/Applications/Mission Control.app")
    /// Mission Control's windows settle into place after its opening animation.
    private static let settleDelay: TimeInterval = 0.6
    /// How often to check whether Mission Control was closed some other way.
    private static let watchInterval: TimeInterval = 0.5

    private var windows: [MissionControlUI.Window] = []
    private var selection = 0
    private var isOpening = false
    /// Where the pointer was before Dial moved it, restored when Mission Control closes.
    private var savedPointer: CGPoint?
    private var watchTimer: Timer?

    /// The HUD stays at the bottom of the screen while Mission Control is open.
    var hudIsSticky: Bool { isOpening || !windows.isEmpty }

    var reading: HUDReading {
        if isOpening { return HUDReading(level: nil, text: "Opening…") }
        guard windows.indices.contains(selection) else {
            return HUDReading(level: nil, text: MissionControlUI.isOpen ? "No windows" : "Turn to open")
        }
        let title = windows[selection].title.isEmpty ? "Window" : windows[selection].title
        return HUDReading(level: nil, text: "\(Self.shorten(title)) \(selection + 1) / \(windows.count)")
    }

    func activate() {
        open()
    }

    func turn(_ steps: Int) {
        guard MissionControlUI.isOpen, !windows.isEmpty else {
            if !isOpening { open() }
            return
        }
        refreshWindows()
        guard !windows.isEmpty else { return }
        selection = ((selection + steps) % windows.count + windows.count) % windows.count
        highlightSelection()
    }

    func press() -> String {
        guard MissionControlUI.isOpen, windows.indices.contains(selection) else {
            open()
            return "Open"
        }
        let window = windows[selection]
        let pressed = MissionControlUI.press(window)
        log("mission", "press: \(pressed ? "brought forward" : "could not press") \"\(window.title)\"")
        closed()
        return "Bring forward"
    }

    func deactivate() {
        if MissionControlUI.isOpen {
            KeyEmitter.post(KeyEmitter.escape)
        }
        closed()
    }

    // MARK: - Opening and closing

    private func open() {
        if !MissionControlUI.isOpen {
            NSWorkspace.shared.openApplication(at: Self.app, configuration: NSWorkspace.OpenConfiguration())
            log("mission", "opening Mission Control")
        }
        isOpening = true
        onReadingChange?()
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.settleDelay) { [weak self] in
            self?.opened()
        }
    }

    private func opened() {
        isOpening = false
        guard MissionControlUI.isOpen else {
            log("mission", "Mission Control didn't open")
            onReadingChange?()
            return
        }
        refreshWindows()
        selection = 0
        log("mission", "open with \(windows.count) windows")
        if savedPointer == nil { savedPointer = PointerControl.location }
        highlightSelection()
        startWatching()
    }

    private func closed() {
        isOpening = false
        windows = []
        watchTimer?.invalidate()
        watchTimer = nil
        if let savedPointer {
            // After Mission Control's closing animation, so it doesn't hover a window on the way out.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { PointerControl.move(to: savedPointer) }
        }
        savedPointer = nil
        onReadingChange?()
    }

    /// Notices Mission Control closing by other means (a click, Escape, a gesture).
    private func startWatching() {
        watchTimer?.invalidate()
        watchTimer = Timer.scheduledTimer(withTimeInterval: Self.watchInterval, repeats: true) { [weak self] _ in
            guard let self, !MissionControlUI.isOpen else { return }
            log("mission", "Mission Control closed")
            self.closed()
        }
    }

    // MARK: - Selection

    private func refreshWindows() {
        let previous = windows.indices.contains(selection) ? windows[selection].title : nil
        windows = MissionControlUI.windows()
        if let previous, let index = windows.firstIndex(where: { $0.title == previous }) {
            selection = index
        } else {
            selection = min(selection, max(windows.count - 1, 0))
        }
    }

    private func highlightSelection() {
        guard windows.indices.contains(selection) else { return }
        let frame = windows[selection].frame
        PointerControl.move(to: CGPoint(x: frame.midX, y: frame.midY))
        onReadingChange?()
    }

    /// Long titles, like a terminal's, would stretch the HUD across the screen.
    private static func shorten(_ title: String) -> String {
        title.count > 32 ? String(title.prefix(31)) + "…" : title
    }
}
