import Foundation
#if canImport(MetricKit)
import MetricKit
#endif

/// Subscribes to MetricKit and records WHY the app exited — the most reliable way to
/// diagnose overnight termination (memory pressure, CPU limit, background-task
/// assertion timeout, watchdog). Reports are delivered by the system periodically
/// (typically once per day), so check the Logs screen after a night of testing.
final class AppExitDiagnostics: NSObject {
    static let shared = AppExitDiagnostics()

    func start() {
#if canImport(MetricKit)
        MXMetricManager.shared.add(self)
        DiagnosticsLog.shared.log("MetricKit subscriber registered", category: "MetricKit")
#endif
    }
}

#if canImport(MetricKit)
extension AppExitDiagnostics: MXMetricManagerSubscriber {
    func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads {
            recordBatteryRelevantMetrics(payload)
            guard let exit = payload.applicationExitMetrics else { continue }
            let bg = exit.backgroundExitData
            DiagnosticsLog.shared.log(
                "AppExit[background] normal=\(bg.cumulativeNormalAppExitCount) "
                + "memoryPressure=\(bg.cumulativeMemoryPressureExitCount) "
                + "memoryResourceLimit=\(bg.cumulativeMemoryResourceLimitExitCount) "
                + "cpuResourceLimit=\(bg.cumulativeCPUResourceLimitExitCount) "
                + "bgTaskAssertionTimeout=\(bg.cumulativeBackgroundTaskAssertionTimeoutExitCount) "
                + "watchdog=\(bg.cumulativeAppWatchdogExitCount) "
                + "badAccess=\(bg.cumulativeBadAccessExitCount) "
                + "abnormal=\(bg.cumulativeAbnormalExitCount) "
                + "illegalInstruction=\(bg.cumulativeIllegalInstructionExitCount)",
                category: "MetricKit"
            )
            let fg = exit.foregroundExitData
            DiagnosticsLog.shared.log(
                "AppExit[foreground] normal=\(fg.cumulativeNormalAppExitCount) "
                + "memoryResourceLimit=\(fg.cumulativeMemoryResourceLimitExitCount) "
                + "watchdog=\(fg.cumulativeAppWatchdogExitCount) "
                + "badAccess=\(fg.cumulativeBadAccessExitCount)",
                category: "MetricKit"
            )
        }
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        // Crash/hang diagnostics are available here if needed; exit metrics above
        // are the primary signal for overnight termination.
    }

    /// Logs and persists the time/CPU metrics that quantify the keep-alive's battery
    /// cost. `cumulativeBackgroundAudioTime` is the exact time the silent keep-alive
    /// audio ran in the reporting period (~24h) — the authoritative answer to "how
    /// much is the background sound used".
    private func recordBatteryRelevantMetrics(_ payload: MXMetricPayload) {
        let bgAudioHours = payload.applicationTimeMetrics?.cumulativeBackgroundAudioTime
            .converted(to: .hours).value ?? 0
        let bgHours = payload.applicationTimeMetrics?.cumulativeBackgroundTime
            .converted(to: .hours).value ?? 0
        let fgHours = payload.applicationTimeMetrics?.cumulativeForegroundTime
            .converted(to: .hours).value ?? 0
        let cpuSeconds = payload.cpuMetrics?.cumulativeCPUTime
            .converted(to: .seconds).value ?? 0

        DiagnosticsLog.shared.log(
            "Battery metrics: backgroundAudio=\(String(format: "%.2f", bgAudioHours))h "
            + "background=\(String(format: "%.2f", bgHours))h "
            + "foreground=\(String(format: "%.2f", fgHours))h "
            + "cpu=\(String(format: "%.0f", cpuSeconds))s "
            + "period=\(payload.timeStampBegin)…\(payload.timeStampEnd)",
            category: "MetricKit"
        )

        let snapshot = KeepAliveBatteryMonitor.MetricKitSnapshot(
            capturedAt: Date(),
            periodBegin: payload.timeStampBegin,
            periodEnd: payload.timeStampEnd,
            backgroundAudioHours: bgAudioHours,
            backgroundHours: bgHours,
            foregroundHours: fgHours,
            cpuSeconds: cpuSeconds
        )
        Task { @MainActor in
            KeepAliveBatteryMonitor.shared.recordMetricKit(snapshot)
        }
    }
}
#endif
