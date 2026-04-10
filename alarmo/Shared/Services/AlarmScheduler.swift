import Foundation
import AVFoundation
import UserNotifications

protocol AlarmSchedulerProtocol {
    func schedule(alarm: Alarm)
    func cancel(alarmId: UUID)
    func scheduleSnooze(alarm: Alarm, totalSeconds: Int)
    func cancelRuntimeRingNotifications(for alarm: Alarm)
}

final class AlarmScheduler: AlarmSchedulerProtocol {
    private let orchestrator = NotificationOrchestrator.shared
    // Runtime follow-ups for repeating alarms (kept under budget for multiple alarms).
    private let shortRingFollowUpOffsets: [TimeInterval] = AlarmScheduler.makeShortRingFollowUpOffsets()
    // Long-chain follow-ups for one-shot/snooze alarms to keep ringing reminders active.
    private let extendedRingFollowUpOffsets: [TimeInterval] = AlarmScheduler.makeExtendedRingFollowUpOffsets()
    private let notificationSupportedExtensions: Set<String> = ["wav", "aiff", "caf"]
    private let fallbackAlarmSoundKey = "cockpitalert"
    private let maxNotificationSoundDuration: TimeInterval = 29.5

    func schedule(alarm: Alarm) {
        // ALWAYS cancel first to clean up any previous state/variation of this alarm
        cancel(alarmId: alarm.id)
        
        // If disabled, we stop here (notification is already cancelled)
        guard alarm.enabled else {
            print("[AlarmScheduler] 🔕 Alarm \(alarm.id) is disabled, skipping schedule.")
            return
        }

        // Determine Time Zone
        var targetTimeZone: TimeZone? = nil
        if alarm.timeZoneMode == .custom, let id = alarm.timeZoneIdentifier {
            targetTimeZone = TimeZone(identifier: id)
        }
        
        // 1. Repeating Alarm (Daily or Specific Days)
        if alarm.repeatMask > 0 {
            if alarm.isDaily {
                var comps = DateComponents()
                comps.hour = alarm.hour
                comps.minute = alarm.minute
                comps.second = alarm.second
                comps.timeZone = targetTimeZone // If nil, uses current (Floating)
                
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
                addRequest(id: "\(alarm.id.uuidString)-daily", trigger: trigger, alarm: alarm, scenario: .alarmRing)
            } else {
                let weekdays = RepeatMask.weekdays(from: alarm.repeatMask)
                for weekday in weekdays {
                    var comps = DateComponents()
                    comps.weekday = weekday
                    comps.hour = alarm.hour
                    comps.minute = alarm.minute
                    comps.second = alarm.second
                    comps.timeZone = targetTimeZone // If nil, uses current (Floating)
                    
                    let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
                    // Use a standardized format for repeating day identifiers
                    addRequest(id: "\(alarm.id.uuidString)-day-\(weekday)", trigger: trigger, alarm: alarm, scenario: .alarmRing)
                }
            }
            scheduleRuntimeFollowUpsForNextOccurrence(alarm: alarm)
        } 
        // 2. One-shot Alarm
        else {
             // Calculate next fire date in the target time zone
            var calendar = Calendar.current
            if let tz = targetTimeZone {
                calendar.timeZone = tz
            }
            
            // Logic to find next occurrence of (hour, minute) in target calendar
            let now = Date()
            var nextDateComp = DateComponents()
            nextDateComp.hour = alarm.hour
            nextDateComp.minute = alarm.minute
            nextDateComp.second = alarm.second // High-precision support
            
            // Use built-in nextDate
            guard let nextDate = calendar.nextDate(after: now, matching: nextDateComp, matchingPolicy: .nextTime) else {
                 print("[AlarmScheduler] ⚠️ Could not compute next fire date")
                 return
            }
            
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second, .timeZone], from: nextDate)
            
