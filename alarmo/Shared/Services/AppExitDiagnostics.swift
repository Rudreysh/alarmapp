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
}
#endif
