import Foundation

/// Anything that produces dial events: the buds, or hotkeys standing in for them.
protocol InputSource: AnyObject {
    /// Short name shown in the debug log, e.g. "volume", "remote", "hotkey".
    var name: String { get }
    var onEvent: ((DialEvent) -> Void)? { get set }
    func start()
    func stop()
}
