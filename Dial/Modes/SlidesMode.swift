import AppKit
import Carbon.HIToolbox

/// ← / → between slides; press starts the show in the frontmost app, or ends
/// it with Escape.
final class SlidesMode: Mode {
    let id = ModeID.slides
    var onReadingChange: (() -> Void)?

    private var presenting = false
    private var tally = StepTally()

    var reading: HUDReading {
        HUDReading(level: nil, text: tally.net == 0 ? (presenting ? "Presenting" : "—") : tally.text(forward: "Next", backward: "Previous"))
    }

    func turn(_ steps: Int) {
        tally.add(steps)
        KeyEmitter.post(steps: steps, forward: KeyEmitter.right, backward: KeyEmitter.left)
    }

    func press() -> String {
        if presenting {
            KeyEmitter.post(KeyEmitter.escape)
            presenting = false
            return "End show"
        }
        let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""
        let shortcut = Self.startShortcut(for: bundleID)
        KeyEmitter.post(shortcut)
        presenting = true
        log("mode", "Slides: start show with \(shortcut) in \(bundleID)")
        return "Start show"
    }

    func deactivate() {
        presenting = false
    }

    /// Keynote ⌥⌘P, PowerPoint ⇧⌘↩, Google Slides in a browser ⌘↩.
    private static func startShortcut(for bundleID: String) -> KeyEmitter.Shortcut {
        switch bundleID {
        case "com.apple.iWork.Keynote":
            return KeyEmitter.Shortcut(kVK_ANSI_P, [.maskCommand, .maskAlternate])
        case "com.microsoft.Powerpoint":
            return KeyEmitter.Shortcut(kVK_Return, [.maskCommand, .maskShift])
        default:
            return KeyEmitter.Shortcut(kVK_Return, .maskCommand)
        }
    }
}
