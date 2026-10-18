import SwiftUI

@main
struct DialApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // ⌘, while Dial is active; the menu bar item's menu opens the same view.
        Settings {
            SettingsView(store: appDelegate.settings)
        }
    }
}
