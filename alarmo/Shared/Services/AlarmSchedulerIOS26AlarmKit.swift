import Foundation
import os

#if canImport(AlarmKit)
import AlarmKit
import ActivityKit
import SwiftUI
import AppIntents
#endif

/// AlarmKit-backed scheduler used on iOS 26+ when available.
///
/// Uses Apple-supported system alarm APIs for lock-screen/alarm-surface behavior.
/// This avoids private APIs and avoids abusing background audio for wake alarms.
final class AlarmSchedulerIOS26AlarmKit: AlarmScheduler {
    private let logger = Logger(subsystem: "ht.alarmo", category: "AlarmScheduler.AlarmKit")
    private let stateStore = AlarmKitStateStore()

    var implementationName: String { "AlarmSchedulerIOS26AlarmKit" }

    var isSupportedOnCurrentDevice: Bool {
#if canImport(AlarmKit)
        if #available(iOS 26.0, *) { return true }
#endif
        return false
    }

    func requestAuthorizationIfNeeded() async throws -> Bool {
#if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            let state = try await resolveAuthorizationState()
            return state == .authorized
        }
#endif
        throw AlarmSchedulingError.unsupportedAlarmKit
    }

    func scheduleAlarm(
        id: UUID,
        title: String,
        date: Date,
        sound: String,
        snoozeEnabled: Bool
    ) async throws {
#if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            let manager = AlarmManager.shared
            let state = try await resolveAuthorizationState()
            guard state == .authorized else {
                logger.error("AlarmKit authorization denied while scheduling \(id.uuidString, privacy: .public)")
                throw AlarmSchedulingError.alarmKitPermissionDenied
            }

            let snoozeInterval: TimeInterval? = snoozeEnabled ? 300 : nil
            let effectiveSoundName = try await scheduleWithFallbackSound(
                manager: manager,
                id: id,
                title: title,
                schedule: .fixed(date),
                snoozeEnabled: snoozeEnabled,
                snoozeInterval: snoozeInterval,
                preferredSoundName: sound
            )
            await stateStore.upsert(
                .init(
                    id: id,
                    title: title,
                    date: date,
                    sound: effectiveSoundName,
                    snoozeEnabled: snoozeEnabled,
                    repeats: false
                )
            )
            logger.log("Scheduled AlarmKit alarm \(id.uuidString, privacy: .public)")
            return
        }
#endif
        throw AlarmSchedulingError.unsupportedAlarmKit
    }

    func cancelAlarm(id: UUID) async {
#if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            do {
                // Prefer cancellation for scheduled alarms; fallback to stop for currently alerting alarms.
                try AlarmManager.shared.cancel(id: id)
                await stateStore.remove(id: id)
            } catch {
                do {
                    try AlarmManager.shared.stop(id: id)
                    await stateStore.remove(id: id)
                } catch {
                    logger.error("AlarmKit cancel failed for \(id.uuidString, privacy: .public): \(error.localizedDescription, privacy: .public)")
                }
            }
            return
        }
#endif
    }

    func rescheduleAlarm(id: UUID, newDate: Date) async throws {
        let existing = await stateStore.value(for: id)
        await cancelAlarm(id: id)
        try await scheduleAlarm(
            id: id,
            title: existing?.title ?? "Alarm",
            date: newDate,
            sound: existing?.sound ?? "default",
            snoozeEnabled: existing?.snoozeEnabled ?? true
        )
    }

    func listScheduledAlarms() async -> [ScheduledAlarmDescriptor] {
        // AlarmKit does not currently expose a direct "pending list" API equivalent to UNNotificationCenter.
        // We keep an app-owned state snapshot for diagnostics and test tools.
        await stateStore.all().map {
            ScheduledAlarmDescriptor(
                id: $0.id,
                title: $0.title,
                fireDate: $0.date,
                enabled: true,
                soundName: $0.sound,
                repeats: $0.repeats,
                snoozeEnabled: $0.snoozeEnabled,
                backendIdentifier: $0.id.uuidString
            )
        }
    }

    func snoozeAlarm(id: UUID, interval: TimeInterval) async throws {
        let existing = await stateStore.value(for: id)
        // For one-shot AlarmKit implementation, snooze is modeled as a fresh one-shot alarm.
        try await scheduleAlarm(
            id: id,
            title: existing?.title ?? "Snoozed Alarm",
            date: Date().addingTimeInterval(max(interval, 1)),
            sound: existing?.sound ?? "default",
            snoozeEnabled: true
        )
    }

    /// Schedules full app alarms, including repeating alarms, on AlarmKit.
    ///
    /// This is used by `AlarmManagerFacade.schedule(alarm:)` so repeating alarms no longer
    /// depend on legacy local-notification follow-up chains while locked.
    func scheduleAppAlarm(_ alarm: Alarm) async throws {
#if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            let manager = AlarmManager.shared
            let state = try await resolveAuthorizationState()
            guard state == .authorized else {
                logger.error("AlarmKit authorization denied while scheduling app alarm \(alarm.id.uuidString, privacy: .public)")
                throw AlarmSchedulingError.alarmKitPermissionDenied
            }

            let trimmedTitle = alarm.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let title = trimmedTitle.isEmpty ? "Alarm" : trimmedTitle
            let schedule = makeSchedule(for: alarm)
            let snoozeInterval = resolvedSnoozeInterval(for: alarm)
            let snoozeEnabled = snoozeInterval != nil
            let effectiveSoundName = try await scheduleWithFallbackSound(
                manager: manager,
                id: alarm.id,
                title: title,
                schedule: schedule,
                snoozeEnabled: snoozeEnabled,
                snoozeInterval: snoozeInterval,
                preferredSoundName: alarm.soundName
            )

            let nextFireDate = AlarmStore.nextFireDate(for: alarm, from: Date()) ?? Date()
            await stateStore.upsert(
                .init(
                    id: alarm.id,
                    title: title,
                    date: nextFireDate,
                    sound: effectiveSoundName,
                    snoozeEnabled: snoozeEnabled,
                    repeats: (alarm.repeatMask > 0 || alarm.isDaily)
                )
            )
            logger.log("Scheduled AlarmKit app alarm \(alarm.id.uuidString, privacy: .public) repeats=\(alarm.repeatMask > 0 || alarm.isDaily, privacy: .public)")
            return
        }
