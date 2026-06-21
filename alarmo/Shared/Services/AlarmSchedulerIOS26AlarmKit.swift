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

            // Pre-stage selected sound now so engine has a local file ready when
            // alarm fires, even after app relaunch/background transitions.
            if !sound.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               sound.lowercased() != "default" {
                _ = stageNotificationSound(named: sound)
                print("[Scheduler] Pre-staged sound at schedule time: '\(sound)'")
            }
            _ = Self.ensureSilentAlertSoundStaged()

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
            let helper = AlarmSchedulerIOS26AlarmKit()
            helper.cancelLockedContinuityGuard(
                manager: AlarmManager.shared,
                sourceAlarmId: id.uuidString,
                reason: "cancel-alarm"
            )
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

    /// Cancels AlarmKit registrations that have no backing store alarm — the
    /// orphans that cause "I changed the sound but still hear the previous one".
    /// When an alarm is replaced (its store row removed and a new one created), its
    /// old AlarmKit registration carries the OLD sound and keeps firing forever
    /// because `reconcilePersistedAlarms` only ever walked the store, never the
    /// actual AlarmKit registrations. Conservative by design: only purges DIRECT
    /// top-level orphans (surface == source, source not in the store) and never an
    /// alerting alarm or any auxiliary surface (snooze/continuity/recovery, which
    /// always have surface != source). Skipped entirely while an alarm is ringing.
    func cancelOrphanedRegistrations(knownStoreIds: Set<UUID>) async {
#if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            guard !AlarmAudioStateController.shared.isAlarmRinging else {
                logger.log("Orphan reconcile skipped — alarm ringing")
                return
            }
            let registered: [AlarmKit.Alarm]
            do {
                registered = try AlarmManager.shared.alarms
            } catch {
                logger.error("Orphan reconcile fetch failed: \(error.localizedDescription, privacy: .public)")
                return
            }
            for alarm in registered {
                if alarm.state == .alerting { continue }
                let surfaceId = alarm.id
                if knownStoreIds.contains(surfaceId) { continue }
                // Only purge a top-level alarm surface (surface == source). Auxiliary
                // surfaces always map to a different source id and are managed by
                // their own lifecycle — never touch them here.
                let sourceIdStr = AlarmCustomUIHandoffStore.sourceAlarmID(forSurfaceAlarmID: surfaceId.uuidString)
                guard sourceIdStr == surfaceId.uuidString else { continue }
                await cancelAlarm(id: surfaceId)
                logger.log("Cancelled orphaned AlarmKit alarm \(surfaceId.uuidString, privacy: .public) — no backing store row")
            }
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

            // Pre-stage selected sound now so engine can resolve it reliably
            // while locked/backgrounded.
            if !alarm.soundName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               alarm.soundName.lowercased() != "default" {
                _ = stageNotificationSound(named: alarm.soundName)
                print("[Scheduler] Pre-staged sound at schedule time: '\(alarm.soundName)'")
            }
            _ = Self.ensureSilentAlertSoundStaged()

            let effectiveSoundName = try await scheduleWithFallbackSound(
                manager: manager,
                id: alarm.id,
                title: title,
                schedule: schedule,
                snoozeEnabled: snoozeEnabled,
                snoozeInterval: snoozeInterval,
                preferredSoundName: alarm.soundName,
                sourceAlarm: alarm
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
            if AlarmFeatureFlags.alarmKitPrimaryOwnerNoRespawn {
                cancelLockedContinuityGuard(
                    manager: manager,
                    sourceAlarmId: alarm.id.uuidString,
                    reason: "respawn-disabled"
                )
            } else {
                await armLockedContinuityGuard(
                    manager: manager,
                    sourceAlarm: alarm,
                    fireDate: nextFireDate
                )
            }
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
    let alarmName: String
    let soundName: String
    let missionType: String?
    let sourceAlarmId: String

    init(
        title: String = "Alarm",
        alarmName: String = "Alarm",
        soundName: String = "default",
        missionType: String? = nil,
        sourceAlarmId: String = ""
    ) {
        self.title = title
        self.alarmName = alarmName
        self.soundName = soundName
        self.missionType = missionType
        self.sourceAlarmId = sourceAlarmId
    }
}

@available(iOS 26.0, *)
extension AlarmSchedulerIOS26AlarmKit {
    var fallbackAlarmSoundKey: String { "cockpitalert" }
    var maxAlarmKitSoundDuration: TimeInterval { 29.5 }
    var alarmKitStopButtonText: String { "Open to Stop" }
    var alarmKitStopButtonSymbol: String { "alarm.fill" }
    var alarmKitTintColor: Color { Colors.accentBlue }

    private func alarmKitSnoozeButtonLabel(interval: TimeInterval) -> String {
        let total = max(1, Int(interval))
        let minutes = total / 60
        let seconds = total % 60
        if minutes > 0, seconds > 0 {
            return "Snooze \(minutes)m \(seconds)s"
        }
        if minutes > 0 {
            return "Snooze \(minutes) min"
        }
        return "Snooze \(seconds)s"
    }

    private func makeAlarmKitSnoozeButton(interval: TimeInterval) -> AlarmButton {
        AlarmButton(
            text: LocalizedStringResource(stringLiteral: alarmKitSnoozeButtonLabel(interval: interval)),
            textColor: .black,
            systemImageName: "zzz"
        )
    }

    private func makeAlarmKitUnlockToStopButton() -> AlarmButton {
        AlarmButton(
            text: LocalizedStringResource(stringLiteral: "Unlock to Stop"),
            textColor: .black,
            systemImageName: "lock.open.fill"
        )
    }

    /// Shared lock-screen button policy for primary and recovery AlarmKit surfaces.
    struct AlarmKitRingingButtonPolicy {
        enum SecondaryKind: Equatable {
            case none(reason: String)
            case snooze(interval: TimeInterval)
            case unlockToStop
        }

        let secondary: SecondaryKind

        static func from(alarm: Alarm, snoozeInterval: TimeInterval?) -> AlarmKitRingingButtonPolicy {
            _ = alarm
            _ = snoozeInterval
            return AlarmKitRingingButtonPolicy(secondary: .unlockToStop)
        }

        static func legacy(snoozeEnabled: Bool, snoozeInterval: TimeInterval?) -> AlarmKitRingingButtonPolicy {
            _ = snoozeEnabled
            _ = snoozeInterval
            return AlarmKitRingingButtonPolicy(secondary: .unlockToStop)
        }
    }

