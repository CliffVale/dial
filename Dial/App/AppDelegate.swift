import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: DialModel!
    private var encoder: VolumeEncoder!
    private var remote: RemoteCommandSource!
    private var simulated: SimulatedInput!
    private var statusItem: StatusItemController!
    private var debugWindow: DebugLogWindowController!
    private var dialPanel: DialPanelController!
    private var hudPanel: HUDPanelController!
    private let appSwitcher = AppSwitcher()
    let settings = SettingsStore()
    private var settingsWindow: SettingsWindowController!
    private var onboardingWindow: OnboardingWindowController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        if DialSnapshots.renderIfRequested() {
            NSApp.terminate(nil)
            return
        }
        log("app", "Dial \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? "?") started; log file \(DebugLog.shared.fileURL.path)")

        model = DialModel(settings: settings.settings)
        settings.onChange = { [weak self] new in self?.model.apply(new) }
        encoder = VolumeEncoder()
        remote = RemoteCommandSource()
        simulated = SimulatedInput()

        let passPress: () -> Void = { [weak self] in self?.remote.passPlayPauseToMediaApp() }
        model.passPressToMediaApp = passPress
        appSwitcher.start()
        let apps = AppsMode(switcher: appSwitcher)
        let modes: [Mode] = [
            VolumeMode(readVolume: { [weak self] in self?.encoder.currentVolume }, passPressToMediaApp: passPress),
            BrightnessMode(),
            apps,
            MissionControlMode(),
            DesktopsMode(),
            TabsMode(),
            ScrollMode(),
            UndoRedoMode(),
            SlidesMode(),
        ]
        modes.forEach(model.register)
        model.onParkingChange = { [weak self] parking in self?.encoder.parking = parking }

        for source in [encoder, remote, simulated] as [InputSource] {
            source.onEvent = { [weak self, unowned source] event in
                self?.model.handle(event, from: source.name)
            }
        }
        encoder.start()
        remote.start()
        if settings.testingTools { simulated.start() }
        settings.onTestingToolsChange = { [weak self] on in
            guard let self else { return }
            on ? self.simulated.start() : self.simulated.stop()
        }

        debugWindow = DebugLogWindowController(model: model, encoder: encoder)
        dialPanel = DialPanelController(model: model, apps: apps)
        statusItem = StatusItemController(model: model, encoder: encoder, presentation: dialPanel.presentation, settings: settings)
        dialPanel.anchor = { [weak self] in self?.statusItem.anchor }
        hudPanel = HUDPanelController(model: model)
        hudPanel.anchor = { [weak self] in self?.statusItem.anchor }
        statusItem.onShowDebugLog = { [weak self] in self?.debugWindow.show() }
        statusItem.onReclaimMediaButtons = { [weak self] in self?.remote.reclaim() }
        simulated.onReclaim = { [weak self] in self?.remote.reclaim() }

        onboardingWindow = OnboardingWindowController(model: model, store: settings, budsConnected: { [weak self] in self?.encoder.deviceLabel != nil })
        settingsWindow = SettingsWindowController(store: settings)
        settingsWindow.onShowSetupGuide = { [weak self] in self?.onboardingWindow.show() }
        statusItem.onShowSettings = { [weak self] in self?.settingsWindow.show() }
        statusItem.onShowSetupGuide = { [weak self] in self?.onboardingWindow.show() }
        if !settings.hasCompletedOnboarding {
            onboardingWindow.show()
        }
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