#endif
        throw AlarmSchedulingError.unsupportedAlarmKit
    }

    func markAlarmFired(id: UUID) async {
        let existing = await stateStore.value(for: id)
        if existing?.repeats == false {
            await stateStore.remove(id: id)
        }
        logger.log("Alarm fired recorded for \(id.uuidString, privacy: .public)")
    }

#if canImport(AlarmKit)
    @available(iOS 26.0, *)
    private func resolveAuthorizationState() async throws -> AlarmManager.AuthorizationState {
        let manager = AlarmManager.shared
        switch manager.authorizationState {
        case .authorized:
            return .authorized
        case .denied:
            return .denied
        case .notDetermined:
            return try await manager.requestAuthorization()
        @unknown default:
            return .denied
        }
    }
#endif
}

private actor AlarmKitStateStore {
    struct Value: Equatable {
        let id: UUID
        let title: String
        let date: Date
        let sound: String
        let snoozeEnabled: Bool
        let repeats: Bool
    }

    private var values: [UUID: Value] = [:]

    func upsert(_ value: Value) {
        values[value.id] = value
    }

    func remove(id: UUID) {
        values[id] = nil
    }

    func value(for id: UUID) -> Value? {
        values[id]
    }

    func all() -> [Value] {
        values.values.sorted { $0.date < $1.date }
    }
}

#if canImport(AlarmKit)
@available(iOS 26.0, *)
private struct AlarmoAlarmMetadata: AlarmMetadata {
    let title: String

    init(title: String = "Alarm") {
        self.title = title
    }
}

@available(iOS 26.0, *)
private extension AlarmSchedulerIOS26AlarmKit {
    func scheduleWithFallbackSound(
        manager: AlarmManager,
        id: UUID,
        title: String,
        schedule: AlarmKit.Alarm.Schedule,
        snoozeEnabled: Bool,
        snoozeInterval: TimeInterval?,
        preferredSoundName: String?
    ) async throws -> String {
        // Replace prior schedule for the same id before creating a new one.
        // This avoids duplicate-schedule rejections on edits/reschedules.
        try? manager.cancel(id: id)

        let requestedSound: String? = {
            guard let value = preferredSoundName?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !value.isEmpty,
                  value.lowercased() != "default" else {
                return nil
            }
            return value
        }()

            let preferredConfiguration = makeConfiguration(
                alarmID: id,
                title: title,
                schedule: schedule,
                snoozeEnabled: snoozeEnabled,
                snoozeInterval: snoozeInterval,
                soundName: requestedSound
            )

        do {
            _ = try await manager.schedule(id: id, configuration: preferredConfiguration)
            return requestedSound ?? "default"
        } catch {
            guard requestedSound != nil else { throw error }
            logger.error("AlarmKit schedule failed with custom sound for \(id.uuidString, privacy: .public); retrying with default sound. Error: \(error.localizedDescription, privacy: .public)")

            let fallbackConfiguration = makeConfiguration(
                alarmID: id,
                title: title,
                schedule: schedule,
                snoozeEnabled: snoozeEnabled,
                snoozeInterval: snoozeInterval,
                soundName: nil
            )
            _ = try await manager.schedule(id: id, configuration: fallbackConfiguration)
            return "default"
        }
    }

