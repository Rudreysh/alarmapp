import Foundation

/// Lightweight, thread-safe log throttling utility.
/// Keeps runtime behavior unchanged while reducing repetitive console noise.
enum LogThrottler {
    private struct Entry {
        var lastEmitAt: TimeInterval = 0
        var lastMessage: String = ""
        var suppressedCount: Int = 0
    }

    private static var entries: [String: Entry] = [:]
    private static let queue = DispatchQueue(label: "ht.alarmo.log-throttler")

    /// Emits at most once per `interval` for the same key+message.
    /// If messages were suppressed, emits a summary suffix on next allowed line.
    static func log(
        _ message: @autoclosure () -> String,
        key: String,
        interval: TimeInterval,
        sink: (String) -> Void = { print($0) }
    ) {
        let now = Date().timeIntervalSince1970
        var output: String?

        queue.sync {
            let text = message()
            var entry = entries[key] ?? Entry()
            let isSameMessage = (entry.lastMessage == text)
            let elapsed = now - entry.lastEmitAt

            if !isSameMessage || elapsed >= interval {
                if entry.suppressedCount > 0 && isSameMessage {
                    output = "\(text) [suppressed \(entry.suppressedCount) similar lines]"
                } else {
                    output = text
                }
                entry.lastEmitAt = now
                entry.lastMessage = text
                entry.suppressedCount = 0
            } else {
                entry.suppressedCount += 1
            }

            entries[key] = entry
        }

        if let output {
            sink(output)
        }
    }
}
