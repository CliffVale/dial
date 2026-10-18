import AudioToolbox
import CoreAudio
import Foundation

/// Watches the default output device and every volume control on it.
///
/// The virtual main volume is the primary signal and gets a direction and an
/// interval since the previous change. The main element and channels 1 and 2
/// are logged too, so we can see which of them the buds actually move.
///
/// With `parkAt`, every change that isn't our own write is followed by setting
/// the volume back to that value, to check the midpoint reset works with the
/// buds before Phase 1 depends on it.
final class AudioWatcher {
    private struct Watch {
        let label: String
        var address: AudioObjectPropertyAddress
        let isPrimary: Bool
        let block: AudioObjectPropertyListenerBlock
    }

    private let system = AudioObjectID(kAudioObjectSystemObject)
    private let parkAt: Float32?
    private let verbose: Bool

    private var device: AudioDeviceID = kAudioObjectUnknown
    private var watches: [Watch] = []
    private var lastValues: [String: Float32] = [:]
    private var lastPrimaryChange: Date?
    private var lastPrimaryNotify: Date?
    private var lastWrite: (value: Float32, at: Date)?

    init(parkAt: Float32?, verbose: Bool) {
        self.parkAt = parkAt
        self.verbose = verbose
    }

    func start() {
        listenOnSystem(kAudioHardwarePropertyDefaultOutputDevice) { [weak self] in
            self?.attachToDefaultOutput(reason: "default output changed")
        }
        listenOnSystem(kAudioHardwarePropertyDevices) { [weak self] in
            self?.logDeviceList(reason: "device list changed")
        }
        logDeviceList(reason: "startup")
        attachToDefaultOutput(reason: "startup")
    }

    // MARK: - Devices

    private func listenOnSystem(_ selector: AudioObjectPropertySelector, _ handler: @escaping () -> Void) {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectAddPropertyListenerBlock(system, &address, .main) { _, _ in handler() }
        if status != noErr {
            Log.line("audio", "failed to listen on system property \(selector.fourCC): \(status)")
        }
    }

    private func logDeviceList(reason: String) {
        let ids: [AudioDeviceID] = readArray(system, kAudioHardwarePropertyDevices, kAudioObjectPropertyScopeGlobal)
        let outputs = ids.filter { hasOutputStreams($0) }
        Log.line("devices", "\(reason): \(outputs.count) output device(s)")
        for id in outputs {
            Log.line("devices", "  id=\(id) \(describe(id))")
        }
    }

    private func attachToDefaultOutput(reason: String) {
        let newDevice: AudioDeviceID = readScalar(system, kAudioHardwarePropertyDefaultOutputDevice, kAudioObjectPropertyScopeGlobal) ?? kAudioObjectUnknown
        if newDevice == device, !watches.isEmpty { return }

        detach()
        device = newDevice
        guard device != kAudioObjectUnknown else {
            Log.line("output", "\(reason): no default output device")
            return
        }

        let isBluetooth = transportType(device).map { Self.isBluetooth($0) } ?? false
        Log.line("output", "\(reason): id=\(device) \(describe(device))\(isBluetooth ? "  ← Bluetooth" : "")")

        // Virtual main volume first: it is what the Sound menu shows and what
        // absolute volume from the buds is expected to move.
        addWatch(label: "vol.virt", selector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume, element: kAudioObjectPropertyElementMain, primary: true)
        addWatch(label: "vol.main", selector: kAudioDevicePropertyVolumeScalar, element: kAudioObjectPropertyElementMain, primary: false)
        addWatch(label: "vol.ch1", selector: kAudioDevicePropertyVolumeScalar, element: 1, primary: false)
        addWatch(label: "vol.ch2", selector: kAudioDevicePropertyVolumeScalar, element: 2, primary: false)
        addWatch(label: "mute", selector: kAudioDevicePropertyMute, element: kAudioObjectPropertyElementMain, primary: false)

        if !watches.contains(where: { $0.isPrimary }) {
            Log.line("output", "  no virtual main volume on this device; volume changes may not be observable")
        }
        let watched = watches.map { w -> String in
            if let v = readValue(w) { return "\(w.label)=\(Self.fmt(v))" }
            return w.label
        }
        Log.line("output", "  watching: \(watched.joined(separator: "  "))")

        if let parkAt, watches.contains(where: { $0.isPrimary }) {
            Log.line("park", "parking volume at \(Self.fmt(parkAt)) after every turn")
            writePrimary(parkAt)
        }
    }