    func makeConfiguration(
        alarmID: UUID,
        title: String,
        schedule: AlarmKit.Alarm.Schedule,
        snoozeEnabled: Bool,
        snoozeInterval: TimeInterval?,
        soundName: String? = nil
    ) -> AlarmManager.AlarmConfiguration<AlarmoAlarmMetadata> {
        let resolvedSnoozeInterval = max(1, snoozeInterval ?? 300)
        let showsSnoozeButton = snoozeEnabled

        let secondaryButton: AlarmButton? = showsSnoozeButton
            ? AlarmButton(
                text: "Snooze",
                textColor: .white,
                systemImageName: "zzz"
            )
            : nil
        let secondaryBehavior: AlarmPresentation.Alert.SecondaryButtonBehavior? = showsSnoozeButton ? .countdown : nil

        let alertPresentation: AlarmPresentation.Alert
        if #available(iOS 26.1, *) {
            alertPresentation = AlarmPresentation.Alert(
                title: LocalizedStringResource(stringLiteral: title),
                secondaryButton: secondaryButton,
                secondaryButtonBehavior: secondaryBehavior
            )
        } else {
            alertPresentation = AlarmPresentation.Alert(
                title: LocalizedStringResource(stringLiteral: title),
                stopButton: AlarmButton(
                    text: "Stop",
                    textColor: .white,
                    systemImageName: "stop.fill"
                ),
                secondaryButton: secondaryButton,
                secondaryButtonBehavior: secondaryBehavior
            )
        }

        let countdownPresentation: AlarmPresentation.Countdown? = showsSnoozeButton
            ? AlarmPresentation.Countdown(
                title: LocalizedStringResource(stringLiteral: "Snoozing"),
                pauseButton: AlarmButton(
                    text: "Pause",
                    textColor: .white,
                    systemImageName: "pause.fill"
                )
            )
            : nil
        let pausedPresentation: AlarmPresentation.Paused? = showsSnoozeButton
            ? AlarmPresentation.Paused(
                title: LocalizedStringResource(stringLiteral: "Snooze Paused"),
                resumeButton: AlarmButton(
                    text: "Resume",
                    textColor: .white,
                    systemImageName: "play.fill"
                )
            )
            : nil

        let presentation = AlarmPresentation(
            alert: alertPresentation,
            countdown: countdownPresentation,
            paused: pausedPresentation
        )

        let attributes = AlarmAttributes(
            presentation: presentation,
            metadata: AlarmoAlarmMetadata(title: title),
            tintColor: .blue
        )

        // Resolve the alarm sound: use the user's chosen sound.
        // For default/fallback, prefer the empty named sound token instead of `.default`.
        // This aligns with observed AlarmKit behavior where `.default` can alert silently.
        let alertSound: AlertConfiguration.AlertSound
        if let name = soundName, !name.isEmpty, name != "default" {
            if let stagedName = stageNotificationSound(named: name) {
                // AlarmKit alert sounds use named assets.
                // `.ringtone` is not part of the current SDK surface.
                alertSound = .named(stagedName)
            } else {
                alertSound = .named("")
            }
        } else {
            alertSound = .named("")
        }

        let countdownDuration: AlarmKit.Alarm.CountdownDuration? = showsSnoozeButton
            ? AlarmKit.Alarm.CountdownDuration(preAlert: nil, postAlert: resolvedSnoozeInterval)
            : nil

