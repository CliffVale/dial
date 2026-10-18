import CoreAudio
import Foundation

/// Notices when another app starts playing audio.
///
/// An app that starts playing after Dial becomes Now Playing and takes the
/// buds' buttons (YouTube in Chrome did this in testing). Dial reclaims them a
/// moment later, when this watcher reports the new playback.
///
/// Uses CoreAudio's per-process objects, macOS 14.2 and later. On 14.0–14.1
/// it does nothing and ⌃⌥R / "Reclaim Media Buttons" stay the way back.
final class PlaybackWatcher {
    /// Called on the main queue with the pid of the app that started playing.
    var onOtherAppStartedPlaying: ((pid_t) -> Void)?
    /// Pids that never count: Dial and its Now Playing helper.
    var ignoredPIDs: () -> Set<pid_t> = { [getpid()] }

    private let system = AudioObjectID(kAudioObjectSystemObject)
    private var watched: [AudioObjectID: (pid: pid_t, running: Bool, listener: AudioObjectPropertyListenerBlock)] = [:]
    private var listListener: AudioObjectPropertyListenerBlock?

    func start() {
        guard #available(macOS 14.2, *) else {
            log("watch", "macOS before 14.2: can't see other apps' playback; use ⌃⌥R to reclaim the buttons")
            return
        }
        var address = Self.address(kAudioHardwarePropertyProcessObjectList)
        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in self?.refreshProcesses() }
        listListener = listener
        AudioObjectAddPropertyListenerBlock(system, &address, .main, listener)
        refreshProcesses(isInitial: true)
    }

    @available(macOS 14.2, *)
    private func refreshProcesses(isInitial: Bool = false) {
        let current = Set(processObjects())
        for (object, entry) in watched where !current.contains(object) {
            var address = Self.address(kAudioProcessPropertyIsRunning)
            AudioObjectRemovePropertyListenerBlock(object, &address, .main, entry.listener)
            watched[object] = nil
        }
        for object in current where watched[object] == nil {
            // IsRunningOutput changes without notifying; IsRunning notifies.
            var address = Self.address(kAudioProcessPropertyIsRunning)
            let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in self?.outputChanged(object) }
            guard AudioObjectAddPropertyListenerBlock(object, &address, .main, listener) == noErr else { continue }
            let pid = pid(of: object)
            let running = isRunningOutput(object)
            watched[object] = (pid, running, listener)
            // A process new to CoreAudio is often already playing by the time
            // it appears, so it never reports a change from stopped.
            if running, !isInitial, !ignoredPIDs().contains(pid) {
                onOtherAppStartedPlaying?(pid)
            }
        }
    }

    @available(macOS 14.2, *)
    private func outputChanged(_ object: AudioObjectID) {
        guard var entry = watched[object] else { return }
        let running = isRunningOutput(object)
        let started = running && !entry.running
        entry.running = running
        watched[object] = entry
        guard started, !ignoredPIDs().contains(entry.pid) else { return }
        onOtherAppStartedPlaying?(entry.pid)
    }

    // MARK: - CoreAudio reads

    @available(macOS 14.2, *)
    private func processObjects() -> [AudioObjectID] {
        var address = Self.address(kAudioHardwarePropertyProcessObjectList)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr, size > 0 else { return [] }
        var objects = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &objects) == noErr else { return [] }
        return objects
    }

    @available(macOS 14.2, *)
    private func pid(of object: AudioObjectID) -> pid_t {
        var address = Self.address(kAudioProcessPropertyPID)
        var pid: pid_t = -1
        var size = UInt32(MemoryLayout<pid_t>.size)
        AudioObjectGetPropertyData(object, &address, 0, nil, &size, &pid)
        return pid
    }

    @available(macOS 14.2, *)
    private func isRunningOutput(_ object: AudioObjectID) -> Bool {
        var address = Self.address(kAudioProcessPropertyIsRunningOutput)
        var running: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        AudioObjectGetPropertyData(object, &address, 0, nil, &size, &running)
        return running != 0
    }

    private static func address(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    }
}
