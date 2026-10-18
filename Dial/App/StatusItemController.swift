import AppKit
import Observation

/// The menu bar item. In Phase 1 it shows the dial symbol and, when a mode is
/// active, that mode's short label; the designed label arrives in Phase 3.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let model: DialModel
    private let encoder: VolumeEncoder

    var onShowDebugLog: (() -> Void)?
    var onReclaimMediaButtons: (() -> Void)?

    private let stateItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let budsItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")

    init(model: DialModel, encoder: VolumeEncoder) {
        self.model = model
        self.encoder = encoder
        super.init()

        item.button?.image = NSImage(systemSymbolName: "dial.medium", accessibilityDescription: "Dial")
        item.button?.imagePosition = .imageLeading
        buildMenu()
        trackModel()
    }

    private func buildMenu() {
        let menu = NSMenu()
        menu.delegate = self
        stateItem.isEnabled = false
        budsItem.isEnabled = false
        menu.addItem(stateItem)
        menu.addItem(budsItem)
        menu.addItem(.separator())

        let debug = NSMenuItem(title: "Show Debug Log", action: #selector(showDebugLog), keyEquivalent: "l")
        debug.target = self
        menu.addItem(debug)
        let reclaim = NSMenuItem(title: "Reclaim Media Buttons", action: #selector(reclaimMediaButtons), keyEquivalent: "")
        reclaim.target = self
        reclaim.toolTip = "Use this if another app started playing and the dial press stopped reaching Dial."
        menu.addItem(reclaim)

        menu.addItem(.separator())
        let hotkeys = NSMenuItem(title: "Simulate: ⌃⌥← → turn · ⌃⌥Space press · ⌃⌥D double press", action: nil, keyEquivalent: "")
        hotkeys.isEnabled = false
        menu.addItem(hotkeys)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Dial", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        stateItem.title = "State: \(model.phaseDescription)"
        if let buds = encoder.deviceLabel {
            budsItem.title = "Buds: \(buds) · volume \(model.shouldPark ? "parked" : "pass-through")"
        } else {
            budsItem.title = "Buds: not the sound output, turns are off"
        }
    }

    /// Re-arms after every change, the AppKit way to follow an @Observable model.
    private func trackModel() {
        withObservationTracking {
            updateButton()
        } onChange: { [weak self] in
            Task { @MainActor in self?.trackModel() }
        }
    }

    private func updateButton() {
        switch model.phase {
        case .rest:
            item.button?.title = ""
        case .picking:
            item.button?.title = " " + model.selectedMode.shortLabel + "…"
        case .inMode(let mode):
            item.button?.title = " " + mode.shortLabel
        }
    }

    @objc private func showDebugLog() {
        onShowDebugLog?()
    }

    @objc private func reclaimMediaButtons() {
        onReclaimMediaButtons?()
    }
}
