import Foundation

/// Turns pass straight through to the buds' volume (the encoder doesn't park in
/// this mode). Press is handed to the music app as play/pause.
final class VolumeMode: Mode {
    let id = ModeID.volume
    private let passPressToMediaApp: () -> Void

    init(passPressToMediaApp: @escaping () -> Void) {
        self.passPressToMediaApp = passPressToMediaApp
    }

    func turn(_ steps: Int) {
        // The volume already moved; the HUD arrives in Phase 3.
        log("mode", "Volume: turn \(steps > 0 ? "+" : "")\(steps) passed through")
    }

    func press() {
        passPressToMediaApp()
    }
}
