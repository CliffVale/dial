import Foundation

/// Brightness keys per detent. External displays may ignore them; the HUD
/// then shows a direction instead of a level.
final class BrightnessMode: Mode {
    let id = ModeID.brightness
    var onReadingChange: (() -> Void)?

    /// The display takes a moment to apply a key; read the level after it.
    private static let readBackDelay: TimeInterval = 0.12
    private var lastDirection = 0

    var reading: HUDReading {
        if let level = DisplayBrightness.level {
            return HUDReading(level: level, text: String(Int((level * 100).rounded())))
        }
        return HUDReading(level: nil, text: lastDirection > 0 ? "Brighter" : lastDirection < 0 ? "Dimmer" : "—")
    }

    func turn(_ steps: Int) {
        lastDirection = steps > 0 ? 1 : -1
        for _ in 0..<abs(steps) {
            SystemControls.postMediaKey(steps > 0 ? .brightnessUp : .brightnessDown)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.readBackDelay) { [weak self] in
            self?.onReadingChange?()
        }
    }

    func press() -> String {
        switch NightShift.toggle() {
        case true?: return "Night Shift on"
        case false?: return "Night Shift off"
        case nil:
            log("mode", "Brightness: Night Shift isn't available on this Mac")
            return "No Night Shift"
        }
    }
}
