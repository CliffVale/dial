import Foundation
import Observation

/// Timestamped log shown in the debug window, echoed to stdout and written to
/// ~/Library/Logs/Dial/dial.log so a session can be shared after the fact.
@Observable
final class DebugLog {
    static let shared = DebugLog()

    struct Entry: Identifiable {
        let id: Int
        let text: String
    }

    private(set) var entries: [Entry] = []

    @ObservationIgnored let fileURL: URL
    @ObservationIgnored private var file: FileHandle?
    @ObservationIgnored private var nextID = 0
    @ObservationIgnored private let start = Date()
    @ObservationIgnored private let clock: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    private static let maxEntries = 3000

    private init() {
        let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/Dial", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("dial.log")

        // Keep one previous session around; start each launch with a fresh file.
        let previous = dir.appendingPathComponent("dial.previous.log")
        try? FileManager.default.removeItem(at: previous)
        try? FileManager.default.moveItem(at: fileURL, to: previous)
        FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        file = try? FileHandle(forWritingTo: fileURL)
    }

    func log(_ tag: String, _ message: String) {
        let now = Date()
        let sinceStart = Int(now.timeIntervalSince(start) * 1000)
        let paddedTag = tag.padding(toLength: 8, withPad: " ", startingAt: 0)
        let line = "\(clock.string(from: now))  +\(String(format: "%7d", sinceStart))ms  [\(paddedTag)] \(message)"

        print(line)
        file?.write(Data((line + "\n").utf8))

        let append = { [self] in
            entries.append(Entry(id: nextID, text: line))
            nextID += 1
            if entries.count > Self.maxEntries {
                entries.removeFirst(entries.count - Self.maxEntries)
            }
        }
        if Thread.isMainThread { append() } else { DispatchQueue.main.async(execute: append) }
    }

    func clear() {
        entries.removeAll()
    }

    var allText: String {
        entries.map(\.text).joined(separator: "\n")
    }
}

func log(_ tag: String, _ message: String) {
    DebugLog.shared.log(tag, message)
}