    private func logAlarmKitSecondaryButton(policy: AlarmKitRingingButtonPolicy, context: String) {
        switch policy.secondary {
        case .unlockToStop:
            print("[AlarmKitUI] \(context) secondaryButton=\"Unlock to Stop\" behavior=custom openApp=true")
        case .snooze(let interval):
            print("[AlarmKitUI] \(context) secondaryButton=\"\(alarmKitSnoozeButtonLabel(interval: interval))\" behavior=custom openApp=false missionsRequired=false")
        case .none(let reason):
            print("[AlarmKitUI] \(context) secondaryButton=\"none\" enabled=false reason=\(reason)")
        }
    }

    private func alarmKitAlertTitle(for schedule: AlarmKit.Alarm.Schedule) -> String {
        let hour = resolvedAlarmHour(from: schedule) ?? Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:
            return "⏰ Good morning! 🌞 Rise and shine"
        case 12..<17:
            return "⏰ Good afternoon! 🌞 Hope your day is going well"
        case 17..<21:
            return "⏰ Good evening! 🌆 Hope you had a good day"
        default:
            return "⏰ Good night! 🌜 Time to rest and recharge"
        }
    }

    private func resolvedAlarmHour(from schedule: AlarmKit.Alarm.Schedule) -> Int? {
        switch schedule {
        case .fixed(let date):
            return Calendar.current.component(.hour, from: date)
        case .relative(let relativeSchedule):
            return Int(relativeSchedule.time.hour)
        @unknown default:
            return nil
        }
    }

    /// Stages a valid 1-second silent CAF file into Library/Sounds/ for use as
    /// AlarmKit sound. Returns the staged FILE NAME (with extension) to pass to
    /// `AlertConfiguration.AlertSound.named(...)`.
    @discardableResult
    static func ensureSilentAlertSoundStaged() -> String? {
        let silentFileName = "alarmo_silence.caf"
        guard let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first else {
            print("[SilentSound] ❌ nil-libraryDir")
            return nil
        }
        let soundsDir = library.appendingPathComponent("Sounds", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: soundsDir, withIntermediateDirectories: true)
        } catch {
            print("[SilentSound] ❌ create-sounds-dir-failed: \(error)")
            return nil
        }
        let destinationURL = soundsDir.appendingPathComponent(silentFileName, isDirectory: false)
        if FileManager.default.fileExists(atPath: destinationURL.path),
           let attrs = try? FileManager.default.attributesOfItem(atPath: destinationURL.path),
           let size = attrs[.size] as? Int,
           size > 1000 {
            print("[SilentSound] ✅ existing-valid: \(silentFileName) size=\(size)")
            return silentFileName
        }
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 44_100.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false
        ]
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("alarmo_silence_temp.caf")
        do {
            let audioFile = try AVAudioFile(
                forWriting: tempURL,
                settings: settings,
                commonFormat: .pcmFormatInt16,
                interleaved: false
            )
            let frameCount = AVAudioFrameCount(44_100)
            guard let buffer = AVAudioPCMBuffer(
                pcmFormat: audioFile.processingFormat,
                frameCapacity: frameCount
            ) else {
                print("[SilentSound] ❌ generation-failed: buffer-allocation")
                return nil
            }
            buffer.frameLength = frameCount
            try audioFile.write(from: buffer)

            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.moveItem(at: tempURL, to: destinationURL)
            guard let verifyPlayer = try? AVAudioPlayer(contentsOf: destinationURL),
                  verifyPlayer.duration > 0 else {
                print("[SilentSound] ❌ generation-failed: verify-player")
                return nil
            }
            print("[SilentSound] ✅ generated-valid: \(silentFileName) duration=\(String(format: "%.2f", verifyPlayer.duration))")
            return silentFileName
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            print("[SilentSound] ❌ generation-failed: \(error)")
            return nil
        }
    }

    func scheduleWithFallbackSound(
        manager: AlarmManager,
        id: UUID,
        originalAlarmID: UUID? = nil,
        title: String,
        schedule: AlarmKit.Alarm.Schedule,
        snoozeEnabled: Bool,
        snoozeInterval: TimeInterval?,
        preferredSoundName: String?,
        sourceAlarm: Alarm? = nil
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

        let buttonPolicy: AlarmKitRingingButtonPolicy = {
            if let sourceAlarm {
                return AlarmKitRingingButtonPolicy.from(alarm: sourceAlarm, snoozeInterval: snoozeInterval)
            }
            return AlarmKitRingingButtonPolicy.legacy(snoozeEnabled: snoozeEnabled, snoozeInterval: snoozeInterval)
        }()
        let missionType = sourceAlarm?.missions.first(where: { $0.type != .off })?.type.rawValue
        let preferredConfiguration = makeConfiguration(
            alarmID: id,
            originalAlarmID: originalAlarmID,
            title: title,
            schedule: schedule,
            buttonPolicy: buttonPolicy,
            soundName: requestedSound,
            missionType: missionType
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
                    buttonPolicy: buttonPolicy,
                    soundName: nil,
                    missionType: missionType
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
                buttonPolicy: buttonPolicy,
                soundName: nil,
                useSystemDefaultSound: true,
                missionType: missionType
            )
            _ = try await manager.schedule(id: id, configuration: systemDefaultConfiguration)
            return "default"
        }
    }

    fileprivate func makeConfiguration(
        alarmID: UUID,
        originalAlarmID: UUID? = nil,
        title: String,
        schedule: AlarmKit.Alarm.Schedule,
        buttonPolicy: AlarmKitRingingButtonPolicy,
        soundName: String? = nil,
        useSystemDefaultSound: Bool = false,
        uiShellOnly: Bool = false,
        missionType: String? = nil
    ) -> AlarmManager.AlarmConfiguration<AlarmoAlarmMetadata> {
        let alertTitle = alarmKitAlertTitle(for: schedule)
        let secondaryButton: AlarmButton?
        let resolvedSnoozeInterval: TimeInterval?
        let secondaryButtonBehavior: AlarmPresentation.Alert.SecondaryButtonBehavior?
        switch buttonPolicy.secondary {
        case .unlockToStop:
            secondaryButton = makeAlarmKitUnlockToStopButton()
            secondaryButtonBehavior = .custom
            resolvedSnoozeInterval = nil
        case .snooze(let interval):
            secondaryButton = makeAlarmKitSnoozeButton(interval: interval)
            secondaryButtonBehavior = .custom
            resolvedSnoozeInterval = interval
        case .none:
            secondaryButton = nil
            secondaryButtonBehavior = nil
            resolvedSnoozeInterval = nil
        }
        let alertPresentation = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: alertTitle),
            stopButton: AlarmButton(
                // "Open to Stop" is intentional: the AlarmKit stop gesture/button
                // routes into app-controlled stop/snooze handling instead of
                // being treated as an unconditional final stop in this architecture.
                text: LocalizedStringResource(stringLiteral: alarmKitStopButtonText),
                textColor: .white,
                systemImageName: alarmKitStopButtonSymbol
            ),
            secondaryButton: secondaryButton,
            secondaryButtonBehavior: secondaryButtonBehavior
        )

        let countdownPresentation: AlarmPresentation.Countdown? = nil
        let pausedPresentation: AlarmPresentation.Paused? = nil

        let presentation = AlarmPresentation(
            alert: alertPresentation,
            countdown: countdownPresentation,
            paused: pausedPresentation
        )

        let attributes = AlarmAttributes(
            presentation: presentation,
            metadata: AlarmoAlarmMetadata(
                title: alertTitle,
                alarmName: title,
                soundName: soundName ?? "default",
                missionType: missionType,
                sourceAlarmId: (originalAlarmID ?? alarmID).uuidString
            ),
            tintColor: alarmKitTintColor
        )
        print("[AlarmKitUI] title=\"\(alertTitle)\" stopButton=\"\(alarmKitStopButtonText)\" symbol=\"\(alarmKitStopButtonSymbol)\" tintColor=accentBlue")
        logAlarmKitSecondaryButton(policy: buttonPolicy, context: "primary")

        let alarmKitSound: AlertConfiguration.AlertSound = {
            if uiShellOnly {
                if let silent = Self.ensureSilentAlertSoundStaged() {
                    print("[AlarmKitUIShell] using silent AlarmKit sound for UI-only surface id=\(alarmID.uuidString)")
                    return .named(silent)
                }
                print("[AlarmKitUIShell] silent staging failed — falling back to audible for id=\(alarmID.uuidString)")
            }
            // Audible floor: AlarmKit plays the user's sound when the app is dead/locked
            // and the engine cannot run. AppEngine reclaims when the app is active.
            return resolveAlarmKitAudibleSound(
                soundName: soundName,
                useSystemDefault: useSystemDefaultSound
            )
        }()

        let sourceAlarmId = (originalAlarmID ?? alarmID).uuidString
        let stopIntent = StopAlarmIntent(alarmID: alarmID.uuidString, originalAlarmID: originalAlarmID?.uuidString)
        let countdown = resolvedSnoozeInterval.map {
            AlarmKit.Alarm.CountdownDuration(preAlert: nil, postAlert: $0)
        }
        switch buttonPolicy.secondary {
        case .snooze:
            return AlarmManager.AlarmConfiguration(
                countdownDuration: countdown,
                schedule: schedule,
                attributes: attributes,
                stopIntent: stopIntent,
                secondaryIntent: SnoozeAlarmIntent(alarmID: alarmID.uuidString, originalAlarmID: sourceAlarmId),
                sound: alarmKitSound
            )
        case .unlockToStop:
            let unlockIntent = UnlockToStopAlarmIntent(alarmID: alarmID.uuidString, originalAlarmID: sourceAlarmId)
            print("[AlarmKitUI] configured Open-to-Stop action intent=StopAlarmIntent supportedModes=foreground(.immediate)")
            print("[AlarmKitUI] configured Unlock to Stop action intent=UnlockToStopAlarmIntent supportedModes=foreground(.immediate)")
            print("[AlarmKitUIValidation] Unlock to Stop action bound=true")
            print("[AlarmKitUIValidation] Open-to-Stop action bound=true")
            print("[AlarmKitUIValidation] sourceAlarmId payload present=\(!sourceAlarmId.isEmpty)")
            return AlarmManager.AlarmConfiguration(
                countdownDuration: countdown,
                schedule: schedule,
                attributes: attributes,
                stopIntent: stopIntent,
                secondaryIntent: unlockIntent,
                sound: alarmKitSound
            )
        case .none:
            return AlarmManager.AlarmConfiguration(
                countdownDuration: countdown,
                schedule: schedule,
                attributes: attributes,
                stopIntent: stopIntent,
                secondaryIntent: nil,
                sound: alarmKitSound
            )
        }
    }

    /// Resolves and stages the user's selected alarm sound for AlarmKit.
    /// Returns `.named(stagedFile)` when the sound is valid, `.default` otherwise.
    /// Never returns the silent CAF — that file is for legacy silent-mode only.
    private func resolveAlarmKitAudibleSound(soundName: String?, useSystemDefault: Bool) -> AlertConfiguration.AlertSound {
        if useSystemDefault {
            print("[AlarmKitSound] system default sound requested, using .default")
            return .default
        }
        guard let rawName = soundName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawName.isEmpty, rawName.lowercased() != "default" else {
            print("[AlarmKitSound] no custom sound specified, using .default")
            return .default
        }
        print("[AlarmKitSound] resolving selected sound: '\(rawName)'")
        guard let stagedFile = stageNotificationSound(named: rawName) else {
            print("[AlarmKitSound] selected sound invalid, falling back to .default")
            return .default
        }
        print("[AlarmKitSound] using selected AlarmKit sound: '\(stagedFile)'")
        return .named(stagedFile)
    }

    func resolvedSnoozeInterval(for alarm: Alarm) -> TimeInterval? {
        guard let totalSeconds = alarm.resolvedSnoozeTotalSeconds else { return nil }
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
        let fileManager = FileManager.default
        guard let library = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first else { return nil }
        let soundsDir = library.appendingPathComponent("Sounds", isDirectory: true)

        let safeBase = normalizedSoundKey(rawName)
        let finalBase = safeBase.isEmpty ? "alarmo_alarm" : safeBase
        let supportedExtensions = ["caf", "m4a", "mp3", "wav", "aiff"]

        // Resolve the source up-front so we can detect a STALE staged file. When the
        // user re-records or replaces a custom sound under the same name, the staged
        // copy ("{key}_alarmkit.m4a" / "{key}.{ext}") would otherwise be served forever
        // — the "previous selected sound" symptom. If the source is newer than the
        // staged file, the staged file is removed and re-created below.
        let resolvedSource = resolveSoundURL(for: rawName)
        let sourceModified = resolvedSource.flatMap { modificationDate(of: $0) }
        func stagedIsFresh(_ stagedURL: URL) -> Bool {
            // Without a resolvable source/date we cannot prove staleness — keep the
            // existing staged file rather than risk discarding a good one.
            guard let sourceModified, let stagedModified = modificationDate(of: stagedURL) else { return true }
            return stagedModified >= sourceModified
        }

        // Return an already-staged file immediately (when still fresh), without needing
        // the source URL. Handles alarm-time calls where staging already succeeded at
        // schedule time.
        let trimmedName = "\(finalBase)_alarmkit.m4a"
        let stagedTrimmedURL = soundsDir.appendingPathComponent(trimmedName)
        if fileManager.fileExists(atPath: stagedTrimmedURL.path) {
            if stagedIsFresh(stagedTrimmedURL) { return trimmedName }
            print("[AlarmKitSound] staged file stale, re-staging: \(trimmedName)")
            try? fileManager.removeItem(at: stagedTrimmedURL)
        }
        for ext in supportedExtensions {
            let candidateName = "\(finalBase).\(ext)"
            let candidateURL = soundsDir.appendingPathComponent(candidateName)
            if fileManager.fileExists(atPath: candidateURL.path) {
                if stagedIsFresh(candidateURL) { return candidateName }
                print("[AlarmKitSound] staged file stale, re-staging: \(candidateName)")
                try? fileManager.removeItem(at: candidateURL)
            }
        }

        // Not yet staged (or stale and removed) — resolve source URL and stage it now.
        guard let sourceURL = resolvedSource else { return nil }
        let ext = sourceURL.pathExtension.lowercased()
        guard supportedExtensions.contains(ext) else { return nil }

        do {
            try fileManager.createDirectory(at: soundsDir, withIntermediateDirectories: true)
        } catch {
            return nil
        }

        let duration = audioDuration(of: sourceURL)
        if duration > maxAlarmKitSoundDuration {
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

        // 3. Check bundled sounds — full bundle scan to find resources in subdirectories
        // (e.g. BundledSounds/ringtones/). The old approach of looking in "sounds/"
        // failed because that directory does not exist in the compiled bundle.
        let supportedExtensions: Set<String> = ["wav", "aiff", "caf", "m4a", "mp3"]

        // Fast path: flat Bundle resource lookup using the original name (not the
        // normalized key). Bundle filenames include spaces (e.g. "Default Alarm.caf")
        // which the normalized key strips out, making the lookup always miss.
        let rawBase = (rawName as NSString).deletingPathExtension
        for ext in supportedExtensions {
            if let url = Bundle.main.url(forResource: rawBase, withExtension: ext) {
                return url
            }
        }

        // Full scan: finds resources in any bundle subdirectory.
        var fallbackMatch: URL?
        if let enumerator = fileManager.enumerator(at: Bundle.main.bundleURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
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
        }
        return fallbackMatch
    }

    func resolvedSoundURL(for rawName: String) -> URL? {
        resolveSoundURL(for: rawName)
    }

    /// Returns the URL of the file AlarmKit will actually play for `rawName` — the
    /// staged file in Library/Sounds (`{key}_alarmkit.m4a` when trimmed, otherwise
    /// the `{key}.{ext}` copy). This is the single source of truth that the app
    /// audio engine must converge on so AlarmKit and AppEngine never diverge onto
    /// different audio. Returns nil only when staging fails entirely.
    func stagedSoundURL(for rawName: String) -> URL? {
        guard let staged = stageNotificationSound(named: rawName) else { return nil }
        guard let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first else { return nil }
        let url = library.appendingPathComponent("Sounds", isDirectory: true).appendingPathComponent(staged, isDirectory: false)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private func audioDuration(of url: URL) -> TimeInterval {
        let asset = AVURLAsset(url: url)
        let seconds = CMTimeGetSeconds(asset.duration)
        guard seconds.isFinite, seconds > 0 else { return 0 }
        return seconds
    }

    private func modificationDate(of url: URL) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
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

    /// Schedules a **silent** AlarmKit surface with full lock-screen UI (slide-to-stop
    /// + snooze) while the app engine remains the audible source.
    func scheduleUIShellWithFallbackSound(
        manager: AlarmManager,
        id: UUID,
        originalAlarmID: UUID,
        title: String,
        schedule: AlarmKit.Alarm.Schedule,
        sourceAlarm: Alarm
    ) async throws {
        try? manager.cancel(id: id)
        _ = Self.ensureSilentAlertSoundStaged()
        let snoozeInterval = resolvedSnoozeInterval(for: sourceAlarm)
        let buttonPolicy = AlarmKitRingingButtonPolicy.from(alarm: sourceAlarm, snoozeInterval: snoozeInterval)
        let config = makeConfiguration(
            alarmID: id,
            originalAlarmID: originalAlarmID,
            title: title,
            schedule: schedule,
            buttonPolicy: buttonPolicy,
            soundName: nil,
            useSystemDefaultSound: false,
            uiShellOnly: true,
            missionType: sourceAlarm.missions.first(where: { $0.type != .off })?.type.rawValue
        )
        logAlarmKitSecondaryButton(policy: buttonPolicy, context: "ui-shell")
        _ = try await manager.schedule(id: id, configuration: config)
        print("[AlarmKitUIShell] scheduled silent UI shell surface=\(id.uuidString) source=\(originalAlarmID.uuidString)")
    }

    // MARK: - Recovery alarm scheduling

    /// Last-resort audible AlarmKit recovery uses the **same** lock-screen button
    /// policy as the primary scheduled alarm (Snooze or Unlock to Stop).
    func scheduleRecoveryWithFallbackSound(
        manager: AlarmManager,
        id: UUID,
        originalAlarmID: UUID? = nil,
        title: String,
        schedule: AlarmKit.Alarm.Schedule,
        preferredSoundName: String?,
        sourceAlarm: Alarm
    ) async throws -> String {
        try? manager.cancel(id: id)

        let requestedSound: String? = {
            guard let value = preferredSoundName?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !value.isEmpty, value.lowercased() != "default" else { return nil }
            return value
        }()

        let snoozeInterval = resolvedSnoozeInterval(for: sourceAlarm)
        let buttonPolicy = AlarmKitRingingButtonPolicy.from(alarm: sourceAlarm, snoozeInterval: snoozeInterval)
        let missionType = sourceAlarm.missions.first(where: { $0.type != .off })?.type.rawValue
        print("[AlarmKitUI] recovery surface using same button policy as primary")

        let preferredConfig = makeRecoveryConfiguration(
            alarmID: id,
            originalAlarmID: originalAlarmID,
            title: title,
            schedule: schedule,
            buttonPolicy: buttonPolicy,
            soundName: requestedSound,
            missionType: missionType
        )
        logAlarmKitSecondaryButton(policy: buttonPolicy, context: "recovery")
        do {
            _ = try await manager.schedule(id: id, configuration: preferredConfig)
            print("[AlarmKitRecovery] using selected sound source=\(originalAlarmID?.uuidString ?? id.uuidString) sound=\(requestedSound ?? "default")")
            return requestedSound ?? "default"
        } catch {
            logger.error("Recovery schedule primary attempt failed for \(id.uuidString, privacy: .public): \(error.localizedDescription, privacy: .public)")
            try? manager.cancel(id: id)
        }

        if requestedSound != nil {
            let fallbackConfig = makeRecoveryConfiguration(
                alarmID: id,
                originalAlarmID: originalAlarmID,
                title: title,
                schedule: schedule,
                buttonPolicy: buttonPolicy,
                soundName: nil,
                missionType: missionType
            )
            do {
                _ = try await manager.schedule(id: id, configuration: fallbackConfig)
                print("[AlarmKitRecovery] using default sound fallback source=\(originalAlarmID?.uuidString ?? id.uuidString)")
                return "default"
            } catch {
                logger.error("Recovery schedule fallback failed for \(id.uuidString, privacy: .public): \(error.localizedDescription, privacy: .public)")
                try? manager.cancel(id: id)
            }
        }

        let systemConfig = makeRecoveryConfiguration(
            alarmID: id,
            originalAlarmID: originalAlarmID,
            title: title,
            schedule: schedule,
            buttonPolicy: buttonPolicy,
            soundName: nil,
            useSystemDefaultSound: true,
            missionType: missionType
        )
        _ = try await manager.schedule(id: id, configuration: systemConfig)
        print("[AlarmKitRecovery] using system default sound fallback source=\(originalAlarmID?.uuidString ?? id.uuidString)")
        return "default"
    }

    /// System-owned backstop surfaces scheduled at alarm time. Fire even when the app
    /// is force-closed — covers side-button silence with no running process.
    @available(iOS 26.0, *)
    func armLockedContinuityGuard(
        manager: AlarmManager,
        sourceAlarm: Alarm,
        fireDate: Date
    ) async {
        if AlarmFeatureFlags.alarmKitPrimaryOwnerNoRespawn {
            cancelLockedContinuityGuard(
                manager: manager,
                sourceAlarmId: sourceAlarm.id.uuidString,
                reason: "respawn-disabled"
            )
            return
        }
        let sourceId = sourceAlarm.id.uuidString
        cancelLockedContinuityGuard(manager: manager, sourceAlarmId: sourceId, reason: "re-arm")

        let delays: [TimeInterval] = [8, 20, 40, 75]
        let now = Date()
        let title = sourceAlarm.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Alarm" : sourceAlarm.name.trimmingCharacters(in: .whitespacesAndNewlines)
        var scheduled: [UUID] = []

        for delay in delays {
            let trigger = fireDate.addingTimeInterval(delay)
            guard trigger.timeIntervalSince(now) > 2 else { continue }
            let surfaceId = UUID()
            do {
                _ = try await scheduleRecoveryWithFallbackSound(
                    manager: manager,
                    id: surfaceId,
                    originalAlarmID: sourceAlarm.id,
                    title: title,
                    schedule: .fixed(trigger),
                    preferredSoundName: sourceAlarm.soundName,
                    sourceAlarm: sourceAlarm
                )
                AlarmCustomUIHandoffStore.request(alarmID: sourceAlarm.id, surfaceAlarmID: surfaceId)
                scheduled.append(surfaceId)
                print("[ContinuityGuard] armed surface=\(surfaceId.uuidString) source=\(sourceId) at=+\(Int(delay))s")
            } catch {
                print("[ContinuityGuard] arm failed surface=\(surfaceId.uuidString) error=\(error.localizedDescription)")
            }
        }
        if !scheduled.isEmpty {
            AlarmCustomUIHandoffStore.recordLockedContinuityGuard(sourceAlarmId: sourceId, surfaceIds: scheduled)
        }
    }

    @available(iOS 26.0, *)
    func cancelLockedContinuityGuard(
        manager: AlarmManager,
        sourceAlarmId: String,
        reason: String
    ) {
        let ids = AlarmCustomUIHandoffStore.lockedContinuityGuardSurfaceIds(sourceAlarmId: sourceAlarmId)
        for id in ids {
            try? manager.cancel(id: id)
        }
        AlarmCustomUIHandoffStore.clearLockedContinuityGuard(sourceAlarmId: sourceAlarmId, reason: reason)
    }

    @available(iOS 26.0, *)
    func cancelAllLockedContinuityGuards(manager: AlarmManager, reason: String) {
        let ids = AlarmCustomUIHandoffStore.allLockedContinuityGuardSurfaceIds()
        for id in ids {
            try? manager.cancel(id: id)
        }
        AlarmCustomUIHandoffStore.clearAllLockedContinuityGuards(reason: reason)
    }

    /// Recovery surfaces use `RecoveryStopAlarmIntent` so slide-to-stop respawns without
    /// Face ID and loops until the user unlocks and stops in-app.
    fileprivate func makeRecoveryConfiguration(
        alarmID: UUID,
        originalAlarmID: UUID? = nil,
        title: String,
        schedule: AlarmKit.Alarm.Schedule,
        buttonPolicy: AlarmKitRingingButtonPolicy,
        soundName: String? = nil,
        useSystemDefaultSound: Bool = false,
        missionType: String? = nil
    ) -> AlarmManager.AlarmConfiguration<AlarmoAlarmMetadata> {
        let sourceAlarmId = (originalAlarmID ?? alarmID).uuidString
        let recoveryStop = RecoveryStopAlarmIntent(
            sourceAlarmID: sourceAlarmId,
            surfaceAlarmID: alarmID.uuidString
        )
        let alertTitle = alarmKitAlertTitle(for: schedule)
        let secondaryButton: AlarmButton?
        let resolvedSnoozeInterval: TimeInterval?
        let secondaryButtonBehavior: AlarmPresentation.Alert.SecondaryButtonBehavior?
        switch buttonPolicy.secondary {
        case .unlockToStop:
            secondaryButton = makeAlarmKitUnlockToStopButton()
            secondaryButtonBehavior = .custom
            resolvedSnoozeInterval = nil
        case .snooze(let interval):
            secondaryButton = makeAlarmKitSnoozeButton(interval: interval)
            secondaryButtonBehavior = .custom
            resolvedSnoozeInterval = interval
        case .none:
            secondaryButton = nil
            secondaryButtonBehavior = nil
            resolvedSnoozeInterval = nil
        }
        let alertPresentation = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: alertTitle),
            stopButton: AlarmButton(
                text: LocalizedStringResource(stringLiteral: alarmKitStopButtonText),
                textColor: .white,
                systemImageName: alarmKitStopButtonSymbol
            ),
            secondaryButton: secondaryButton,
            secondaryButtonBehavior: secondaryButtonBehavior
        )
        let presentation = AlarmPresentation(
            alert: alertPresentation,
            countdown: nil,
            paused: nil
        )
        let attributes = AlarmAttributes(
            presentation: presentation,
            metadata: AlarmoAlarmMetadata(
                title: alertTitle,
                alarmName: title,
                soundName: soundName ?? "default",
                missionType: missionType,
                sourceAlarmId: sourceAlarmId
            ),
            tintColor: alarmKitTintColor
        )
        logAlarmKitSecondaryButton(policy: buttonPolicy, context: "recovery-stop-intent")
        let alarmKitSound = resolveAlarmKitAudibleSound(
            soundName: soundName,
            useSystemDefault: useSystemDefaultSound
        )
        let countdown = resolvedSnoozeInterval.map {
            AlarmKit.Alarm.CountdownDuration(preAlert: nil, postAlert: $0)
        }
        switch buttonPolicy.secondary {
        case .snooze:
            return AlarmManager.AlarmConfiguration(
                countdownDuration: countdown,
                schedule: schedule,
                attributes: attributes,
                stopIntent: recoveryStop,
                secondaryIntent: SnoozeAlarmIntent(alarmID: alarmID.uuidString, originalAlarmID: sourceAlarmId),
                sound: alarmKitSound
            )
        case .unlockToStop:
            return AlarmManager.AlarmConfiguration(
                countdownDuration: countdown,
                schedule: schedule,
                attributes: attributes,
                stopIntent: recoveryStop,
                secondaryIntent: UnlockToStopAlarmIntent(alarmID: alarmID.uuidString, originalAlarmID: sourceAlarmId),
                sound: alarmKitSound
            )
        case .none:
            return AlarmManager.AlarmConfiguration(
                countdownDuration: countdown,
                schedule: schedule,
                attributes: attributes,
                stopIntent: recoveryStop,
                secondaryIntent: nil,
                sound: alarmKitSound
            )
        }
    }
}

