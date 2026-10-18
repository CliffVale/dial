import Carbon.HIToolbox
import Foundation

/// Global hotkeys that stand in for the dial, so UI work never waits on the buds.
///
/// ⌃⌥← / ⌃⌥→   turn one detent
/// ⌃⌥⇧← / ⌃⌥⇧→ fast spin: five detents 50 ms apart
/// ⌃⌥Space      press
/// ⌃⌥D          double press
/// ⌃⌥R          reclaim the dial's buttons from a music app
///
/// Carbon hotkeys need no permission and don't reach the frontmost app.
final class SimulatedInput: InputSource {
    let name = "hotkey"
    var onEvent: ((DialEvent) -> Void)?
    var onReclaim: (() -> Void)?

    private enum Key: UInt32, CaseIterable {
        case left = 1, right, fastLeft, fastRight, press, doublePress, reclaim

        var keyCode: Int {
            switch self {
            case .left, .fastLeft: return kVK_LeftArrow
            case .right, .fastRight: return kVK_RightArrow
            case .press: return kVK_Space
            case .doublePress: return kVK_ANSI_D
            case .reclaim: return kVK_ANSI_R
            }
        }

        var modifiers: Int {
            switch self {
            case .fastLeft, .fastRight: return controlKey | optionKey | shiftKey
            default: return controlKey | optionKey
            }
        }

        var label: String {
            switch self {
            case .left: return "⌃⌥←"
            case .right: return "⌃⌥→"
            case .fastLeft: return "⌃⌥⇧←"
            case .fastRight: return "⌃⌥⇧→"
            case .press: return "⌃⌥Space"
            case .doublePress: return "⌃⌥D"
            case .reclaim: return "⌃⌥R"
            }
        }
    }

    private static let signature: OSType = 0x4449_414C // 'DIAL'
    private static let fastSpinSteps = 5
    private static let fastSpinInterval: TimeInterval = 0.05

    private var hotKeys: [EventHotKeyRef] = []
    private var handler: EventHandlerRef?

    func start() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let callback: EventHandlerUPP = { _, event, userData in
            guard let event, let userData else { return OSStatus(eventNotHandledErr) }
            var id = EventHotKeyID()
            let status = GetEventParameter(
                event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                nil, MemoryLayout<EventHotKeyID>.size, nil, &id
            )
            guard status == noErr else { return status }
            Unmanaged<SimulatedInput>.fromOpaque(userData).takeUnretainedValue().fire(id.id)
            return noErr
        }
        InstallEventHandler(GetApplicationEventTarget(), callback, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handler)

        var failed: [String] = []
        for key in Key.allCases {
            var ref: EventHotKeyRef?
            let id = EventHotKeyID(signature: Self.signature, id: key.rawValue)
            let status = RegisterEventHotKey(UInt32(key.keyCode), UInt32(key.modifiers), id, GetApplicationEventTarget(), 0, &ref)
            if status == noErr, let ref {
                hotKeys.append(ref)
            } else {
                failed.append(key.label)
            }
        }
        if failed.isEmpty {
            log("hotkey", "simulated input ready: ⌃⌥←/→ turn, ⌃⌥⇧←/→ fast spin, ⌃⌥Space press, ⌃⌥D double press, ⌃⌥R reclaim buttons")
        } else {
            log("hotkey", "could not register \(failed.joined(separator: ", ")); another app or a system shortcut owns it")
        }
    }

    func stop() {
        hotKeys.forEach { UnregisterEventHotKey($0) }
        hotKeys.removeAll()
        if let handler { RemoveEventHandler(handler) }
        handler = nil
    }

    private func fire(_ id: UInt32) {
        guard let key = Key(rawValue: id) else { return }
        log("hotkey", key.label)
        switch key {
        case .left: onEvent?(.turn(-1))
        case .right: onEvent?(.turn(1))
        case .fastLeft: spin(-1)
        case .fastRight: spin(1)
        case .press: onEvent?(.press)
        case .doublePress: onEvent?(.doublePress)
        case .reclaim: onReclaim?()
        }
    }

    private func spin(_ direction: Int) {
        for i in 0..<Self.fastSpinSteps {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * Self.fastSpinInterval) { [weak self] in
                self?.onEvent?(.turn(direction))
            }
        }
    }
}
