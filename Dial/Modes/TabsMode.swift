import Carbon.HIToolbox

/// ⌃⇧⇥ / ⌃⇥ to move between tabs; press opens a new one with ⌘T.
final class TabsMode: Mode {
    let id = ModeID.tabs
    var onReadingChange: (() -> Void)?

    private var tally = StepTally()

    var reading: HUDReading {
        HUDReading(level: nil, text: tally.text(forward: "Next", backward: "Previous"))
    }

    func turn(_ steps: Int) {
        tally.add(steps)
        KeyEmitter.post(
            steps: steps,
            forward: KeyEmitter.Shortcut(kVK_Tab, .maskControl),
            backward: KeyEmitter.Shortcut(kVK_Tab, [.maskControl, .maskShift])
        )
    }

    func press() -> String {
        KeyEmitter.post(KeyEmitter.Shortcut(kVK_ANSI_T, .maskCommand))
        return "New tab"
    }
}