@available(iOS 26.0, *)
struct StopAlarmIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Stop Alarm"
    // `.foreground(.immediate)` is the iOS 26 replacement for the deprecated
    // `openAppWhenRun = true`. Slide-to-stop immediately triggers iOS Face ID /
    // passcode unlock, then foregrounds the app so the engine (already playing)
    // and the full-screen Stop / Snooze UI are shown. Without this explicit mode
    // the lock-screen button can run the intent in the background and never open
    // the app.
    static var supportedModes: IntentModes { .foreground(.immediate) }

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
            print("🧭 [ALARMTRACE_ACTION] EVENT=ALARMKIT_SLIDE_TO_STOP_INTENT_INVALID_ALARM_ID RAW_ID=\(alarmID)")
            return .result()
        }
        
        let lookupUUIDString = originalAlarmID ?? alarmID
        guard let lookupUUID = UUID(uuidString: lookupUUIDString) else {
            print("🧭 [ALARMTRACE_ACTION] EVENT=ALARMKIT_SLIDE_TO_STOP_INTENT_INVALID_ORIGINAL_ID RAW_ID=\(lookupUUIDString)")
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
            // Locked/Background handling must apply whenever app is not active.
            // If we restrict this only to protected-data-unavailable, quick
            // unlock -> relock cycles can leave the system in a silent state:
            // reassert calls run while app is background-unlocked, but no
            // AlarmKit surface gets respawned.
            let state = UIApplication.shared.applicationState
            return state != .active || !UIApplication.shared.isProtectedDataAvailable
        }
        let appStateRaw = await MainActor.run { UIApplication.shared.applicationState.rawValue }
        let protectedDataAvailable = await MainActor.run { UIApplication.shared.isProtectedDataAvailable }
        print("🧭 [ALARMTRACE_ACTION] EVENT=ALARMKIT_SLIDE_TO_STOP_INTENT_ENTRY SURFACE_ID=\(uuid.uuidString) SOURCE_ID=\(lookupUUID.uuidString) APP_STATE=\(appStateRaw) PROTECTED_DATA=\(protectedDataAvailable) LOCKED_HANDLING=\(shouldUseLockedHandling) SUPPRESS_UNLOCK_PROMPT=\(suppressUnlockPrompt)")
        let resolvedAlarmName = await MainActor.run {
            AlarmStore.shared.alarm(by: lookupUUID)?.name
        }
        let trimmedAlarmName = resolvedAlarmName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let slideSystemVol = AVAudioSession.sharedInstance().outputVolume
        let slidePlayerVol = AlarmContinuousAudioEngine.shared.currentPlayerVolume
        let slideAppTarget = AlarmAudioStateController.shared.selectedSoundVolume
        let slidePhase = AlarmAudioStateController.shared.phase.rawValue
        print("[SlideToStop] user swiped: system=\(String(format: "%.2f", slideSystemVol)) player=\(String(format: "%.2f", slidePlayerVol)) appTarget=\(String(format: "%.2f", slideAppTarget)) phase=\(slidePhase) lockedHandling=\(shouldUseLockedHandling) enginePlaying=\(AlarmContinuousAudioEngine.shared.confirmStillPlaying())")
        AlarmContinuousAudioEngine.shared.debugVolumeSnapshot(context: "stop-intent-entry")

        let resolvedRunId = await MainActor.run {
            AlarmAudioStateController.shared.currentAlarmRunId?.uuidString
        }
        print("[OpenToStop] intent invoked source=\(lookupUUID.uuidString)")
        print("[OpenToStop] supportedModes=foreground(.immediate)")
        print("[AuthHandoff] AlarmKit Open-to-Stop invoked source=\(lookupUUID.uuidString) runId=\(resolvedRunId ?? "nil")")
        print("[AuthHandoff] Open-to-Stop invoked source=\(lookupUUID.uuidString)")
        print("[AuthHandoff] Open-to-Stop invoked; finalStop=false source=\(lookupUUID.uuidString)")
        print("[AuthHandoff] final stop NOT set for Open-to-Stop source=\(lookupUUID.uuidString)")
        // Persist ringing handoff BEFORE auth, engine checks, or async work.
        // Never mark final stop — slide-to-stop only requests authenticate → open app → custom UI.
        await MainActor.run {
            AlarmAuthHandoffStore.persistStopIntentHandoff(
                sourceAlarmId: lookupUUID,
                surfaceAlarmId: uuid,
                runId: resolvedRunId,
                handoffSource: .alarmKitOpenToStop
            )
            AlarmAudioStateController.shared.clearAlarmKitPrimaryLocked(reason: "slide-to-stop-surface-consumed")
            NotificationCenter.default.post(
                name: .alarmKitCustomUIHandoffRequested,
                object: nil,
                userInfo: [
                    "alarmId": lookupUUID.uuidString,
                    "surfaceAlarmId": uuid.uuidString
                ]
            )
        }
        print("[AuthHandoff] persisted ringing handoff source=\(lookupUUID.uuidString)")
        print("[AuthHandoff] persisted ringing state before auth source=\(lookupUUID.uuidString)")
        print("[AlarmHandoff] StopIntent requested app open/auth source=\(lookupUUID.uuidString)")

        if shouldUseLockedHandling && !suppressUnlockPrompt {
            await MainActor.run {
                NotificationManager.shared.scheduleAlarmRecoveryOpenAppNotification(
                    sourceAlarmId: lookupUUID.uuidString,
                    reason: "slide-to-stop-no-unlock"
                )
            }
            print("[AlarmKitRecovery] pre-armed reason=open-to-stop-auth-timeout source=\(lookupUUID.uuidString)")
            print("[AlarmKitRecovery] pre-armed audible recovery reason=auth-timeout-not-unlocked source=\(lookupUUID.uuidString)")
            print("[AuthHandoff] waiting for app activation source=\(lookupUUID.uuidString)")
        }

        if shouldUseLockedHandling {
            if AlarmFeatureFlags.alarmKitPrimaryOwnerNoRespawn {
                await MainActor.run {
                    _ = NotificationManager.shared.startAppEngineAfterAlarmKitSuppression(
                        sourceAlarmId: lookupUUID.uuidString,
                        surfaceAlarmId: uuid.uuidString,
                        reason: "slide-to-stop"
                    )
                }
                print("[AlarmKitRespawn] disabled — AppEngine takeover attempted after slide-to-stop source=\(lookupUUID.uuidString)")
                return .result()
            }
            AlarmContinuousAudioEngine.shared.debugVolumeSnapshot(context: "stop-intent-locked-handling")

            await MainActor.run {
                _ = AlarmAudioStateController.shared.tryEngineAudibleWhileLocked(
                    reason: "slide-to-stop"
                )
            }

            let engineActuallyAudible = await AlarmAudioStateController.shared.isAppEngineActuallyAudible(
                reason: "slide-to-stop"
            )
            if engineActuallyAudible {
                await MainActor.run {
                    NotificationManager.shared.scheduleRecoveryPromptNotification(sourceAlarmId: lookupUUID.uuidString)
                    NotificationManager.shared.armEngineAudibleVerification(
                        sourceAlarmId: lookupUUID.uuidString,
                        reason: "slide-to-stop"
                    )
                    NotificationManager.shared.startLockedNoUIAudibleWatchdog(sourceAlarmId: lookupUUID.uuidString)
                }
                print("🧭 [ALARMTRACE_ACTION] EVENT=ALARMKIT_SLIDE_TO_STOP_ENGINE_AUDIBLE SOURCE_ID=\(lookupUUID.uuidString) SURFACE_ID=\(uuid.uuidString)")
                print("[AlarmKitRespawn] slide-to-stop — AppEngine audible; no AlarmKit respawn source=\(lookupUUID.uuidString)")
                return .result()
            }

            print("[AlarmKitRespawn] slide-to-stop — AlarmKit sound gone, AppEngine inaudible; respawning source=\(lookupUUID.uuidString)")
            let scheduledCount = await NotificationManager.shared.scheduleSystemOwnedContinuityRecoveries(
                sourceAlarmId: lookupUUID.uuidString,
                dismissedSurfaceIds: [uuid.uuidString],
                reason: "slide-to-stop",
                delays: [1.0, 3.5, 8.0, 15.0]
            )
            await MainActor.run {
                NotificationManager.shared.orchestrateAlarmKitRespawnWhenSoundGone(
                    sourceAlarmId: lookupUUID.uuidString,
                    reason: "slide-to-stop",
                    dismissedSurfaceId: uuid.uuidString,
                    forceAfterDismissal: true
                )
            }
            if scheduledCount > 0 {
                print("🧭 [ALARMTRACE_ACTION] EVENT=ALARMKIT_SLIDE_TO_STOP_RESPAWN_SCHEDULED SOURCE_ID=\(lookupUUID.uuidString) SURFACE_ID=\(uuid.uuidString) COUNT=\(scheduledCount)")
            }
            return .result()
        }

        // Fallback or unlocked-device path (handoff already persisted at entry).
        print("🧭 [ALARMTRACE_ACTION] EVENT=ALARMKIT_SLIDE_TO_STOP_UNLOCKED_OR_FALLBACK_PATH SOURCE_ID=\(lookupUUID.uuidString) SURFACE_ID=\(uuid.uuidString) SOUND_CONTINUES=\(AlarmContinuousAudioEngine.shared.isEngineActive)")
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

