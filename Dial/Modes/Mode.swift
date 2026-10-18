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

    var symbol: String {
        switch self {
        case .volume: return "speaker.wave.2"
        case .brightness: return "sun.max"
        case .apps: return "square.grid.3x3"
        case .missionControl: return "rectangle.3.group"
        case .desktops: return "rectangle.on.rectangle"
        case .tabs: return "macwindow"
        case .scroll: return "computermouse"
        case .undoRedo: return "arrow.uturn.backward"
        case .slides: return "play.rectangle"
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

protocol Mode: AnyObject {
    var id: ModeID { get }
    func turn(_ steps: Int)
    func press()
}

extension Mode {
    var label: String { id.label }
    var shortLabel: String { id.shortLabel }
    var kind: ModeKind { id.kind }
}

/// Stands in for modes that arrive in Phase 3: logs what it would do.
final class PlaceholderMode: Mode {
    let id: ModeID

    init(_ id: ModeID) {
        self.id = id
    }

    func turn(_ steps: Int) {
        log("mode", "\(id.label): turn \(steps > 0 ? "+" : "")\(steps) (action arrives in Phase 3)")
    }

    func press() {
        log("mode", "\(id.label): press (action arrives in Phase 3)")
    }
}
