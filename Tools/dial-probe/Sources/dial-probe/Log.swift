import Foundation

/// Timestamped, line-buffered logging. Every line carries wall-clock time with
/// milliseconds and milliseconds since launch, so logs can be lined up with
/// what was done on the dial.
enum Log {
    static let start = Date()

    private static let clock: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    static func line(_ tag: String, _ message: String) {
        let now = Date()
        let sinceStart = Int(now.timeIntervalSince(start) * 1000)
        let paddedTag = tag.padding(toLength: 9, withPad: " ", startingAt: 0)
        print("\(clock.string(from: now))  +\(String(format: "%7d", sinceStart))ms  [\(paddedTag)] \(message)")
    }

    static func plain(_ message: String = "") {
        print(message)
    }
}

/// Counts of each signal, printed when the probe exits.
enum Tally {
    private static var counts: [String: Int] = [:]
    private static var order: [String] = []

    static func bump(_ key: String) {
        if counts[key] == nil { order.append(key) }
        counts[key, default: 0] += 1
    }

    static func printSummary() {
        Log.plain()
        Log.plain("── summary ──────────────────────────────")
        if order.isEmpty {
            Log.plain("  no signals received")
        }
        for key in order {
            Log.plain("  \(key.padding(toLength: 34, withPad: " ", startingAt: 0)) \(counts[key]!)")
        }
    }
}

extension UInt32 {
    /// Four-character code, e.g. 'blue' for kAudioDeviceTransportTypeBluetooth.
    var fourCC: String {
        let bytes = [24, 16, 8, 0].map { UInt8((self >> $0) & 0xFF) }
        if bytes.allSatisfy({ $0 >= 0x20 && $0 < 0x7F }) {
            return "'" + String(decoding: bytes, as: UTF8.self) + "'"
        }
        return String(format: "0x%08X", self)
    }
}
