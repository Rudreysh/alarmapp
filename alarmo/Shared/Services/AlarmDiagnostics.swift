import AVFoundation
import UIKit

struct AlarmDiagnostic {
    let level: Level
    let message: String

    enum Level {
        case warning
        case critical
    }
}

final class AlarmDiagnostics {
    @MainActor
    static func runScheduleDiagnostics(for alarm: Alarm) -> [AlarmDiagnostic] {
        var results: [AlarmDiagnostic] = []

        if AlarmContinuousAudioEngine.shared.resolvedSoundURLForDiagnostics(soundName: alarm.soundName) == nil {
            results.append(
                AlarmDiagnostic(
                    level: .warning,
                    message: "Selected sound '\(alarm.soundName)' not found. Fallback sound will be used."
                )
            )
        }

        let volume = AVAudioSession.sharedInstance().outputVolume
        if volume < 0.3 {
            results.append(
                AlarmDiagnostic(
                    level: .warning,
                    message: "Phone volume is at \(Int(volume * 100))%. Increase volume for reliable alarm."
                )
            )
        }

        if let available = availableStorage(), available < 100_000_000 {
            results.append(
                AlarmDiagnostic(
                    level: .warning,
                    message: "Low storage may affect alarm reliability."
                )
            )
        }

        if UIApplication.shared.backgroundRefreshStatus != .available {
            results.append(
                AlarmDiagnostic(
                    level: .critical,
                    message: "Background App Refresh is disabled. Enable in Settings for reliable alarms."
                )
            )
        }

        return results
    }

    private static func availableStorage() -> Int? {
        guard let values = try? URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
            .resourceValues(forKeys: [.volumeAvailableCapacityKey]),
              let available = values.volumeAvailableCapacity else {
            return nil
        }
        return available
    }
}

extension Notification.Name {
    static let alarmDiagnosticsGenerated = Notification.Name("alarm.diagnostics.generated")
}
