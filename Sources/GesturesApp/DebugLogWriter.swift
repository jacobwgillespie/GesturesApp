import Foundation

final class DebugLogWriter: @unchecked Sendable {
    static let shared = DebugLogWriter()

    let logFileURL: URL

    private let queue = DispatchQueue(label: "Gestures.DebugLogWriter")
    private let stateLock = NSLock()
    private let formatter: ISO8601DateFormatter
    private var isEnabled = false

    private init() {
        let baseDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Gestures", isDirectory: true)
            .appendingPathComponent("Logs", isDirectory: true)
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent("GesturesLogs", isDirectory: true)

        try? FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        logFileURL = baseDirectory.appendingPathComponent("debug.log", isDirectory: false)
        if !FileManager.default.fileExists(atPath: logFileURL.path) {
            FileManager.default.createFile(atPath: logFileURL.path, contents: nil)
        }

        formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }

    func append(_ message: String) {
        guard stateLock.withLock({ isEnabled }) else { return }
        let line = "[\(formatter.string(from: Date()))] \(message)\n"
        queue.async { [logFileURL] in
            guard let data = line.data(using: .utf8) else { return }
            if let handle = try? FileHandle(forWritingTo: logFileURL) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
            } else {
                try? data.write(to: logFileURL, options: .atomic)
            }
        }
    }

    func setEnabled(_ enabled: Bool) {
        stateLock.withLock {
            isEnabled = enabled
        }
    }

    func clear() {
        queue.async { [logFileURL] in
            try? Data().write(to: logFileURL, options: .atomic)
        }
    }
}

private extension NSLock {
    func withLock<T>(_ operation: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try operation()
    }
}