/// Recovery stop intent used on 2nd+ AlarmKit surfaces spawned after a failed auth attempt.
///
/// `openAppWhenRun = false` means pressing the lock screen button requires NO Face ID /
/// passcode. The intent immediately reschedules another recovery alarm so the alarm loop
/// cannot be broken from the lock screen — the user must unlock and tap Stop in the
/// custom full-screen UI.
@available(iOS 26.0, *)
struct UnlockToStopAlarmIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Unlock to Stop"
    // `.foreground(.immediate)` (iOS 26 replacement for `openAppWhenRun = true`):
    // tapping the secondary "Unlock to Stop" lock-screen button authenticates and
    // foregrounds the app so AlarmRingingView + AppEngine takeover can run. The
    // deprecated `openAppWhenRun` flag did not reliably open the app for AlarmKit
    // secondary custom intents, which is why the button appeared to do nothing.
    static var supportedModes: IntentModes { .foreground(.immediate) }

    @Parameter(title: "Alarm ID")
    var alarmID: String

    @Parameter(title: "Original Alarm ID")
    var originalAlarmID: String?

    init() {}

    init(alarmID: String, originalAlarmID: String? = nil) {
        self.alarmID = alarmID
        self.originalAlarmID = originalAlarmID
    }

    func perform() async throws -> some IntentResult {
        guard let surfaceUUID = UUID(uuidString: alarmID) else { return .result() }
        let lookupUUIDString = originalAlarmID ?? alarmID
        guard let lookupUUID = UUID(uuidString: lookupUUIDString) else { return .result() }

        let resolvedRunId = await MainActor.run {
            AlarmAudioStateController.shared.currentAlarmRunId?.uuidString
        }
        print("[UnlockToStop] intent invoked source=\(lookupUUID.uuidString)")
        print("[UnlockToStop] supportedModes=foreground(.immediate)")
        print("[UnlockToStop] action tapped source=\(lookupUUID.uuidString) runId=\(resolvedRunId ?? "nil")")
        print("[AuthHandoff] Unlock-to-Stop secondary tapped source=\(lookupUUID.uuidString)")
        print("[AuthHandoff] Open-to-Stop invoked; finalStop=false source=\(lookupUUID.uuidString)")
        await MainActor.run {
            AlarmAuthHandoffStore.persistStopIntentHandoff(
                sourceAlarmId: lookupUUID,
                surfaceAlarmId: surfaceUUID,
                runId: resolvedRunId,
                handoffSource: .unlockToStopNotification
            )
            print("[UnlockToStop] persisted handoff state source=\(lookupUUID.uuidString)")
            print("[AlarmKitRecovery] pre-armed reason=unlock-to-stop-auth-timeout source=\(lookupUUID.uuidString)")
            NotificationManager.shared.scheduleAlarmRecoveryOpenAppNotification(
                sourceAlarmId: lookupUUID.uuidString,
                reason: "unlock-to-stop-secondary"
            )
            NotificationCenter.default.post(
                name: .alarmKitCustomUIHandoffRequested,
                object: nil,
                userInfo: [
                    "alarmId": lookupUUID.uuidString,
                    "surfaceAlarmId": surfaceUUID.uuidString
                ]
            )
        }
        print("[UnlockToStop] requested foreground app open source=\(lookupUUID.uuidString)")
        print("[UnlockToStop] final stop NOT set source=\(lookupUUID.uuidString)")
        print("[AuthHandoff] persisted ringing handoff source=\(lookupUUID.uuidString)")
        return .result()
    }
}

