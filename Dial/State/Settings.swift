import Foundation

/// Persisted preferences. Phase 5 adds the Settings window that edits them.
struct DialSettings {
    private static let orderKey = "modeOrder"
    private static let disabledKey = "disabledModes"

    /// Segment order on the ring.
    var order: [ModeID]
    var disabled: Set<ModeID>

    var enabledModes: [ModeID] {
        let modes = order.filter { !disabled.contains($0) }
        return modes.isEmpty ? [.volume] : modes
    }

    static func load(from defaults: UserDefaults = .standard) -> DialSettings {
        let stored = (defaults.stringArray(forKey: orderKey) ?? []).compactMap(ModeID.init(rawValue:))
        // Keep the stored order, then append any mode added since it was saved.
        let order = stored + ModeID.allCases.filter { !stored.contains($0) }
        let disabled = Set((defaults.stringArray(forKey: disabledKey) ?? []).compactMap(ModeID.init(rawValue:)))
        return DialSettings(order: order, disabled: disabled)
    }

    func save(to defaults: UserDefaults = .standard) {
        defaults.set(order.map(\.rawValue), forKey: Self.orderKey)
        defaults.set(disabled.map(\.rawValue), forKey: Self.disabledKey)
    }
}
