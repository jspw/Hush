import Foundation

enum HushLogger {
    private static let queue = DispatchQueue(label: "hush.logger", qos: .utility)
    private static let retentionDays = 7

    private static let timestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private static let fileDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    static let logDirectory: URL = {
        let libraryURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        let url = libraryURL.appendingPathComponent("Logs/Hush", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    static func start() {
        queue.async { pruneOldLogs() }
        log("=== Hush session started ===")
    }

    static func log(_ message: String) {
        let timestamp = timestampFormatter.string(from: Date())
        let line = "[\(timestamp)] \(message)"
        print("[Hush] \(message)")
        queue.async { writeLine(line) }
    }

    private static func currentLogFileURL() -> URL {
        let name = "hush-\(fileDateFormatter.string(from: Date())).log"
        return logDirectory.appendingPathComponent(name)
    }

    private static func writeLine(_ line: String) {
        let url = currentLogFileURL()
        guard let data = (line + "\n").data(using: .utf8) else { return }
        if FileManager.default.fileExists(atPath: url.path) {
            guard let handle = try? FileHandle(forWritingTo: url) else { return }
            defer { try? handle.close() }
            try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: url)
        }
    }

    private static func pruneOldLogs() {
        let cutoff = Date().addingTimeInterval(-Double(retentionDays) * 86_400)
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: logDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return }
        for url in contents where url.pathExtension == "log" {
            guard let mtime = try? url.resourceValues(forKeys: [.contentModificationDateKey])
                    .contentModificationDate,
                  mtime < cutoff else { continue }
            try? FileManager.default.removeItem(at: url)
        }
    }
}

func hushLog(_ message: String) {
    HushLogger.log(message)
}