@available(iOS 26.0, *)
struct SnoozeAlarmIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Snooze Alarm"
    // Snooze should work from the lock screen without forcing Face ID / passcode,
    // so it runs in the background (iOS 26 replacement for openAppWhenRun = false).
    static var supportedModes: IntentModes { .background }

    @Parameter(title: "Alarm ID")
    var alarmID: String

    @Parameter(title: "Original Alarm ID")
    var originalAlarmID: String?

    init() {}

    init(alarmID: String, originalAlarmID: String? = nil) {
        self.alarmID = alarmID
        self.originalAlarmID = originalAlarmID
    }

    func perform() async throws -> some IntentResult {
        guard let surfaceUUID = UUID(uuidString: alarmID) else {
            print("🧭 [ALARMTRACE_ACTION] EVENT=ALARMKIT_SNOOZE_INTENT_INVALID_ALARM_ID RAW_ID=\(alarmID)")
            return .result()
        }

        let lookupUUIDString = originalAlarmID ?? alarmID
        guard UUID(uuidString: lookupUUIDString) != nil else {
            print("🧭 [ALARMTRACE_ACTION] EVENT=ALARMKIT_SNOOZE_INTENT_INVALID_ORIGINAL_ID RAW_ID=\(lookupUUIDString)")
            return .result()
        }

        guard !AlarmAuthHandoffStore.isFinalStopOrSnoozePressed() else {
            print("[AlarmKitSnooze] skipped — final stop/snooze already pressed source=\(lookupUUIDString)")
            return .result()
        }

        let performed = await NotificationManager.shared.performAlarmKitSnooze(
            sourceAlarmId: lookupUUIDString,
            surfaceAlarmId: surfaceUUID.uuidString
        )
        print("🧭 [ALARMTRACE_ACTION] EVENT=ALARMKIT_SNOOZE_INTENT_COMPLETE SOURCE_ID=\(lookupUUIDString) SURFACE_ID=\(surfaceUUID.uuidString) PERFORMED=\(performed)")
        return .result()
    }
}

