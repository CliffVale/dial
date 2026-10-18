import Foundation

/// What the dial did, independent of where it came from.
enum DialEvent: Equatable, CustomStringConvertible {
    /// Positive is clockwise (right), negative anticlockwise (left).
    case turn(Int)
    case press
    case doublePress

    var description: String {
        switch self {
        case .turn(let steps): return "turn(\(steps > 0 ? "+" : "")\(steps))"
        case .press: return "press"
        case .doublePress: return "doublePress"
        }
    }
}
