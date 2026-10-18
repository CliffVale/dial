import Foundation

/// Three lines per detent at the pointer; press switches between vertical and
/// sideways.
final class ScrollMode: Mode {
    let id = ModeID.scroll
    var onReadingChange: (() -> Void)?

    private static let linesPerDetent = 3
    private var horizontal = false
    private var tally = StepTally()

    var reading: HUDReading {
        guard tally.net != 0 else { return HUDReading(level: nil, text: horizontal ? "Sideways" : "—") }
        let lines = abs(tally.net) * Self.linesPerDetent
        let arrow = horizontal ? (tally.net > 0 ? "→" : "←") : (tally.net > 0 ? "↓" : "↑")
        return HUDReading(level: nil, text: "\(arrow) \(lines) lines")
    }

    func turn(_ steps: Int) {
        tally.add(steps)
        ScrollEmitter.scroll(lines: steps * Self.linesPerDetent, horizontal: horizontal)
    }

    func press() -> String {
        horizontal.toggle()
        tally = StepTally()
        return horizontal ? "Sideways" : "Vertical"
    }
}
