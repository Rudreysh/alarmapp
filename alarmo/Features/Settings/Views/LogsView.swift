import SwiftUI

/// On-device diagnostics log viewer (Settings → Alarm → Logs). Shows timestamped
/// events for the keep-alive, alarm takeover, and overnight termination reasons so
/// behavior can be verified on a physical device without Xcode attached.
///
/// Performance: the full log can be up to ~512KB. It is loaded off the main thread and
/// only the most recent `maxDisplayLines` are rendered, in a lazy `List` (one row per
/// line) rather than a single huge `Text`. Use Export for the complete file.
struct LogsView: View {
    private struct LogLine: Identifiable { let id: Int; let text: String }

    @State private var lines: [LogLine] = []
    @State private var truncated = false
    @State private var isLoading = false
    @State private var newestFirst = true

    private let maxDisplayLines = 1500

    var body: some View {
        VStack(spacing: 0) {
            controlBar
            Divider()
            content
        }
        .navigationTitle("Logs")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: reload)
    }

    @ViewBuilder
    private var content: some View {
        if lines.isEmpty {
            Spacer()
            Text(isLoading ? "Loading…" : "No logs yet.")
                .foregroundColor(.secondary)
            Spacer()
        } else {
            List {
                if truncated {
                    Text("Showing last \(maxDisplayLines) lines — Export for the full log.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                ForEach(displayedLines) { line in
                    Text(line.text)
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .textSelection(.enabled)
                        .listRowInsets(EdgeInsets(top: 1, leading: 12, bottom: 1, trailing: 12))
                        .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
        }
    }

    private var controlBar: some View {
        HStack(spacing: 16) {
            Button { reload() } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            Button { newestFirst.toggle() } label: {
                Label(newestFirst ? "Newest" : "Oldest", systemImage: "arrow.up.arrow.down")
            }
            Spacer()
            if let url = DiagnosticsLog.shared.fileURL {
                ShareLink(item: url) {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
            }
            Button(role: .destructive) {
                DiagnosticsLog.shared.clear()
                lines = []
                truncated = false
            } label: {
                Label("Clear", systemImage: "trash")
            }
        }
        .font(.footnote)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var displayedLines: [LogLine] {
        newestFirst ? lines.reversed() : lines
    }

    private func reload() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let contents = DiagnosticsLog.shared.contents()
            var all = contents
                .split(separator: "\n", omittingEmptySubsequences: false)
                .map(String.init)
            if all.last == "" { all.removeLast() }
            let didTruncate = all.count > maxDisplayLines
            if didTruncate { all = Array(all.suffix(maxDisplayLines)) }
            let mapped = all.enumerated().map { LogLine(id: $0.offset, text: $0.element) }
            DispatchQueue.main.async {
                self.lines = mapped
                self.truncated = didTruncate
                self.isLoading = false
            }
        }
    }
}
