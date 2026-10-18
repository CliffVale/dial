import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: DialModel!
    private var encoder: VolumeEncoder!
    private var remote: RemoteCommandSource!
    private var simulated: SimulatedInput!
    private var statusItem: StatusItemController!
    private var debugWindow: DebugLogWindowController!

    func applicationDidFinishLaunching(_ notification: Notification) {
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
        statusItem = StatusItemController(model: model, encoder: encoder)
        statusItem.onShowDebugLog = { [weak self] in self?.debugWindow.show() }
        statusItem.onReclaimMediaButtons = { [weak self] in self?.remote.reclaim() }
        simulated.onReclaim = { [weak self] in self?.remote.reclaim() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Give the listening volume back if we were holding it.
        encoder.stop()
        remote.stop()
        simulated.stop()
        log("app", "Dial quit")
    }
}
