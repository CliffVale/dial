import Foundation
import Observation

/// The one state machine. Input sources feed it events; views only read it.
///
///   rest ──double press──▶ picking ──press──▶ inMode(m)
///                            ▲  │                │
///                            │  └─double press / idle─▶ back to where it came from
///                            └──────double press─────┘
///
/// At rest and in Volume mode the dial behaves like plain earbuds: turns move
/// the volume and a press goes to the music app.
@Observable
final class DialModel {
    enum Phase: Equatable {
        case rest
        case picking
        case inMode(ModeID)
    }

    private(set) var phase: Phase = .rest

    /// The ring's modes in order.
    private(set) var modes: [ModeID]

    /// Accumulated detents while picking. Never wrapped, so the highlight and
    /// knob angles keep accumulating (DESIGN.md, "Angles must accumulate").
    private(set) var selectionStep = 0

    /// When the latest detent arrived and the gap before it, for fast spin.
    private(set) var lastDetentAt: Date?
    private(set) var lastDetentInterval: TimeInterval?

    /// Where a cancelled pick returns to.
    @ObservationIgnored private var phaseBeforePicking: Phase = .rest
    @ObservationIgnored private var handlers: [ModeID: Mode] = [:]
    @ObservationIgnored private var idleTimer: Timer?

    /// Told whenever the encoder should start or stop parking the volume.
    @ObservationIgnored var onParkingChange: ((Bool) -> Void)?
    /// Hands a press to the music app (rest and Volume mode).
    @ObservationIgnored var passPressToMediaApp: (() -> Void)?

    init(settings: DialSettings) {
        modes = settings.enabledModes
    }

    func register(_ mode: Mode) {
        handlers[mode.id] = mode
    }

    // MARK: - Derived state

    var selectedMode: ModeID {
        modes[((selectionStep % modes.count) + modes.count) % modes.count]
    }

    /// Accumulated highlight angle in degrees, clockwise from the first segment.
    var selectionAngle: Double {
        Double(selectionStep) * 360 / Double(modes.count)
    }

    var activeMode: ModeID? {
        if case .inMode(let mode) = phase { return mode }
        return nil
    }

    var isFastSpin: Bool {
        guard let interval = lastDetentInterval else { return false }
        return interval < DialMotion.fastStepThreshold
    }

    /// Parked everywhere except rest and Volume mode, where the dial is a volume knob.
    var shouldPark: Bool {
        switch phase {
        case .rest: return false
        case .picking: return true
        case .inMode(let mode): return mode != .volume
        }
    }

    var phaseDescription: String {
        switch phase {
        case .rest: return "rest"
        case .picking: return "picking (\(selectedMode.label))"
        case .inMode(let mode): return "in \(mode.label)"
        }
    }

    // MARK: - Events

    func handle(_ event: DialEvent, from source: String) {
        log("event", "\(event) from \(source)  [state: \(phaseDescription)]")
        switch (phase, event) {
        case (.rest, .turn):
            // The encoder isn't parking, so the volume already moved.
            break
        case (.rest, .press):
            log("state", "press at rest → music app")
            passPressToMediaApp?()
        case (.rest, .doublePress), (.inMode, .doublePress):
            beginPicking()

        case (.picking, .turn(let steps)):
            recordDetents(steps)
            selectionStep += steps
            log("state", "selection → \(selectedMode.label) (step \(selectionStep), angle \(Int(selectionAngle))°)")
            restartIdleTimer()
        case (.picking, .press):
            choose(selectedMode)
        case (.picking, .doublePress):
            endPicking(reason: "double press")

        case (.inMode(let mode), .turn(let steps)):
            recordDetents(steps)
            handlers[mode]?.turn(steps)
        case (.inMode(let mode), .press):
            handlers[mode]?.press()
        }
    }

    // MARK: - Transitions

    private func beginPicking() {
        phaseBeforePicking = phase
        // Start on the active mode by moving the shortest way from where the
        // selection already is, so the angle stays continuous.
        if let mode = activeMode, let target = modes.firstIndex(of: mode) {
            let current = ((selectionStep % modes.count) + modes.count) % modes.count
            var offset = target - current
            if offset > modes.count / 2 { offset -= modes.count }
            if offset < -modes.count / 2 { offset += modes.count }
            selectionStep += offset
        }
        setPhase(.picking)
        restartIdleTimer()
    }

    private func choose(_ mode: ModeID) {
        idleTimer?.invalidate()
        setPhase(.inMode(mode))
    }

    private func endPicking(reason: String) {
        idleTimer?.invalidate()
        log("state", "picking closed by \(reason)")
        setPhase(phaseBeforePicking)
    }

    private func setPhase(_ newPhase: Phase) {
        let oldPark = shouldPark
        let oldDescription = phaseDescription
        phase = newPhase
        log("state", "\(oldDescription) → \(phaseDescription)")
        if shouldPark != oldPark {
            onParkingChange?(shouldPark)
        }
    }

    private func restartIdleTimer() {
        idleTimer?.invalidate()
        idleTimer = Timer.scheduledTimer(withTimeInterval: DialMotion.idleDismiss, repeats: false) { [weak self] _ in
            self?.endPicking(reason: "\(Int(DialMotion.idleDismiss))s idle")
        }
    }

    private func recordDetents(_ steps: Int) {
        let now = Date()
        lastDetentInterval = lastDetentAt.map { now.timeIntervalSince($0) }
        lastDetentAt = now
    }
}
