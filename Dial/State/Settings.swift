import Foundation
import Observation

/// Persisted preferences, edited in the Settings window.
struct DialSettings: Equatable {
    private static let orderKey = "modeOrder"
    private static let disabledKey = "disabledModes"
    private static let pressKey = "pressActions"

    /// Segment order on the ring.
    var order: [ModeID]
    var disabled: Set<ModeID>
    /// Only the modes whose press differs from their own default.
    var pressActions: [ModeID: PressAction] = [:]

    var enabledModes: [ModeID] {
        let modes = order.filter { !disabled.contains($0) }
        return modes.isEmpty ? [.volume] : modes
    }

    func pressAction(for mode: ModeID) -> PressAction {
        if let action = pressActions[mode], mode.pressOptions.contains(action) { return action }
        return mode.pressOptions[0]
    }

    mutating func setPressAction(_ action: PressAction, for mode: ModeID) {
        pressActions[mode] = action == mode.pressOptions[0] ? nil : action
    }

    /// At least one mode always stays on.
    mutating func setEnabled(_ enabled: Bool, for mode: ModeID) {
        if enabled {
            disabled.remove(mode)
        } else if enabledModes.count > 1 {
            disabled.insert(mode)
        }
    }

    mutating func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        var reordered = order
        let moving = source.map { reordered[$0] }
        for index in source.sorted(by: >) { reordered.remove(at: index) }
        let insertAt = destination - source.filter { $0 < destination }.count
        reordered.insert(contentsOf: moving, at: insertAt)
        order = reordered
    }

    static let standard = DialSettings(order: ModeID.allCases, disabled: [])

    static func load(from defaults: UserDefaults = .standard) -> DialSettings {
        let stored = (defaults.stringArray(forKey: orderKey) ?? []).compactMap(ModeID.init(rawValue:))
        // Keep the stored order, then append any mode added since it was saved.
        let order = stored + ModeID.allCases.filter { !stored.contains($0) }
        let disabled = Set((defaults.stringArray(forKey: disabledKey) ?? []).compactMap(ModeID.init(rawValue:)))
        var press: [ModeID: PressAction] = [:]
        for (key, value) in defaults.dictionary(forKey: pressKey) as? [String: String] ?? [:] {
            if let mode = ModeID(rawValue: key), let action = PressAction(rawValue: value) { press[mode] = action }
        }
        return DialSettings(order: order, disabled: disabled, pressActions: press)
    }

    func save(to defaults: UserDefaults = .standard) {
        defaults.set(order.map(\.rawValue), forKey: Self.orderKey)
        defaults.set(disabled.map(\.rawValue), forKey: Self.disabledKey)
        defaults.set(Dictionary(uniqueKeysWithValues: pressActions.map { ($0.key.rawValue, $0.value.rawValue) }), forKey: Self.pressKey)
    }
}

/// The settings the app runs on; saving and telling the model on every change.
@Observable
final class SettingsStore {
    private static let onboardedKey = "hasCompletedOnboarding"
    private static let testingToolsKey = "testingTools"

    var settings: DialSettings {
        didSet {
            guard settings != oldValue else { return }
            settings.save()
            onChange?(settings)
        }
    }

    var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: Self.onboardedKey) }
    }

    /// The ⌃⌥ hotkeys that stand in for the dial, and the debug log. On in
    /// Debug builds; off by default in Release, where they could clash with
    /// other apps' shortcuts.
    var testingTools: Bool {
        didSet {
            UserDefaults.standard.set(testingTools, forKey: Self.testingToolsKey)
            onTestingToolsChange?(testingTools)
        }
    }

    @ObservationIgnored var onChange: ((DialSettings) -> Void)?
    @ObservationIgnored var onTestingToolsChange: ((Bool) -> Void)?

    init() {
        settings = .load()
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: Self.onboardedKey)
        #if DEBUG
        let testingDefault = true
        #else
        let testingDefault = false
        #endif
        testingTools = UserDefaults.standard.object(forKey: Self.testingToolsKey) as? Bool ?? testingDefault
    }
}
