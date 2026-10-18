import Carbon.HIToolbox

/// Left undoes (⌘Z), right redoes (⇧⌘Z); press saves (⌘S).
final class UndoRedoMode: Mode {
    let id = ModeID.undoRedo
    var onReadingChange: (() -> Void)?

    private var tally = StepTally()

    var reading: HUDReading {
        HUDReading(level: nil, text: tally.text(forward: "Redo", backward: "Undo"))
    }

    func turn(_ steps: Int) {
        tally.add(steps)
        KeyEmitter.post(
            steps: steps,
            forward: KeyEmitter.Shortcut(kVK_ANSI_Z, [.maskCommand, .maskShift]),
            backward: KeyEmitter.Shortcut(kVK_ANSI_Z, .maskCommand)
        )
    }

    func press() -> String {
        KeyEmitter.post(KeyEmitter.Shortcut(kVK_ANSI_S, .maskCommand))
        return "Save"
    }
}
