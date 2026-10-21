import AudioToolbox
import CoreAudio
import Foundation

/// Turns the buds' output volume into a rotary encoder.
///
/// Phase 0 showed each dial click moves the virtual main volume by one 1/16
/// step, right up and left down. At 0% or 100% the listener still fires but
/// the value can't move, so the direction is lost. While `parking` is on, every
/// change is followed by writing the park value back, which keeps the dial in
/// range. Our own write fires the listener too (about 8 times, 10–35 ms later);
/// those echoes are ignored.
final class VolumeEncoder: InputSource {
    let name = "volume"
    var onEvent: ((DialEvent) -> Void)?

    /// Called when the buds become (or stop being) the default output.
    var onDeviceChange: ((String?) -> Void)?

    /// Matched against the default output's name; the device must also be Bluetooth.
    static let deviceName = "CMF Buds"
    static let step: Float32 = 1.0 / 16
    /// The park value stays within this range so a turn never hits a limit.
    static let parkRange: ClosedRange<Float32> = 0.25...0.75

    /// Steps for one volume report: parked, each report is exactly one click;
    /// unparked, quick clicks can merge into one report of two steps.
    static func steps(forDelta delta: Float32, parked: Bool) -> Int {
        if parked { return 1 }
        return max(1, Int((abs(delta) / Self.step).rounded()))
    }

    private static let echoWindow: TimeInterval = 0.4
    private static let echoTolerance: Float32 = 0.032
    private static let burstWindow: TimeInterval = 0.05

    /// On in every state except rest and Volume mode.
    var parking = false {
        didSet {
            guard parking != oldValue else { return }
            parking ? beginParking() : endParking()
        }
    }

    private(set) var deviceLabel: String?

    /// The buds' volume right now, or nil when they aren't the output.
    var currentVolume: Float? { readVolume() }
    private(set) var parkValue: Float32?

