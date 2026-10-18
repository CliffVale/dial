import Foundation

enum ModeKind {
    /// Adjusts a level, like volume or brightness.
    case level
    /// Moves through a list, like apps or windows.
    case list
    /// Sends one action per detent.
    case step
}

/// The nine segments, clockwise from the gap at 12 o'clock (DESIGN.md).
enum ModeID: String, CaseIterable, Codable {
    case volume, brightness, apps, missionControl, desktops, tabs, scroll, undoRedo, slides

    var label: String {
        switch self {
        case .volume: return "Volume"
        case .brightness: return "Brightness"
        case .apps: return "Apps"
        case .missionControl: return "Mission Control"
        case .desktops: return "Desktops"
        case .tabs: return "Tabs"
        case .scroll: return "Scroll"
        case .undoRedo: return "Undo / Redo"
        case .slides: return "Slides"
        }
    }

    /// The knob label.
    var shortLabel: String {
        switch self {
        case .volume: return "Volume"
        case .brightness: return "Bright"
        case .apps: return "Apps"
        case .missionControl: return "Mission"
        case .desktops: return "Desktops"
        case .tabs: return "Tabs"
        case .scroll: return "Scroll"
        case .undoRedo: return "Undo"
        case .slides: return "Slides"
        }
    }

    var kind: ModeKind {
        switch self {
        case .volume, .brightness: return .level
        case .apps, .missionControl: return .list
        default: return .step
        }
    }
}

/// What the HUD shows for a mode: a level for the meter (0...1) and/or a value.
struct HUDReading: Equatable {
    var level: Double?
    var text: String

    static let empty = HUDReading(level: nil, text: "")
}

protocol Mode: AnyObject {
    var id: ModeID { get }
    /// Whether turning or pressing posts events, which needs Accessibility.
    var needsAccessibility: Bool { get }
    /// The HUD's meter and value right now.
    var reading: HUDReading { get }
    /// Set by the model; call when `reading` changes on its own (a value read back later).
    var onReadingChange: (() -> Void)? { get set }

    func turn(_ steps: Int)
    /// Performs the press action and returns its name for the HUD ("Mute", "New tab").
    func press() -> String
    /// Called when the mode is chosen and when it's left.
    func activate()
    func deactivate()
}

extension Mode {
    var label: String { id.label }
    var shortLabel: String { id.shortLabel }
    var kind: ModeKind { id.kind }
    var needsAccessibility: Bool { true }
    func activate() {}
    func deactivate() {}
}

/// Net detents in one direction while the HUD is up, for values like
/// "Undo ×2". Starts again once the HUD's linger has passed.
struct StepTally {
    private(set) var net = 0
    private var last = Date.distantPast

    mutating func add(_ steps: Int) {
        let now = Date()
        if now.timeIntervalSince(last) > DialMotion.hudLinger { net = 0 }
        net += steps
        last = now
    }

    /// "Next ×2", "Previous ×1", or "—" when the turns cancel out.
    func text(forward: String, backward: String) -> String {
        if net > 0 { return "\(forward) ×\(net)" }
        if net < 0 { return "\(backward) ×\(-net)" }
        return "—"
    }
}
