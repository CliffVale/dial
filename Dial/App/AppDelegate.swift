import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: DialModel!
    private var encoder: VolumeEncoder!
    private var remote: RemoteCommandSource!
    private var simulated: SimulatedInput!
    private var statusItem: StatusItemController!
    private var debugWindow: DebugLogWindowController!
    private var dialPanel: DialPanelController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        if DialSnapshots.renderIfRequested() {
            NSApp.terminate(nil)
            return
        }
        log("app", "Dial \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? "?") started; log file \(DebugLog.shared.fileURL.path)")

        model = DialModel(settings: .load())
        encoder = VolumeEncoder()
        remote = RemoteCommandSource()
        simulated = SimulatedInput()

        let passPress: () -> Void = { [weak self] in self?.remote.passPlayPauseToMediaApp() }
        model.passPressToMediaApp = passPress
        model.register(VolumeMode(passPressToMediaApp: passPress))
        for id in ModeID.allCases where id != .volume {
            model.register(PlaceholderMode(id))
        }
        model.onParkingChange = { [weak self] parking in self?.encoder.parking = parking }

        for source in [encoder, remote, simulated] as [InputSource] {
            source.onEvent = { [weak self, unowned source] event in
                self?.model.handle(event, from: source.name)
            }
            source.start()
        }

        debugWindow = DebugLogWindowController(model: model, encoder: encoder)
        dialPanel = DialPanelController(model: model)
        statusItem = StatusItemController(model: model, encoder: encoder, presentation: dialPanel.presentation)
        dialPanel.anchor = { [weak self] in self?.statusItem.anchor }
        statusItem.onShowDebugLog = { [weak self] in self?.debugWindow.show() }
        statusItem.onReclaimMediaButtons = { [weak self] in self?.remote.reclaim() }
        simulated.onReclaim = { [weak self] in self?.remote.reclaim() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        guard model != nil else { return }
        // Give the listening volume back if we were holding it.
        encoder.stop()
        remote.stop()
        simulated.stop()
        log("app", "Dial quit")
    }
}
