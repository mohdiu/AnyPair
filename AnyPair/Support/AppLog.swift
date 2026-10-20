import Foundation

/// Small append-only log of the app side of a pairing (Bonjour, relay, result).
/// Shared together with idevice's log when a pairing fails.
enum AppLog {
    static var url: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("anypair-app-log.txt")
    }

    private static let queue = DispatchQueue(label: "anypair.log")
    private static let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static func write(_ message: String) {
        NSLog("[AnyPair] %@", message)
        let line = "\(formatter.string(from: Date())) \(message)\n"
        queue.async {
            guard let data = line.data(using: .utf8) else { return }
            if let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            } else {
                try? data.write(to: url)
            }
        }
    }

    static func reset() {
        queue.sync { try? FileManager.default.removeItem(at: url) }
    }

    /// Both logs that exist, for the share sheet.
    static var shareURLs: [URL] {
        [url, PairingLog.url].filter { FileManager.default.fileExists(atPath: $0.path) }
    }
}
