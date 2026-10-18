import AVFoundation
import MediaPlayer

/// Registers as the Now Playing app by playing silence, then logs every
/// MPRemoteCommandCenter command that reaches it.
///
/// macOS sends headphone buttons to whichever app last became Now Playing, so
/// start Spotify *before* the probe to test the probe winning, or press play in
/// Spotify *after* the probe to test Spotify taking over.
final class NowPlayingProbe {
    private let engine = AVAudioEngine()
    private var isPlaying = true

    func start() {
        startSilence()
        registerCommands()
        publishNowPlaying()
        Log.line("nowplay", "registered as Now Playing (title \"dial-probe\"), playing silence")
    }

    private func startSilence() {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
        let source = AVAudioSourceNode(format: format) { _, _, _, bufferList in
            for buffer in UnsafeMutableAudioBufferListPointer(bufferList) {
                if let data = buffer.mData { memset(data, 0, Int(buffer.mDataByteSize)) }
            }
            return noErr
        }
        engine.attach(source)
        engine.connect(source, to: engine.mainMixerNode, format: format)
        do {
            try engine.start()
        } catch {
            Log.line("nowplay", "could not start silent player: \(error)")
        }
    }

    private func registerCommands() {
        let center = MPRemoteCommandCenter.shared()

        register(center.togglePlayPauseCommand, "togglePlayPause") { [weak self] in self?.setPlaying(!(self?.isPlaying ?? true)) }
        register(center.playCommand, "play") { [weak self] in self?.setPlaying(true) }
        register(center.pauseCommand, "pause") { [weak self] in self?.setPlaying(false) }
        register(center.stopCommand, "stop") { [weak self] in self?.setPlaying(false) }
        register(center.nextTrackCommand, "nextTrack")
        register(center.previousTrackCommand, "previousTrack")
        register(center.changeRepeatModeCommand, "changeRepeatMode")
        register(center.changeShuffleModeCommand, "changeShuffleMode")
        register(center.likeCommand, "like")
        register(center.dislikeCommand, "dislike")
        register(center.bookmarkCommand, "bookmark")

        center.seekForwardCommand.isEnabled = true
        center.seekForwardCommand.addTarget { event in
            Self.logSeek("seekForward", event)
            return .success
        }
        center.seekBackwardCommand.isEnabled = true
        center.seekBackwardCommand.addTarget { event in
            Self.logSeek("seekBackward", event)
            return .success
        }
        center.changePlaybackPositionCommand.isEnabled = true
        center.changePlaybackPositionCommand.addTarget { event in
            let time = (event as? MPChangePlaybackPositionCommandEvent)?.positionTime ?? -1
            Log.line("command", "changePlaybackPosition to \(String(format: "%.1f", time))s")
            Tally.bump("command changePlaybackPosition")
            return .success
        }
        center.changePlaybackRateCommand.isEnabled = true
        center.changePlaybackRateCommand.addTarget { event in
            let rate = (event as? MPChangePlaybackRateCommandEvent)?.playbackRate ?? -1
            Log.line("command", "changePlaybackRate to \(rate)")
            Tally.bump("command changePlaybackRate")
            return .success
        }
        // Skip commands stay disabled, like a music app; with them on, macOS
        // can send skipForward where we expect nextTrack.
    }

    private func register(_ command: MPRemoteCommand, _ name: String, then action: (() -> Void)? = nil) {
        command.isEnabled = true
        command.addTarget { _ in
            Log.line("command", name)
            Tally.bump("command \(name)")
            action?()
            return .success
        }
    }

    private static func logSeek(_ name: String, _ event: MPRemoteCommandEvent) {
        let phase = (event as? MPSeekCommandEvent).map { $0.type == .beginSeeking ? "begin" : "end" } ?? "?"
        Log.line("command", "\(name) \(phase)")
        Tally.bump("command \(name) \(phase)")
    }

    private func setPlaying(_ playing: Bool) {
        isPlaying = playing
        MPNowPlayingInfoCenter.default().playbackState = playing ? .playing : .paused
        publishNowPlaying()
        Log.line("nowplay", "state now \(playing ? "playing" : "paused") (silence keeps running so we stay Now Playing)")
    }

    private func publishNowPlaying() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: "dial-probe",
            MPMediaItemPropertyArtist: "Dial",
            MPMediaItemPropertyPlaybackDuration: 3600.0,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: 0.0,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
        ]
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
    }
}
