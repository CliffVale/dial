import AppKit
import Foundation

/// Press and double press from the buds.
///
/// Phase 0 showed the buds' buttons reach the Mac only as remote commands sent
/// to the Now Playing app: press arrives as play or pause, double press as
/// nextTrack. Dial runs the `dial-remote` helper (DialRemote/main.swift) as a child process to hold Now
/// Playing and turns its messages into dial events.
///
/// To pass one press on to the music app, Dial ends the helper, posts a
/// play/pause media key (which macOS now routes to the music app), then starts
/// a new helper, which takes Now Playing back.
final class RemoteCommandSource: InputSource {
    let name = "remote"
    var onEvent: ((DialEvent) -> Void)?

    /// After ending the helper, how long until macOS routes keys to the music app.
    private static let passthroughKeyDelay: TimeInterval = 0.4
    /// After posting the key, how long until the new helper starts.
    private static let passthroughReturnDelay: TimeInterval = 0.6
    /// A helper that dies on its own is restarted after this long.
    private static let restartDelay: TimeInterval = 1.0
    /// After another app starts playing, wait this long, then reclaim.
    private static let reclaimDelay: TimeInterval = 1.0
    /// Playback that starts this soon after a pass-through is the music app
    /// resuming because of it; the new helper already won Now Playing back.
    private static let passthroughQuietPeriod: TimeInterval = 2.5

    private static let helperURL = Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/dial-remote")

    private var helper: Process?
    private var buffer = Data()
    private var isPassingThrough = false
    private var lastPassthrough: Date?
    private var isStopping = false
    private var pendingReclaim: DispatchWorkItem?
    private let playbackWatcher = PlaybackWatcher()

    func start() {
        isStopping = false
        launchHelper(reason: "start")
        playbackWatcher.ignoredPIDs = { [weak self] in
            var pids: Set<pid_t> = [getpid()]
            if let helper = self?.helper { pids.insert(helper.processIdentifier) }
            return pids
        }
        playbackWatcher.onOtherAppStartedPlaying = { [weak self] pid in
            self?.otherAppStartedPlaying(pid)
        }
        playbackWatcher.start()
    }

    func stop() {
        isStopping = true
        endHelper()
    }

    /// Starts a new helper, to win Now Playing back from an app that started
    /// playing after Dial.
    func reclaim() {
        log("remote", "reclaiming Now Playing with a new helper")
        endHelper()
        launchHelper(reason: "reclaim")
    }

    private func otherAppStartedPlaying(_ pid: pid_t) {
        let name = NSRunningApplication(processIdentifier: pid)?.localizedName ?? "pid \(pid)"
        if isPassingThrough || lastPassthrough.map({ Date().timeIntervalSince($0) < Self.passthroughQuietPeriod }) == true {
            log("remote", "\(name) started playing after a pass-through; no reclaim needed")
            return
        }
        log("remote", "\(name) started playing; reclaiming the buttons in \(Self.reclaimDelay)s")
        pendingReclaim?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.reclaim() }
        pendingReclaim = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.reclaimDelay, execute: work)
    }

    // MARK: - Passing a press to the music app

    func passPlayPauseToMediaApp() {
        guard !isPassingThrough else {
            log("remote", "press pass-through already running; ignored")
            return
        }
        guard Permissions.ensureAccessibility(reason: "pass the dial press to your music app") else { return }

        log("remote", "passing play/pause to the music app: ending the Now Playing helper")
        isPassingThrough = true
        lastPassthrough = Date()
        pendingReclaim?.cancel()
        endHelper()

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.passthroughKeyDelay) {
            SystemControls.postMediaKey(.playPause)
            log("remote", "posted play/pause media key")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.passthroughKeyDelay + Self.passthroughReturnDelay) { [weak self] in
            guard let self else { return }
            self.isPassingThrough = false
            self.launchHelper(reason: "pass-through done")
        }
    }

    // MARK: - Helper process

    private func launchHelper(reason: String) {
        guard !isStopping, helper == nil else { return }

        let process = Process()
        process.executableURL = Self.helperURL
        let output = Pipe()
        process.standardOutput = output
        // The helper exits when this pipe closes, so it never outlives Dial.
        process.standardInput = Pipe()
        process.standardError = FileHandle.nullDevice

        output.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            DispatchQueue.main.async { self?.received(data) }
        }
        process.terminationHandler = { [weak self] ended in
            DispatchQueue.main.async { self?.helperEnded(ended) }
        }

        do {
            try process.run()
            helper = process
            log("remote", "\(reason): started Now Playing helper (pid \(process.processIdentifier))")
        } catch {
            log("remote", "\(reason): could not start the Now Playing helper: \(error.localizedDescription)")
        }
    }

    private func endHelper() {
        guard let process = helper else { return }
        helper = nil
        (process.standardOutput as? Pipe)?.fileHandleForReading.readabilityHandler = nil
        if process.isRunning {
            // SIGKILL: the helper must be gone at once for the key to route
            // past it, and it holds nothing that needs cleaning up.
            kill(process.processIdentifier, SIGKILL)
        }
        buffer.removeAll()
    }

    private func helperEnded(_ process: Process) {
        // Only an unexpected exit of the current helper needs a restart.
        guard process === helper else { return }
        helper = nil
        log("remote", "Now Playing helper exited unexpectedly (status \(process.terminationStatus)); restarting")
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.restartDelay) { [weak self] in
            self?.launchHelper(reason: "restart")
        }
    }

    private func received(_ data: Data) {
        buffer.append(data)
        while let newline = buffer.firstIndex(of: UInt8(ascii: "\n")) {
            let line = String(decoding: buffer[buffer.startIndex..<newline], as: UTF8.self)
            buffer.removeSubrange(buffer.startIndex...newline)
            handle(line)
        }
    }

    private func handle(_ line: String) {
        if line.hasPrefix("press ") {
            log("remote", "\(line.dropFirst("press ".count)) → press")
            onEvent?(.press)
        } else if line == "double" {
            log("remote", "nextTrack → doublePress")
            onEvent?(.doublePress)
        } else if line.hasPrefix("log ") {
            log("helper", String(line.dropFirst("log ".count)))
        } else if !line.isEmpty {
            log("helper", line)
        }
    }
}
