import SwiftUI

@main
struct DialApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // The only window apart from the debug log. Built out in Phase 5.
        Settings {
            Text("Settings arrive in Phase 5.")
                .padding(40)
        }
    }
}