@available(iOS 26.0, *)
struct RecoveryStopAlarmIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Open Alarm"
    // No authentication prompt. Tapping the lock-screen button runs the intent
    // immediately in the background so we can respawn a new recovery alarm
    // before the silence gap becomes perceptible (iOS 26 replacement for
    // openAppWhenRun = false).
    static var supportedModes: IntentModes { .background }

    @Parameter(title: "Source Alarm ID")
    var sourceAlarmID: String

    @Parameter(title: "Surface Alarm ID")
    var surfaceAlarmID: String?

    init() { self.sourceAlarmID = "" }
    init(sourceAlarmID: String, surfaceAlarmID: String? = nil) {
        self.sourceAlarmID = sourceAlarmID
        self.surfaceAlarmID = surfaceAlarmID
    }

    func perform() async throws -> some IntentResult {
        print("[RecoveryHandoff] recovery stop intent fired source=\(sourceAlarmID)")

        guard !AlarmAuthHandoffStore.isFinalStopOrSnoozePressed() else {
            print("[RecoveryHandoff] skipped recovery because final stop/snooze already pressed source=\(sourceAlarmID)")
            return .result()
        }

        await MainActor.run {
            AlarmAuthHandoffStore.ensureRingingForRecovery(sourceAlarmId: sourceAlarmID)
        }

        let appIsActive = await MainActor.run { UIApplication.shared.applicationState == .active }
        if appIsActive {
            print("[RecoveryHandoff] app active; routing to custom UI source=\(sourceAlarmID)")
            await MainActor.run {
                NotificationCenter.default.post(
                    name: .alarmKitCustomUIHandoffRequested,
                    object: nil,
                    userInfo: [
                        "alarmId": sourceAlarmID,
                        "surfaceAlarmId": surfaceAlarmID ?? sourceAlarmID
                    ]
                )
            }
            return .result()
        }

        if AlarmFeatureFlags.alarmKitPrimaryOwnerNoRespawn {
            print("[RecoveryHandoff] respawn disabled — no continuity surfaces scheduled source=\(sourceAlarmID)")
            return .result()
        }

        // Locked loop: each slide-to-stop on a recovery surface schedules the next
        // system-owned surfaces until the user unlocks and final-stops in-app.
        let dismissed = surfaceAlarmID.map { [$0] } ?? []
        let count = await NotificationManager.shared.scheduleSystemOwnedContinuityRecoveries(
            sourceAlarmId: sourceAlarmID,
            dismissedSurfaceIds: dismissed,
            reason: "recovery-intent-respawn",
            delays: [1.0, 3.5, 8.0, 15.0]
        )
        print("[RecoveryHandoff] continuity respawn scheduled count=\(count) source=\(sourceAlarmID)")
        if count == 0 {
            await MainActor.run {
                NotificationManager.shared.scheduleAlarmRecoveryOpenAppNotification(
                    sourceAlarmId: sourceAlarmID,
                    reason: "recovery-intent-respawn-failed"
                )
            }
        }
        return .result()
    }
}
#endif
