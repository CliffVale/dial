import AVFoundation
import AppKit
import MediaPlayer

// dial-remote: Dial's Now Playing helper, run by Dial from
// Dial.app/Contents/Helpers. Its own bundle id (com.art.dial.remote) keeps
// Apple events meant for Dial, like quit, from reaching it.

/// Runs in a separate process and owns Now Playing.
///
/// Phase 1 tests showed macOS keeps sending the buds' buttons to an app that
/// was Now Playing even after it stops, so the only way to let a press reach
/// the music app is for the Now Playing process to exit. Keeping that role in
/// a helper lets Dial end it and start a new one, which wins Now Playing back
/// just as a fresh launch does.
///
/// Talks to Dial over stdout, one line per message:
///   press <command>   play, pause or togglePlayPause
///   double            nextTrack
///   log <text>
/// Exits when stdin closes, so it never outlives Dial.
enum NowPlayingHelper {
    private static var engine = AVAudioEngine()
    private static var configObserver: NSObjectProtocol?

    static func run() -> Never {
        setvbuf(stdout, nil, _IOLBF, 0)
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        registerCommands()
        startPlayer()
        send("log registered as Now Playing (pid \(getpid()))")

        // Dial holds our stdin; when it quits or crashes, stdin closes.
        let stdinSource = DispatchSource.makeReadSource(fileDescriptor: STDIN_FILENO, queue: .main)
        stdinSource.setEventHandler {
            if readLine() == nil { exit(0) }
        }
        stdinSource.resume()
        withExtendedLifetime(stdinSource) {
            app.run()
        }
        exit(0)
    }

    private static func send(_ line: String) {
        print(line)
    }

    private static func registerCommands() {
        let center = MPRemoteCommandCenter.shared()
        for (command, label) in [
            (center.togglePlayPauseCommand, "togglePlayPause"),
            (center.playCommand, "play"),
            (center.pauseCommand, "pause"),
        ] {
            command.isEnabled = true
            command.addTarget { _ in
                send("press \(label)")
                // Stay "playing" whatever was asked, so we keep Now Playing.
                publish()
                return .success
            }
        }
        center.nextTrackCommand.isEnabled = true
        center.nextTrackCommand.addTarget { _ in
            send("double")
            return .success
        }
        // Not mapped yet; reported so we notice if the buds ever send them.
        for (command, label) in [
            (center.previousTrackCommand, "previousTrack"),
            (center.stopCommand, "stop"),
        ] {
            command.isEnabled = true
            command.addTarget { _ in
                send("log \(label) received (not mapped)")
                return .success
            }
        }
    }

    private static func startPlayer() {
        engine.stop()
        engine = AVAudioEngine()
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
        let node = AVAudioSourceNode(format: format) { _, _, _, bufferList in
            for buffer in UnsafeMutableAudioBufferListPointer(bufferList) {
                if let data = buffer.mData { memset(data, 0, Int(buffer.mDataByteSize)) }
            }
            return noErr
        }
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        do {
            try engine.start()
        } catch {
            send("log could not start the silent player: \(error.localizedDescription)")
        }

        if let configObserver { NotificationCenter.default.removeObserver(configObserver) }
        configObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
        ) { _ in
            // The output changed (buds reconnected, another device chosen) and
            // the engine stopped itself.
            send("log audio configuration changed; restarting the silent player")
            startPlayer()
        }
        publish()
    }

    private static func publish() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: "Dial",
            MPMediaItemPropertyArtist: "Smart Dial control",
            // A plain long track. A zero-length live stream is ignored by
            // macOS, and the buttons never arrive.
            MPMediaItemPropertyPlaybackDuration: 3600.0,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: 0.0,
            MPNowPlayingInfoPropertyPlaybackRate: 1.0,
        ]
        MPNowPlayingInfoCenter.default().playbackState = .playing
    }
}

NowPlayingHelper.run()