        return AlarmManager.AlarmConfiguration(
            countdownDuration: countdownDuration,
            schedule: schedule,
            attributes: attributes,
            stopIntent: StopAlarmIntent(alarmID: alarmID.uuidString),
            secondaryIntent: nil,
            sound: alertSound
        )
    }

    func resolvedSnoozeInterval(for alarm: Alarm) -> TimeInterval? {
        let minutes = max(0, alarm.snoozeMinutes)
        let seconds = max(0, alarm.snoozeSeconds)
        let totalSeconds: Int
        if seconds > 0 {
            totalSeconds = minutes * 60 + seconds
        } else {
            totalSeconds = minutes * 60
        }
        guard totalSeconds > 0 else { return nil }
        return TimeInterval(totalSeconds)
    }

    func makeSchedule(for alarm: Alarm) -> AlarmKit.Alarm.Schedule {
        let hour = min(23, max(0, alarm.hour))
        let minute = min(59, max(0, alarm.minute))
        let isRepeating = (alarm.repeatMask > 0 || alarm.isDaily)

        if isRepeating {
            let weekdays = (alarm.isDaily ? Array(1...7) : RepeatMask.weekdays(from: alarm.repeatMask))
                .compactMap(localeWeekday(fromCalendarWeekday:))
            return .relative(
                .init(
                    time: .init(hour: hour, minute: minute),
                    repeats: .weekly(weekdays.isEmpty ? [.monday] : weekdays)
                )
            )
        }

        if let fireDate = AlarmStore.nextFireDate(for: alarm, from: Date()) {
            return .fixed(fireDate)
        }
        return .relative(
            .init(
                time: .init(hour: hour, minute: minute),
                repeats: .never
            )
        )
    }

    func localeWeekday(fromCalendarWeekday value: Int) -> Locale.Weekday? {
        switch value {
        case 1: return .sunday
        case 2: return .monday
        case 3: return .tuesday
        case 4: return .wednesday
        case 5: return .thursday
        case 6: return .friday
        case 7: return .saturday
        default: return nil
        }
    }

    private func stageNotificationSound(named rawName: String) -> String? {
        guard let sourceURL = resolveSoundURL(for: rawName) else { return nil }
        let ext = sourceURL.pathExtension.lowercased()
        let supportedExtensions: Set<String> = ["wav", "aiff", "caf", "m4a", "mp3"]
        guard supportedExtensions.contains(ext) else { return nil }

        let fileManager = FileManager.default
        guard let library = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first else { return nil }
        let soundsDir = library.appendingPathComponent("Sounds", isDirectory: true)

        do {
            try fileManager.createDirectory(at: soundsDir, withIntermediateDirectories: true)
        } catch {
            return nil
        }

        let safeBase = normalizedSoundKey(rawName)
        let finalBase = safeBase.isEmpty ? "alarmo_alarm" : safeBase
        let fileName = "\(finalBase).\(ext)"
        let destinationURL = soundsDir.appendingPathComponent(fileName, isDirectory: false)

        if !fileManager.fileExists(atPath: destinationURL.path) {
            do {
                try fileManager.copyItem(at: sourceURL, to: destinationURL)
            } catch {
                return nil
            }
        }
        return fileName
    }

    private func resolveSoundURL(for rawName: String) -> URL? {
        let normalized = normalizedSoundKey(rawName)
        let fileManager = FileManager.default

        // 1. Check CustomSounds in Documents
        if let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            let customDir = docs.appendingPathComponent("CustomSounds")
            if let enumerator = fileManager.enumerator(at: customDir, includingPropertiesForKeys: nil) {
                for case let fileURL as URL in enumerator {
                    let key = normalizedSoundKey(fileURL.deletingPathExtension().lastPathComponent)
                    if key == normalized { return fileURL }
                }
            }
        }

        // 2. Check bundled sounds
        let soundsRoot = Bundle.main.bundleURL.appendingPathComponent("sounds", isDirectory: true)
        guard let enumerator = fileManager.enumerator(at: soundsRoot, includingPropertiesForKeys: nil) else { return nil }

        var fallbackMatch: URL?
        let supportedExtensions: Set<String> = ["wav", "aiff", "caf", "m4a", "mp3"]
        for case let fileURL as URL in enumerator {
            let ext = fileURL.pathExtension.lowercased()
            guard !ext.isEmpty else { continue }

            let key = normalizedSoundKey(fileURL.deletingPathExtension().lastPathComponent)
            if key == normalized {
                if supportedExtensions.contains(ext) {
                    return fileURL
                }
                fallbackMatch = fallbackMatch ?? fileURL
            }
        }
        return fallbackMatch
    }

    private func normalizedSoundKey(_ raw: String) -> String {
        let noExt = (raw as NSString).deletingPathExtension
        return noExt
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
    }
}

@available(iOS 26.0, *)
struct StopAlarmIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Stop Alarm"
    static var openAppWhenRun: Bool = false
    
    @Parameter(title: "Alarm ID")
    var alarmID: String
    
    init() {}
    
    init(alarmID: String) {
        self.alarmID = alarmID
    }
    
    func perform() async throws -> some IntentResult {
        if let uuid = UUID(uuidString: alarmID) {
            try? AlarmManager.shared.stop(id: uuid)
            // Mirror in-app stop behavior for one-shot/quick alarms so app state
            // stays aligned when user stops directly from the system AlarmKit UI.
            let store = AlarmStore.shared
            if let alarm = store.alarm(by: uuid) {
                if alarm.type == .quick {
                    store.remove(id: uuid)
                } else if alarm.repeatMask == 0 && !alarm.isDaily {
                    store.toggleEnabled(id: uuid, enabled: false)
                }
            }
        }
        return .result()
    }
}
#endif
