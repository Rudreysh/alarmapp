import Foundation

/// Lightweight persistent, timestamped diagnostics log for on-device testing.
///
/// Appends to `Documents/Logs/alarmo-diagnostics.log` on a serial queue with a size
/// cap (keeps the most recent entries). Use for the events that are hard to observe
/// without a debugger — keep-alive lifecycle, alarm takeover, overnight termination
/// reasons. Mirrors to the Xcode console too. Viewable in Settings → Alarm → Logs.
final class DiagnosticsLog {
    static let shared = DiagnosticsLog()

    private let queue = DispatchQueue(label: "ht.alarmo.diagnosticslog")
    private let maxBytes = 512 * 1024
    private let fileName = "alarmo-diagnostics.log"

    private let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private init() {}

    /// Cached after first resolution — avoids repeating FileManager work per write.
    private var cachedURL: URL?

    var fileURL: URL? {
        if let cachedURL { return cachedURL }
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let dir = docs.appendingPathComponent("Logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(fileName, isDirectory: false)
        cachedURL = url
        return url
    }

    /// Append a timestamped line. Safe to call from any thread. Only `Date()` is
    /// captured on the caller; formatting, console mirror, and the file write all run
    /// on the serial background queue, so the caller (e.g. main during an alarm fire)
    /// is never blocked.
    func log(_ message: String, category: String = "App") {
        let now = Date()
        queue.async { [weak self] in
            guard let self else { return }
            let line = "[\(self.formatter.string(from: now))] [\(category)] \(message)\n"
            print("📋 \(line)", terminator: "")
            guard let url = self.fileURL else { return }
            self.append(line, to: url)
            self.rotateIfNeeded(url: url)
        }
    }

    /// Full current log contents (chronological). Call off the main thread if large.
    func contents() -> String {
        queue.sync {
            guard let url = fileURL, let data = try? Data(contentsOf: url) else { return "" }
            return String(data: data, encoding: .utf8) ?? ""
        }
    }

    func clear() {
        queue.async { [weak self] in
            guard let self, let url = self.fileURL else { return }
            try? Data().write(to: url)
        }
    }

    // MARK: - Private

    private func append(_ line: String, to url: URL) {
        guard let data = line.data(using: .utf8) else { return }
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            // File does not exist yet.
            try? data.write(to: url, options: .atomic)
        }
    }

    private func rotateIfNeeded(url: URL) {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int, size > maxBytes else { return }
        guard let data = try? Data(contentsOf: url) else { return }
        // Keep the most recent half, trimmed to the next line boundary.
        let keep = data.suffix(maxBytes / 2)
        var trimmed = Data(keep)
        if let nl = trimmed.firstIndex(of: 0x0A), nl + 1 < trimmed.count {
            trimmed = Data(trimmed[(nl + 1)...])
        }
        let header = "[log rotated — older entries trimmed]\n".data(using: .utf8) ?? Data()
        try? (header + trimmed).write(to: url, options: .atomic)
    }
}
