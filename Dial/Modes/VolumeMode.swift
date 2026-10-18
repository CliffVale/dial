import Foundation

/// Turns pass straight through to the buds' volume (the encoder doesn't park in
/// this mode). Press is handed to the music app as play/pause, Art's choice
/// over the spec's mute.
final class VolumeMode: Mode {
    let id = ModeID.volume
    var onReadingChange: (() -> Void)?

    private let readVolume: () -> Float?
    private let passPressToMediaApp: () -> Void

    init(readVolume: @escaping () -> Float?, passPressToMediaApp: @escaping () -> Void) {
        self.readVolume = readVolume
        self.passPressToMediaApp = passPressToMediaApp
    }

    var reading: HUDReading {
        guard let volume = readVolume() else { return HUDReading(level: nil, text: "—") }
        return HUDReading(level: Double(volume), text: String(Int((volume * 100).rounded())))
    }

    func turn(_ steps: Int) {
        // The volume already moved; only the HUD changes.
    }

    func press() -> String {
        passPressToMediaApp()
        return "Play / Pause"
    }
}
