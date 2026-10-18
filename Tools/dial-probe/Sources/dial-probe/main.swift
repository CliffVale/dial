import AppKit
import Foundation

// dial-probe: logs every signal the CMF Smart Dial might produce on the Mac,
// so Phase 1 can be built on what actually arrives.

setvbuf(stdout, nil, _IOLBF, 0)

let usage = """
usage: dial-probe [--now-playing] [--park <0..1>] [--verbose]

  --now-playing   become the Now Playing app (silent player) and log
                  MPRemoteCommandCenter commands
  --park <value>  after every volume change, set the volume back to <value>
                  (e.g. 0.5), to test the midpoint reset
  --verbose       also log system-defined events other than media keys

Ctrl-C prints a summary of every signal seen.
"""

var nowPlaying = false
var parkAt: Float32?
var verbose = false

var args = CommandLine.arguments.dropFirst().makeIterator()
while let arg = args.next() {
    switch arg {
    case "--now-playing":
        nowPlaying = true
    case "--park":
        guard let raw = args.next(), let value = Float32(raw), (0.0...1.0).contains(value) else {
            print("--park needs a value between 0 and 1\n\n\(usage)")
            exit(2)
        }
        parkAt = value
    case "--verbose":
        verbose = true
    case "-h", "--help":
        print(usage)
        exit(0)
    default:
        print("unknown option \(arg)\n\n\(usage)")
        exit(2)
    }
}

let app = NSApplication.shared
// Accessory keeps us out of the Dock but still a full app, which MediaRemote
// needs to treat us as Now Playing.
app.setActivationPolicy(nowPlaying ? .accessory : .prohibited)

Log.plain("dial-probe  started \(Date())")
Log.plain("options: now-playing=\(nowPlaying ? "on" : "off")  park=\(parkAt.map { String($0) } ?? "off")  verbose=\(verbose ? "on" : "off")")
Log.plain("Ctrl-C to stop and print a summary.")
Log.plain()

let tap = MediaKeyTap(verbose: verbose)
if tap.start() {
    Log.line("tap", "media key tap running")
} else {
    Log.line("tap", "COULD NOT create the event tap. Grant Input Monitoring to your terminal app in")
    Log.line("tap", "System Settings → Privacy & Security → Input Monitoring, then quit and reopen the terminal.")
    Log.line("tap", "Continuing without media key logging.")
}

let audio = AudioWatcher(parkAt: parkAt, verbose: verbose)
audio.start()

var nowPlayingProbe: NowPlayingProbe?
if nowPlaying {
    nowPlayingProbe = NowPlayingProbe()
    nowPlayingProbe?.start()
}

Log.line("ready", "waiting for the dial… (type a note and press Return to add a MARK line)")

// Typed notes become MARK lines, so each block of gestures is labelled in the log.
let stdinSource = DispatchSource.makeReadSource(fileDescriptor: STDIN_FILENO, queue: .main)
stdinSource.setEventHandler {
    guard let line = readLine() else {
        stdinSource.cancel()
        return
    }
    Log.line("MARK", "──── \(line.isEmpty ? "(mark)" : line) ────")
}
stdinSource.resume()

signal(SIGINT, SIG_IGN)
let sigint = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
sigint.setEventHandler {
    Tally.printSummary()
    exit(0)
}
sigint.resume()

app.run()
