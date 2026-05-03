import Foundation
import os

#if canImport(AlarmKit)
import AlarmKit
import ActivityKit
import SwiftUI
import AppIntents
import AVFoundation
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
                NotificationManager.shared.cancelAlarmKitUnlockPrompt(alarmId: id.uuidString)
            } catch {
                do {
                    try AlarmManager.shared.stop(id: id)
                    await stateStore.remove(id: id)
                    NotificationManager.shared.cancelAlarmKitUnlockPrompt(alarmId: id.uuidString)
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
fileprivate extension AlarmSchedulerIOS26AlarmKit {
    var fallbackAlarmSoundKey: String { "cockpitalert" }
    var maxAlarmKitSoundDuration: TimeInterval { 29.5 }

    func scheduleWithFallbackSound(
        manager: AlarmManager,
        id: UUID,
        originalAlarmID: UUID? = nil,
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
            originalAlarmID: originalAlarmID,
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
            logger.error("AlarmKit schedule primary attempt failed for \(id.uuidString, privacy: .public). Error: \(error.localizedDescription, privacy: .public)")

            // Defensive cleanup: some AlarmKit failures can leave an id in a
            // transient state. Cancel before fallback schedule to avoid duplicate-id rejection.
            try? manager.cancel(id: id)

            if requestedSound != nil {
                let fallbackConfiguration = makeConfiguration(
                    alarmID: id,
                    originalAlarmID: originalAlarmID,
                    title: title,
                    schedule: schedule,
                    snoozeEnabled: snoozeEnabled,
                    snoozeInterval: snoozeInterval,
                    soundName: nil
                )
                do {
                    _ = try await manager.schedule(id: id, configuration: fallbackConfiguration)
                    return "default"
                } catch {
                    logger.error("AlarmKit schedule bundled-fallback attempt failed for \(id.uuidString, privacy: .public). Error: \(error.localizedDescription, privacy: .public)")
                    try? manager.cancel(id: id)
                }
            }

            // Final fallback: force system default alarm sound.
            let systemDefaultConfiguration = makeConfiguration(
                alarmID: id,
                originalAlarmID: originalAlarmID,
                title: title,
                schedule: schedule,
                snoozeEnabled: snoozeEnabled,
                snoozeInterval: snoozeInterval,
                soundName: nil,
                useSystemDefaultSound: true
            )
            _ = try await manager.schedule(id: id, configuration: systemDefaultConfiguration)
            return "default"
        }
    }

    func makeConfiguration(
        alarmID: UUID,
        originalAlarmID: UUID? = nil,
        title: String,
        schedule: AlarmKit.Alarm.Schedule,
        snoozeEnabled: Bool,
        snoozeInterval: TimeInterval?,
        soundName: String? = nil,
        useSystemDefaultSound: Bool = false
    ) -> AlarmManager.AlarmConfiguration<AlarmoAlarmMetadata> {
        let alertPresentation: AlarmPresentation.Alert
        if #available(iOS 26.1, *) {
            alertPresentation = AlarmPresentation.Alert(
                title: LocalizedStringResource(stringLiteral: title)
            )
        } else {
            alertPresentation = AlarmPresentation.Alert(
                title: LocalizedStringResource(stringLiteral: title),
                stopButton: AlarmButton(
                    text: "Stop",
                    textColor: .white,
                    systemImageName: "stop.fill"
                )
            )
        }

        let countdownPresentation: AlarmPresentation.Countdown? = nil
        let pausedPresentation: AlarmPresentation.Paused? = nil

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
        // If custom resolution fails, use a known short bundled fallback so AlarmKit
        // scheduling still succeeds and keeps system alarm behavior.
        let alertSound: AlertConfiguration.AlertSound
        if useSystemDefaultSound {
            alertSound = .default
        } else {
            if let name = soundName, !name.isEmpty, name != "default" {
                if let stagedName = stageNotificationSound(named: name) {
                    // AlarmKit alert sounds use named assets.
                    // `.ringtone` is not part of the current SDK surface.
                    alertSound = .named(stagedName)
                } else if let stagedFallback = stageNotificationSound(named: fallbackAlarmSoundKey) {
                    alertSound = .named(stagedFallback)
                } else {
                    alertSound = .named("")
                }
            } else {
                if let stagedFallback = stageNotificationSound(named: fallbackAlarmSoundKey) {
                    alertSound = .named(stagedFallback)
                } else {
                    alertSound = .named("")
                }
            }
        }

        return AlarmManager.AlarmConfiguration(
            countdownDuration: nil,
            schedule: schedule,
            attributes: attributes,
            stopIntent: StopAlarmIntent(alarmID: alarmID.uuidString, originalAlarmID: originalAlarmID?.uuidString),
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
        let duration = audioDuration(of: sourceURL)

        if duration > maxAlarmKitSoundDuration {
            let trimmedName = "\(finalBase)_alarmkit.m4a"
            let trimmedURL = soundsDir.appendingPathComponent(trimmedName, isDirectory: false)

            if !fileManager.fileExists(atPath: trimmedURL.path) {
                do {
                    try exportTrimmedSound(
                        sourceURL: sourceURL,
                        destinationURL: trimmedURL,
                        maxDuration: maxAlarmKitSoundDuration
                    )
                } catch {
                    return nil
                }
            }
            return trimmedName
        } else {
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

        // 2. Check downloaded Assets in Application Support (cloud sounds).
        if let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let assetsDir = appSupport.appendingPathComponent("Assets", isDirectory: true)
            if let enumerator = fileManager.enumerator(at: assetsDir, includingPropertiesForKeys: nil) {
                for case let fileURL as URL in enumerator {
                    let ext = fileURL.pathExtension.lowercased()
                    guard !ext.isEmpty else { continue }
                    let key = normalizedSoundKey(fileURL.deletingPathExtension().lastPathComponent)
                    if key == normalized { return fileURL }
                }
            }
        }

        // 3. Check bundled sounds
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

    private func audioDuration(of url: URL) -> TimeInterval {
        let asset = AVURLAsset(url: url)
        let seconds = CMTimeGetSeconds(asset.duration)
        guard seconds.isFinite, seconds > 0 else { return 0 }
        return seconds
    }

    private func exportTrimmedSound(
        sourceURL: URL,
        destinationURL: URL,
        maxDuration: TimeInterval
    ) throws {
        let asset = AVURLAsset(url: sourceURL)
        guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw AlarmSchedulingError.schedulingRejected("Unable to create audio exporter")
        }

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try? FileManager.default.removeItem(at: destinationURL)
        }

        exporter.outputURL = destinationURL
        exporter.outputFileType = .m4a
        exporter.timeRange = CMTimeRange(
            start: .zero,
            duration: CMTime(seconds: maxDuration, preferredTimescale: 600)
        )

        let semaphore = DispatchSemaphore(value: 0)
        exporter.exportAsynchronously {
            semaphore.signal()
        }
        semaphore.wait()

        if exporter.status != .completed {
            let reason = exporter.error?.localizedDescription ?? "Unknown export failure"
            throw AlarmSchedulingError.schedulingRejected("Trimmed sound export failed: \(reason)")
        }
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
    // Keep this false so lock-screen Stop intent can run repeatedly without
    // forcing app activation while the device is still locked.
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Alarm ID")
    var alarmID: String

    @Parameter(title: "Original Alarm ID")
    var originalAlarmID: String?

    @Parameter(title: "Suppress Unlock Prompt")
    var suppressUnlockPrompt: Bool

    init() {
        self.suppressUnlockPrompt = false
    }

    init(alarmID: String, originalAlarmID: String? = nil, suppressUnlockPrompt: Bool = false) {
        self.alarmID = alarmID
        self.originalAlarmID = originalAlarmID
        self.suppressUnlockPrompt = suppressUnlockPrompt
    }

    func perform() async throws -> some IntentResult {
        guard let uuid = UUID(uuidString: alarmID) else {
            return .result()
        }
        
        let lookupUUIDString = originalAlarmID ?? alarmID
        guard let lookupUUID = UUID(uuidString: lookupUUIDString) else {
            return .result()
        }

        // --- THE "ZOMBIE ALARM" ALARMKIT HACK ---
        // Since only AlarmKit can physically bypass the iOS hardware silent switch
        // while the phone is locked, we cannot rely on background AVAudioPlayers.
        // The moment the user swipes "Stop" on the lock screen, AlarmKit forcibly
        // stops the system sound. 
        // To prevent this and force the user to unlock, we detect if the phone
        // is locked, and if so, we immediately spawn a brand new AlarmKit alarm
        // a short moment in the future.
        // This causes the Lock Screen UI to immediately flash back onto the screen
        // and resumes the system sound with virtually zero gap.
        let shouldUseLockedHandling = await MainActor.run {
            let appState = UIApplication.shared.applicationState
            // Treat any non-foreground state as lock-style handling so the
            // AlarmKit surface + sound can be force-looped until explicit unlock.
            return appState != .active || !UIApplication.shared.isProtectedDataAvailable
        }
        let resolvedAlarmName = await MainActor.run {
            AlarmStore.shared.alarm(by: lookupUUID)?.name
        }
        let trimmedAlarmName = resolvedAlarmName?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if shouldUseLockedHandling {
            let originalAlarm = await MainActor.run { AlarmStore.shared.alarm(by: lookupUUID) }
            if let originalAlarm = originalAlarm {
                let helper = AlarmSchedulerIOS26AlarmKit()
                let title = originalAlarm.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Alarm" : originalAlarm.name.trimmingCharacters(in: .whitespacesAndNewlines)
                // Explicitly cancel the surface the user just swiped away so old
                // entries do not accumulate in Notification Center.
                try? AlarmManager.shared.cancel(id: uuid)
                
                // Must use a new UUID so AlarmKit doesn't drop the request.
                // Keep a visible pause before reappearing to avoid lock-screen UI stacking.
                let baseRespawnDelay: TimeInterval = 4.0
                let maxRespawnAttempts = 4
                let snoozeInterval = helper.resolvedSnoozeInterval(for: originalAlarm)
                let snoozeEnabled = snoozeInterval != nil

                var didSchedule = false
                var lastError: Error?
                var newUUID = UUID()

                for attempt in 1...maxRespawnAttempts {
                    do {
                        let attemptDelay = baseRespawnDelay + (Double(attempt - 1) * 0.2)
                        newUUID = UUID()
                        _ = try await helper.scheduleWithFallbackSound(
                            manager: AlarmManager.shared,
                            id: newUUID,
                            originalAlarmID: lookupUUID,
                            title: title,
                            schedule: .fixed(Date().addingTimeInterval(attemptDelay)),
                            snoozeEnabled: snoozeEnabled,
                            snoozeInterval: snoozeInterval,
                            preferredSoundName: originalAlarm.soundName
                        )
                        didSchedule = true
                        break
                    } catch {
                        lastError = error
                        print("[StopAlarmIntent] Zombie reschedule attempt \(attempt)/\(maxRespawnAttempts) failed: \(error)")
                        if attempt < maxRespawnAttempts {
                            try? await Task.sleep(nanoseconds: 200_000_000)
                        }
                    }
                }

                if didSchedule {
                    // Route custom UI using the ORIGINAL alarm id (for wallpaper/quotes/settings),
                    // while still tracking the current AlarmKit surface id to dismiss it on unlock.
                    AlarmCustomUIHandoffStore.request(alarmID: lookupUUID, surfaceAlarmID: newUUID)
                    if !suppressUnlockPrompt {
                        NotificationManager.shared.scheduleAlarmKitUnlockPrompt(
                            sourceAlarmId: lookupUUID.uuidString,
                            surfaceAlarmId: newUUID.uuidString,
                            alarmName: title
                        )
                        NotificationManager.shared.startAlarmKitUnlockPromptLoop(
                            sourceAlarmId: lookupUUID.uuidString,
                            surfaceAlarmId: newUUID.uuidString,
                            alarmName: title
                        )
                        NotificationCenter.default.post(
                            name: .alarmKitCustomUIHandoffRequested,
                            object: nil,
                            userInfo: [
                                "alarmId": lookupUUID.uuidString,
                                "surfaceAlarmId": newUUID.uuidString
                            ]
                        )
                    }
                    return .result()
                }

                print("[StopAlarmIntent] Zombie reschedule failed after \(maxRespawnAttempts) attempts: \(lastError?.localizedDescription ?? "unknown error")")
                if !suppressUnlockPrompt {
                    NotificationManager.shared.scheduleAlarmKitUnlockPrompt(
                        sourceAlarmId: lookupUUID.uuidString,
                        surfaceAlarmId: uuid.uuidString,
                        alarmName: title
                    )
                    NotificationManager.shared.startAlarmKitUnlockPromptLoop(
                        sourceAlarmId: lookupUUID.uuidString,
                        surfaceAlarmId: uuid.uuidString,
                        alarmName: title
                    )
                }
                return .result()
            }
        }

        // Fallback or unlocked-device path.
        AlarmCustomUIHandoffStore.request(alarmID: lookupUUID, surfaceAlarmID: uuid)
        if !suppressUnlockPrompt {
            NotificationManager.shared.scheduleAlarmKitUnlockPrompt(
                sourceAlarmId: lookupUUID.uuidString,
                surfaceAlarmId: uuid.uuidString,
                alarmName: trimmedAlarmName
            )
            NotificationManager.shared.startAlarmKitUnlockPromptLoop(
                sourceAlarmId: lookupUUID.uuidString,
                surfaceAlarmId: uuid.uuidString,
                alarmName: trimmedAlarmName
            )
            NotificationCenter.default.post(
                name: .alarmKitCustomUIHandoffRequested,
                object: nil,
                userInfo: [
                    "alarmId": lookupUUID.uuidString,
                    "surfaceAlarmId": uuid.uuidString
                ]
            )
        }

        return .result()
    }
}
#endif