    private let system = AudioObjectID(kAudioObjectSystemObject)
    private var device: AudioDeviceID = kAudioObjectUnknown
    private var volumeAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
    )
    private var volumeListener: AudioObjectPropertyListenerBlock?
    private var defaultOutputListener: AudioObjectPropertyListenerBlock?

    private var lastValue: Float32?
    private var lastNotify: Date?
    private var lastWrite: (value: Float32, at: Date)?
    /// The listening volume before parking began, restored when parking ends.
    private var userVolume: Float32?

    func start() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            self?.attachToDefaultOutput(reason: "default output changed")
        }
        defaultOutputListener = listener
        AudioObjectAddPropertyListenerBlock(system, &address, .main, listener)
        attachToDefaultOutput(reason: "start")
    }

    func stop() {
        if parking { endParking() }
        detach()
        if let listener = defaultOutputListener {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectRemovePropertyListenerBlock(system, &address, .main, listener)
            defaultOutputListener = nil
        }
    }

    // MARK: - Device

    private func attachToDefaultOutput(reason: String) {
        let newDevice = readDefaultOutput()
        if newDevice == device, volumeListener != nil { return }
        detach()

        guard newDevice != kAudioObjectUnknown else {
            log("volume", "\(reason): no default output; turns are off")
            setDeviceLabel(nil)
            return
        }
        let name = readName(newDevice) ?? "?"
        let transport = readTransport(newDevice)
        let isBluetooth = transport == kAudioDeviceTransportTypeBluetooth || transport == kAudioDeviceTransportTypeBluetoothLE
        guard isBluetooth, name.localizedCaseInsensitiveContains(Self.deviceName) else {
            log("volume", "\(reason): default output is \"\(name)\", not the buds; turns are off until the buds are the output")
            setDeviceLabel(nil)
            return
        }
        guard AudioObjectHasProperty(newDevice, &volumeAddress) else {
            log("volume", "\(reason): \"\(name)\" has no virtual main volume; turns are off")
            setDeviceLabel(nil)
            return
        }

        device = newDevice
        lastValue = readVolume()
        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in self?.volumeChanged() }
        volumeListener = listener
        AudioObjectAddPropertyListenerBlock(device, &volumeAddress, .main, listener)
        log("volume", "\(reason): listening to \"\(name)\" (id \(device)), volume \(fmt(lastValue))")
        setDeviceLabel(name)

        if parking {
            // A fresh device: take its volume as the listening volume.
            userVolume = nil
            beginParking()
        }
    }

    private func detach() {
        if let listener = volumeListener, device != kAudioObjectUnknown {
            AudioObjectRemovePropertyListenerBlock(device, &volumeAddress, .main, listener)
        }
        volumeListener = nil
        device = kAudioObjectUnknown
        lastValue = nil
        lastNotify = nil
        lastWrite = nil
        parkValue = nil
    }

    private func setDeviceLabel(_ label: String?) {
        deviceLabel = label
        onDeviceChange?(label)
    }

    // MARK: - Parking

    private func beginParking() {
        guard device != kAudioObjectUnknown, let current = readVolume() else { return }
        if userVolume == nil { userVolume = current }
        let target = min(max(current, Self.parkRange.lowerBound), Self.parkRange.upperBound)
        parkValue = target
        log("park", "parking on: holding volume at \(fmt(target)) (listening volume \(fmt(userVolume)))")
        if abs(current - target) > 0.001 { write(target) }
    }

    private func endParking() {
        parkValue = nil
        guard device != kAudioObjectUnknown else {
            userVolume = nil
            return
        }
        if let restore = userVolume {
            log("park", "parking off: restoring listening volume \(fmt(restore))")
            if let current = readVolume(), abs(current - restore) > 0.001 { write(restore) }
        } else {
            log("park", "parking off")
        }
        userVolume = nil
    }

    // MARK: - Changes

    private func volumeChanged() {
        guard let value = readVolume() else { return }
        let now = Date()
        let previous = lastValue
        lastValue = value

        // CoreAudio fires once per channel a few ms apart; collapse the burst.
        let inBurst = lastNotify.map { now.timeIntervalSince($0) < Self.burstWindow } ?? false
        lastNotify = now

        if let write = lastWrite, now.timeIntervalSince(write.at) < Self.echoWindow, abs(value - write.value) < Self.echoTolerance {
            return
        }

        let delta = previous.map { value - $0 } ?? 0
        if delta == 0 {
            if !inBurst {
                log("volume", "notified at \(fmt(value)) with no change (at 0% or 100%?); direction unknown, ignored")
            }
            return
        }

        let steps = Self.steps(forDelta: delta, parked: parking)
        let signed = delta > 0 ? steps : -steps
        log("volume", "\(fmt(previous)) → \(fmt(value))  Δ\(String(format: "%+.4f", delta))  → turn(\(signed > 0 ? "+" : "")\(signed))")
        onEvent?(.turn(signed))

        if parking, let parkValue {
            write(parkValue)
        }
    }

    private func write(_ value: Float32) {
        var v = value
        let status = AudioObjectSetPropertyData(device, &volumeAddress, 0, nil, UInt32(MemoryLayout<Float32>.size), &v)
        if status == noErr {
            lastWrite = (value, Date())
            lastValue = value
        } else {
            log("volume", "could not set volume to \(fmt(value)): OSStatus \(status)")
        }
    }

    // MARK: - CoreAudio reads

    private func readVolume() -> Float32? {
        guard device != kAudioObjectUnknown else { return nil }
        var value: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        guard AudioObjectGetPropertyData(device, &volumeAddress, 0, nil, &size, &value) == noErr else { return nil }
        return value
    }

    private func readDefaultOutput() -> AudioDeviceID {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var id = AudioDeviceID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &id) == noErr else { return kAudioObjectUnknown }
        return id
    }

    private func readName(_ id: AudioDeviceID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var name: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &name) == noErr, let name else { return nil }
        return name.takeRetainedValue() as String
    }

    private func readTransport(_ id: AudioDeviceID) -> UInt32 {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var transport: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        AudioObjectGetPropertyData(id, &address, 0, nil, &size, &transport)
        return transport
    }

    private func fmt(_ v: Float32?) -> String {
        v.map { String(format: "%.4f", $0) } ?? "?"
    }
}
