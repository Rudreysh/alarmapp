import SwiftUI

/// Settings → Alarm → Battery Monitor. Surfaces how much the silent keep-alive audio
/// runs and the battery it costs, so the keep-alive's battery impact can be measured
/// on a real device. Read-only instrumentation built on `KeepAliveBatteryMonitor` +
/// the MetricKit snapshot recorded by `AppExitDiagnostics`.
struct BatteryMonitorView: View {
    @State private var report = KeepAliveBatteryMonitor.shared.makeReport()

    var body: some View {
        List {
            nowSection
            metricKitSection
            appObservedSection
            estimateSection
            recentSection
            noteSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Battery Monitor")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { report = KeepAliveBatteryMonitor.shared.makeReport() } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .onAppear { report = KeepAliveBatteryMonitor.shared.makeReport() }
    }

    private var nowSection: some View {
        Section("Now") {
            kv("Battery", report.batteryLevelPct >= 0 ? "\(report.batteryLevelPct)%" : "Unknown")
            kv("State", report.batteryStateText)
            kv("Keep-alive", report.activeNow ? "Running" : "Idle")
        }
    }

    @ViewBuilder
    private var metricKitSection: some View {
        Section {
            if let mk = report.metricKit {
                kv("Background audio", String(format: "%.1f h", mk.backgroundAudioHours))
                kv("Background total", String(format: "%.1f h", mk.backgroundHours))
                kv("Foreground", String(format: "%.1f h", mk.foregroundHours))
                kv("CPU time", String(format: "%.0f s", mk.cpuSeconds))
                kv("Period", "\(Self.day(mk.periodBegin)) → \(Self.day(mk.periodEnd))")
            } else {
                Text("No MetricKit report yet. iOS delivers one roughly once every 24h (device only, not simulator). Check back tomorrow.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        } header: {
            Text("System measurement (MetricKit)")
        } footer: {
            Text("Authoritative. \"Background audio\" is the exact time the silent keep-alive ran in the reporting period.")
        }
    }

    private var appObservedSection: some View {
        Section {
            kv("Keep-alive ran (24h)", KeepAliveBatteryMonitor.formatDuration(report.keepAliveHours24h * 3600))
            kv("Sessions (24h)", "\(report.sessions24h)")
        } header: {
            Text("App-observed keep-alive")
        } footer: {
            Text("A lower bound — sessions ended by app termination are not fully counted. Trust MetricKit above for the real total.")
        }
    }

    @ViewBuilder
    private var estimateSection: some View {
        Section {
            if let drain = report.estDrainPerHourPct {
                kv("Drain while active", String(format: "≈ %.1f%% / hour", drain))
                kv("Based on", "\(report.estSampleCount) unplugged session(s)")
            } else {
                Text("Not enough unplugged keep-alive sessions yet to estimate. Need a few sessions of ≥15 min on battery.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        } header: {
            Text("Estimated cost")
        } footer: {
            Text("Coarse: iOS reports battery in ~5% steps and other apps drain too, so treat this as a trend, not a precise figure.")
        }
    }

    @ViewBuilder
    private var recentSection: some View {
        if !report.recent.isEmpty {
            Section("Recent sessions") {
                ForEach(report.recent) { row in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(row.when).font(.system(size: 13, weight: .semibold))
                            Spacer()
                            Text(row.duration).font(.system(size: 13, design: .monospaced))
                        }
                        HStack(spacing: 6) {
                            Text(row.batteryDelta)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            if row.charging {
                                Text("charging")
                                    .font(.system(size: 11))
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var noteSection: some View {
        Section {
            Button(role: .destructive) {
                KeepAliveBatteryMonitor.shared.reset()
                report = KeepAliveBatteryMonitor.shared.makeReport()
            } label: {
                Label("Reset monitor data", systemImage: "trash")
            }
        }
    }

    private func kv(_ key: String, _ value: String) -> some View {
        HStack {
            Text(key)
            Spacer()
            Text(value).foregroundColor(.secondary)
        }
    }

    private static func day(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d HH:mm"
        return f.string(from: date)
    }
}