    private func addWatch(label: String, selector: AudioObjectPropertySelector, element: AudioObjectPropertyElement, primary: Bool) {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioDevicePropertyScopeOutput, mElement: element)
        guard AudioObjectHasProperty(device, &address) else { return }

        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            self?.changed(label: label)
        }
        let status = AudioObjectAddPropertyListenerBlock(device, &address, .main, block)
        guard status == noErr else {
            Log.line("output", "  failed to listen on \(label): \(status)")
            return
        }
        let watch = Watch(label: label, address: address, isPrimary: primary, block: block)
        watches.append(watch)
        lastValues[label] = readValue(watch)
    }

    private func detach() {
        for var w in watches {
            AudioObjectRemovePropertyListenerBlock(device, &w.address, .main, w.block)
        }
        watches.removeAll()
        lastValues.removeAll()
        lastPrimaryChange = nil
        lastPrimaryNotify = nil
        lastWrite = nil
    }

    // MARK: - Changes

    private func changed(label: String) {
        guard let watch = watches.first(where: { $0.label == label }), let value = readValue(watch) else { return }
        let previous = lastValues[label]
        lastValues[label] = value

        if label == "mute" {
            Log.line("mute", "mute=\(value > 0.5 ? "on" : "off")")
            Tally.bump("mute change")
            return
        }

        let delta = previous.map { value - $0 } ?? 0
        let deltaText = String(format: "%+.4f", delta)

        guard watch.isPrimary else {
            if delta == 0, previous != nil, !verbose { return }
            Log.line(label, "\(Self.fmt(value))  Δ\(deltaText)")
            return
        }

        // Our own park write fires the listener too. Anything that lands within
        // half a 1/16 step of the value we just wrote, shortly after, is an echo.
        if let write = lastWrite, Date().timeIntervalSince(write.at) < 0.4, abs(value - write.value) < 0.032 {
            Log.line("echo", "\(Self.fmt(value))  Δ\(deltaText)  (our park write, ignored)")
            Tally.bump("park echo (ignored)")
            return
        }

        // CoreAudio fires the virtual main listener once per channel, a few ms
        // apart. Collapse those bursts, but keep a notification that arrives on
        // its own with an unchanged value: the buds may be sending something.
        let notifiedAt = Date()
        let inBurst = lastPrimaryNotify.map { notifiedAt.timeIntervalSince($0) < 0.05 } ?? false
        lastPrimaryNotify = notifiedAt
        if delta == 0, previous != nil {
            if inBurst {
                if verbose { Log.line(label, "\(Self.fmt(value))  (repeat in burst)") }
            } else {
                let gap = lastPrimaryChange.map { String(format: "%5.0fms since last change", notifiedAt.timeIntervalSince($0) * 1000) } ?? ""
                Log.line(label, "\(Self.fmt(value))  NOTIFY, value unchanged  \(gap)")
                Tally.bump("volume notify, unchanged")
            }
            return
        }

        let now = Date()
        let interval = lastPrimaryChange.map { String(format: "%5.0fms since last", now.timeIntervalSince($0) * 1000) } ?? "      first change"
        lastPrimaryChange = now

        let direction: String
        if delta > 0 { direction = "UP   → turn right?" }
        else if delta < 0 { direction = "DOWN → turn left?" }
        else { direction = "SAME (no change in value)" }

        Log.line(label, "\(Self.fmt(value))  Δ\(deltaText)  \(interval)  \(direction)")
        Tally.bump(delta > 0 ? "volume up" : delta < 0 ? "volume down" : "volume same")

        if let parkAt, abs(value - parkAt) > 0.001 {
            writePrimary(parkAt)
        }
    }

    private func writePrimary(_ value: Float32) {
        guard let watch = watches.first(where: { $0.isPrimary }) else { return }
        var address = watch.address
        var v = value
        let status = AudioObjectSetPropertyData(device, &address, 0, nil, UInt32(MemoryLayout<Float32>.size), &v)
        if status == noErr {
            lastWrite = (value, Date())
            lastValues[watch.label] = value
            Log.line("park", "wrote \(Self.fmt(value))")
        } else {
            Log.line("park", "write failed: \(status)")
        }
    }

    // MARK: - Reading properties

    private func readValue(_ watch: Watch) -> Float32? {
        var address = watch.address
        if watch.label == "mute" {
            var mute: UInt32 = 0
            var size = UInt32(MemoryLayout<UInt32>.size)
            guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &mute) == noErr else { return nil }
            return Float32(mute)
        }
        var value: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr else { return nil }
        return value
    }

    private func readScalar<T>(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector, _ scope: AudioObjectPropertyScope) -> T? {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
        var size = UInt32(MemoryLayout<T>.size)
        let pointer = UnsafeMutablePointer<T>.allocate(capacity: 1)
        defer { pointer.deallocate() }
        guard AudioObjectGetPropertyData(object, &address, 0, nil, &size, pointer) == noErr else { return nil }
        return pointer.pointee
    }

    private func readArray<T>(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector, _ scope: AudioObjectPropertyScope) -> [T] {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(object, &address, 0, nil, &size) == noErr, size > 0 else { return [] }
        let count = Int(size) / MemoryLayout<T>.stride
        let pointer = UnsafeMutablePointer<T>.allocate(capacity: count)
        defer { pointer.deallocate() }
        guard AudioObjectGetPropertyData(object, &address, 0, nil, &size, pointer) == noErr else { return [] }
        return Array(UnsafeBufferPointer(start: pointer, count: count))
    }

    private func readString(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) -> String? {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var name: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(object, &address, 0, nil, &size, &name) == noErr, let name else { return nil }
        return name.takeRetainedValue() as String
    }

    private func hasOutputStreams(_ id: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreams, mScope: kAudioDevicePropertyScopeOutput, mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        return AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size) == noErr && size > 0
    }

    private func transportType(_ id: AudioDeviceID) -> UInt32? {
        readScalar(id, kAudioDevicePropertyTransportType, kAudioObjectPropertyScopeGlobal)
    }

    private func describe(_ id: AudioDeviceID) -> String {
        let name = readString(id, kAudioObjectPropertyName) ?? "?"
        let uid = readString(id, kAudioDevicePropertyDeviceUID) ?? "?"
        let transport = transportType(id).map { $0.fourCC } ?? "?"
        return "\"\(name)\" transport=\(transport) uid=\(uid)"
    }

    private static func isBluetooth(_ transport: UInt32) -> Bool {
        transport == kAudioDeviceTransportTypeBluetooth || transport == kAudioDeviceTransportTypeBluetoothLE
    }

    private static func fmt(_ v: Float32) -> String {
        String(format: "%.4f", v)
    }
}