            // We use calendar trigger for one-shot specific time to be precise with clock time
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let oneShotId = "\(alarm.id.uuidString)-once"
            addRequest(id: oneShotId, trigger: trigger, alarm: alarm, scenario: .alarmRing)
            scheduleRingFollowUps(
                alarm: alarm,
                scenario: .alarmRing,
                baseIdentifier: oneShotId,
                baseIntervalFromNow: nextDate.timeIntervalSince(now),
                offsets: extendedRingFollowUpOffsets
            )
        }
        
        AlarmDebug.dumpPendingNotifications()
    }

    func cancel(alarmId: UUID) {
        let prefix = alarmId.uuidString
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let toCancel = requests.filter { $0.identifier.hasPrefix(prefix) }.map { $0.identifier }
            if !toCancel.isEmpty {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: toCancel)
                print("[AlarmScheduler] 🗑️ Cancelled \(toCancel.count) notifications for alarm \(prefix)")
            }
        }
        UNUserNotificationCenter.current().getDeliveredNotifications { delivered in
            let toRemove = delivered
                .filter { $0.request.identifier.hasPrefix(prefix) }
                .map { $0.request.identifier }
            if !toRemove.isEmpty {
                UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: toRemove)
            }
        }
    }
    
    private func addRequest(
        id: String,
        trigger: UNNotificationTrigger,
        alarm: Alarm,
        scenario: AppNotificationScenario,
        phase: Int = 0
    ) {
        let attachments = NotificationBranding.alarmAttachment(wallpaperId: alarm.wallpaperId, phase: phase).map { [$0] } ?? []
        orchestrator.schedule(
            identifier: id,
            scenario: scenario,
            trigger: trigger,
            context: AppNotificationContext(alarmName: alarm.name),
            categoryIdentifier: AlarmNotificationCategory.alarmRing,
            userInfo: ["alarmId": alarm.id.uuidString],
            sound: notificationSound(for: alarm),
            attachments: attachments,
            force: true
        ) { success in
            if success {
                AlarmDebug.logScheduleRequest(identifier: id, alarm: alarm, trigger: trigger)
            } else {
                print("[AlarmScheduler] ❌ Error scheduling: request not accepted for \(id)")
            }
        }
    }

    private func notificationSound(for alarm: Alarm) -> UNNotificationSound {
        // Local notification sounds must be <= 30s.
        // If the selected sound is too long, fall back to a short built-in alarm sound
        // so lock-screen alerts are never silent.
        if let staged = stageNotificationSound(named: alarm.soundName, enforceDurationLimit: true) {
            if shouldUseCriticalAlertSound(for: alarm) {
                return UNNotificationSound.criticalSoundNamed(UNNotificationSoundName(staged), withAudioVolume: 1.0)
            }
            return UNNotificationSound(named: UNNotificationSoundName(staged))
        }
        if let fallback = stageNotificationSound(named: fallbackAlarmSoundKey, enforceDurationLimit: true) {
            if shouldUseCriticalAlertSound(for: alarm) {
                return UNNotificationSound.criticalSoundNamed(UNNotificationSoundName(fallback), withAudioVolume: 1.0)
            }
            return UNNotificationSound(named: UNNotificationSoundName(fallback))
        }
        if shouldUseCriticalAlertSound(for: alarm) {
            return UNNotificationSound.defaultCriticalSound(withAudioVolume: 1.0)
        }
        return .default
    }

    private func shouldUseCriticalAlertSound(for alarm: Alarm) -> Bool {
        guard EntitlementInspector.hasCriticalAlertsAccess else { return false }
        // Honor existing alarm intent toggles that indicate "always loud / bypass silent".
        return alarm.bypassSilentMode || alarm.extraLoudEnabled
    }

    func scheduleSnooze(alarm: Alarm, totalSeconds: Int) {
        let clamped = max(1, totalSeconds)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(clamped), repeats: false)
        let id = "\(alarm.id.uuidString)-snooze-\(UUID().uuidString)"
        let attachments = NotificationBranding.alarmAttachment(wallpaperId: alarm.wallpaperId, phase: 0).map { [$0] } ?? []
        orchestrator.schedule(
            identifier: id,
            scenario: .alarmSnooze,
            trigger: trigger,
            context: AppNotificationContext(alarmName: alarm.name),
            categoryIdentifier: AlarmNotificationCategory.alarmRing,
            userInfo: ["alarmId": alarm.id.uuidString],
            sound: notificationSound(for: alarm),
            attachments: attachments,
            force: true
        )
        scheduleRingFollowUps(
            alarm: alarm,
            scenario: .alarmSnooze,
            baseIdentifier: id,
            baseIntervalFromNow: TimeInterval(clamped),
            offsets: extendedRingFollowUpOffsets
        )
        print("[AlarmScheduler] 💤 Snoozed for \(clamped)s")
    }

    func cancelRuntimeRingNotifications(for alarm: Alarm) {
        let alarmId = alarm.id.uuidString
        let oneShotPrefix = "\(alarmId)-once"
        let snoozePrefix = "\(alarmId)-snooze-"
        let runtimePrefix = "\(alarmId)-runtime-"

        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let toCancel = requests
                .filter { req in
                    req.identifier.hasPrefix(oneShotPrefix) ||
                    req.identifier.hasPrefix(snoozePrefix) ||
                    req.identifier.hasPrefix(runtimePrefix)
                }
                .map(\.identifier)
            if !toCancel.isEmpty {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: toCancel)
            }
        }

        UNUserNotificationCenter.current().getDeliveredNotifications { delivered in
            let toRemove = delivered
                .filter { note in
                    let id = note.request.identifier
                    return id.hasPrefix(oneShotPrefix) ||
                    id.hasPrefix(snoozePrefix) ||
                    id.hasPrefix(runtimePrefix)
                }
                .map { $0.request.identifier }
            if !toRemove.isEmpty {
                UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: toRemove)
            }
        }
    }

    private func scheduleRingFollowUps(
        alarm: Alarm,
        scenario: AppNotificationScenario,
        baseIdentifier: String,
        baseIntervalFromNow: TimeInterval,
        offsets: [TimeInterval]
    ) {
        guard baseIntervalFromNow > 0 else { return }
        for (index, offset) in offsets.enumerated() {
            let total = max(1, baseIntervalFromNow + offset)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: total, repeats: false)
            addRequest(
                id: "\(baseIdentifier)-followup-\(index + 1)",
                trigger: trigger,
                alarm: alarm,
                scenario: scenario,
                phase: index + 1
            )
        }
    }

    private func scheduleRuntimeFollowUpsForNextOccurrence(alarm: Alarm) {
        let now = Date()
        guard let nextDate = AlarmStore.nextFireDate(for: alarm, from: now) else { return }
        let interval = nextDate.timeIntervalSince(now)
        guard interval > 0 else { return }
        let base = "\(alarm.id.uuidString)-runtime-\(Int(nextDate.timeIntervalSince1970))"
        scheduleRingFollowUps(
            alarm: alarm,
            scenario: .alarmRing,
            baseIdentifier: base,
            baseIntervalFromNow: interval,
            offsets: shortRingFollowUpOffsets
        )
    }

    private func stageNotificationSound(named rawName: String, enforceDurationLimit: Bool = false) -> String? {
        guard let sourceURL = resolveBundledSoundURL(for: rawName) else { return nil }
        let ext = sourceURL.pathExtension.lowercased()
        guard notificationSupportedExtensions.contains(ext) else { return nil }
        if enforceDurationLimit, !isValidNotificationSoundDuration(sourceURL) {
            return nil
        }

        let fileManager = FileManager.default
        guard let library = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first else { return nil }
        let soundsDir = library.appendingPathComponent("Sounds", isDirectory: true)

        do {
            try fileManager.createDirectory(at: soundsDir, withIntermediateDirectories: true)
        } catch {
            return nil
        }

        let safeBase = sanitizedFileStem(from: rawName)
        let fileName = "\(safeBase).\(ext)"
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

    private func isValidNotificationSoundDuration(_ sourceURL: URL) -> Bool {
        let asset = AVURLAsset(url: sourceURL)
        let seconds = CMTimeGetSeconds(asset.duration)
        guard seconds.isFinite, seconds > 0 else { return true }
        return seconds <= maxNotificationSoundDuration
    }

    private func resolveBundledSoundURL(for rawName: String) -> URL? {
        let normalized = normalizedSoundKey(rawName)
        let soundsRoot = Bundle.main.bundleURL.appendingPathComponent("sounds", isDirectory: true)
        guard let enumerator = FileManager.default.enumerator(
            at: soundsRoot,
            includingPropertiesForKeys: nil
        ) else { return nil }

        var fallbackMatch: URL?
        for case let fileURL as URL in enumerator {
            let ext = fileURL.pathExtension.lowercased()
            guard !ext.isEmpty else { continue }

            let key = normalizedSoundKey(fileURL.deletingPathExtension().lastPathComponent)
            if key == normalized {
                if notificationSupportedExtensions.contains(ext) {
                    return fileURL
                }
                fallbackMatch = fallbackMatch ?? fileURL
            }
        }
        return fallbackMatch
    }

    private func sanitizedFileStem(from rawName: String) -> String {
        let stem = normalizedSoundKey(rawName)
        return stem.isEmpty ? "alarmo_alarm" : stem
    }

    private func normalizedSoundKey(_ raw: String) -> String {
        let noExt = (raw as NSString).deletingPathExtension
        return noExt
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
    }

    private static func makeShortRingFollowUpOffsets() -> [TimeInterval] {
        // Repeating alarms get a multi-hour chain while preserving global slot budget.
        makeRingFollowUpOffsets(maxCount: 48)
    }

    private static func makeExtendedRingFollowUpOffsets() -> [TimeInterval] {
        // iOS allows ~64 pending local notifications per app.
        // Reserve one for the base alarm and use the rest for follow-ups.
        makeRingFollowUpOffsets(maxCount: 63)
    }

    private static func makeRingFollowUpOffsets(maxCount: Int) -> [TimeInterval] {
        guard maxCount > 0 else { return [] }

        var offsets: [TimeInterval] = []

        func append(_ values: [Int]) {
            for raw in values {
                guard offsets.count < maxCount else { return }
                let value = TimeInterval(raw)
                if offsets.last != value {
                    offsets.append(value)
                }
            }
        }

        // iOS banners cannot be pinned forever by app code. To mimic "always visible",
        // keep re-alerting aggressively while respecting pending request limits.
        append(Array(stride(from: 5, through: 60, by: 5))) // every 5s for first minute
        append(Array(stride(from: 75, through: 10 * 60, by: 15))) // every 15s up to 10m
        append(Array(stride(from: (10 * 60) + 30, through: 30 * 60, by: 30))) // every 30s up to 30m
        append(Array(stride(from: 31 * 60, through: 120 * 60, by: 60))) // every 1m up to 2h
        append(Array(stride(from: 125 * 60, through: 360 * 60, by: 5 * 60))) // every 5m up to 6h

        return offsets
    }
}
