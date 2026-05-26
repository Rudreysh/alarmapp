import Foundation
import os
import UserNotifications

/// New version-aware scheduling API used by `AlarmManagerFacade`.
protocol AlarmScheduler {
    var implementationName: String { get }
    var isSupportedOnCurrentDevice: Bool { get }

    func scheduleAlarm(
        id: UUID,
        title: String,
        date: Date,
        sound: String,
        snoozeEnabled: Bool
    ) async throws

    func cancelAlarm(id: UUID) async
    func rescheduleAlarm(id: UUID, newDate: Date) async throws
    func listScheduledAlarms() async -> [ScheduledAlarmDescriptor]
    func snoozeAlarm(id: UUID, interval: TimeInterval) async throws
    func markAlarmFired(id: UUID) async
}

enum AlarmSchedulerPath: String {
    case alarmKit = "AlarmKit path"
    case legacyNotification = "Legacy notification path"
}

enum AlarmSchedulingError: LocalizedError {
    case notificationsNotAuthorized
    case alarmKitPermissionDenied
    case unsupportedAlarmKit
    case missingScheduledAlarm(UUID)
    case invalidScheduleData
    case schedulingRejected(String)

    var errorDescription: String? {
        switch self {
        case .notificationsNotAuthorized:
            return "Notifications are not authorized."
        case .alarmKitPermissionDenied:
            return "AlarmKit permission was denied."
        case .unsupportedAlarmKit:
            return "AlarmKit is unavailable on this device/runtime."
        case .missingScheduledAlarm(let id):
            return "No scheduled alarm found for \(id.uuidString)."
        case .invalidScheduleData:
            return "Schedule data is invalid."
        case .schedulingRejected(let reason):
            return "Scheduling was rejected: \(reason)"
        }
    }
}

/// Canonical scheduled-alarm descriptor for diagnostics and test tooling.
struct ScheduledAlarmDescriptor: Identifiable, Equatable, Codable {
    let id: UUID
    let title: String
    let fireDate: Date?
    let enabled: Bool
    let soundName: String
    let repeats: Bool
    let snoozeEnabled: Bool
    let backendIdentifier: String
}

/// Persistent record used to reconcile scheduler state on app relaunch.
struct AlarmScheduleRequest: Identifiable, Equatable, Codable {
    let id: UUID
    let title: String
    let fireDate: Date
    let enabled: Bool
    let soundName: String
    let repeats: Bool
    let snoozeEnabled: Bool
}

enum AlarmCustomUIHandoffStore {
    struct PendingRequest: Equatable {
        let sourceAlarmID: String
        let surfaceAlarmID: String
    }

    private struct SurfaceSourceEntry: Codable {
        let sourceAlarmID: String
        let timestamp: TimeInterval
    }

    nonisolated private static let sourceAlarmIDKey = "alarmo.alarmKit.pendingCustomUISourceAlarmId"
    nonisolated private static let surfaceAlarmIDKey = "alarmo.alarmKit.pendingCustomUISurfaceAlarmId"
    nonisolated private static let timestampKey = "alarmo.alarmKit.pendingCustomUITimestamp"
    nonisolated private static let surfaceSourceMapKey = "alarmo.alarmKit.surfaceSourceMap"
    nonisolated private static let maxAge: TimeInterval = 4 * 60 * 60
    nonisolated static let urlScheme = "alarmo"
    nonisolated static let urlHost = "alarm-ringing"

    nonisolated static func request(
        alarmID: UUID,
        surfaceAlarmID: UUID? = nil,
        now: Date = Date()
    ) {
        let sourceID = alarmID.uuidString
        let surfaceID = (surfaceAlarmID ?? alarmID).uuidString
        let nowTimestamp = now.timeIntervalSince1970

        UserDefaults.standard.set(sourceID, forKey: sourceAlarmIDKey)
        UserDefaults.standard.set(surfaceID, forKey: surfaceAlarmIDKey)
        UserDefaults.standard.set(nowTimestamp, forKey: timestampKey)

        var map = loadSurfaceSourceMap()
        map[surfaceID] = SurfaceSourceEntry(sourceAlarmID: sourceID, timestamp: nowTimestamp)
        persistSurfaceSourceMap(map)
    }

    nonisolated static func pendingRequest(now: Date = Date()) -> PendingRequest? {
        guard let sourceAlarmID = UserDefaults.standard.string(forKey: sourceAlarmIDKey) else { return nil }
        let timestamp = UserDefaults.standard.double(forKey: timestampKey)

        guard timestamp > 0, now.timeIntervalSince1970 - timestamp <= maxAge else {
            clear()
            return nil
        }
        let surfaceAlarmID = UserDefaults.standard.string(forKey: surfaceAlarmIDKey) ?? sourceAlarmID
        return PendingRequest(sourceAlarmID: sourceAlarmID, surfaceAlarmID: surfaceAlarmID)
    }

    nonisolated static func pendingAlarmID(now: Date = Date()) -> String? {
        pendingRequest(now: now)?.sourceAlarmID
    }

    nonisolated static func pendingSurfaceAlarmID(now: Date = Date()) -> String? {
        pendingRequest(now: now)?.surfaceAlarmID
    }

    nonisolated static func consumePendingAlarmID(now: Date = Date()) -> String? {
        guard let alarmID = pendingAlarmID(now: now) else { return nil }
        clear()
        return alarmID
    }

    nonisolated static func sourceAlarmID(forSurfaceAlarmID surfaceAlarmID: String) -> String {
        if let pending = pendingRequest(), pending.surfaceAlarmID == surfaceAlarmID {
            return pending.sourceAlarmID
        }
        var map = loadSurfaceSourceMap()
        if let mapped = map[surfaceAlarmID] {
            let age = Date().timeIntervalSince1970 - mapped.timestamp
            if age <= maxAge {
                return mapped.sourceAlarmID
            }
            map[surfaceAlarmID] = nil
            persistSurfaceSourceMap(map)
        }
        return surfaceAlarmID
    }

    nonisolated static func handoffURL(for alarmID: UUID) -> URL {
        var components = URLComponents()
        components.scheme = urlScheme
        components.host = urlHost
        components.queryItems = [
            URLQueryItem(name: "alarmId", value: alarmID.uuidString)
        ]
        return components.url ?? URL(string: "\(urlScheme)://\(urlHost)?alarmId=\(alarmID.uuidString)")!
    }

    nonisolated static func alarmID(from url: URL) -> UUID? {
        guard url.scheme == urlScheme, url.host == urlHost else { return nil }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        guard let rawID = components?.queryItems?.first(where: { $0.name == "alarmId" })?.value else {
            return nil
        }
        return UUID(uuidString: rawID)
    }

    nonisolated static func clear() {
        UserDefaults.standard.removeObject(forKey: sourceAlarmIDKey)
        UserDefaults.standard.removeObject(forKey: surfaceAlarmIDKey)
        UserDefaults.standard.removeObject(forKey: timestampKey)
    }

    nonisolated private static func loadSurfaceSourceMap() -> [String: SurfaceSourceEntry] {
        guard let data = UserDefaults.standard.data(forKey: surfaceSourceMapKey),
              let decoded = try? JSONDecoder().decode([String: SurfaceSourceEntry].self, from: data) else {
            return [:]
        }
        return decoded
    }

    nonisolated private static func persistSurfaceSourceMap(_ map: [String: SurfaceSourceEntry]) {
        guard let data = try? JSONEncoder().encode(map) else { return }
        UserDefaults.standard.set(data, forKey: surfaceSourceMapKey)
    }
}

enum AlarmScheduleMapper {
    static func map(alarm: Alarm, now: Date = Date()) -> AlarmScheduleRequest? {
        guard let fireDate = AlarmStore.nextFireDate(for: alarm, from: now) else { return nil }

        let trimmedTitle = alarm.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return AlarmScheduleRequest(
            id: alarm.id,
            title: trimmedTitle.isEmpty ? "Alarm" : trimmedTitle,
            fireDate: fireDate,
            enabled: alarm.enabled,
            soundName: alarm.soundName,
            repeats: alarm.repeatMask > 0 || alarm.isDaily,
            snoozeEnabled: (alarm.snoozeMinutes > 0 || alarm.snoozeSeconds > 0)
        )
    }
}

struct AlarmSchedulerDiagnostics {
    let iOSVersion: String
    let schedulerPath: AlarmSchedulerPath
    let schedulerImplementation: String
    let alarmKitSupported: Bool
    let notificationAuthorization: UNAuthorizationStatus
    let pendingNotificationIdentifiers: [String]
}

actor AlarmScheduleRequestStore {
    private let fileURL: URL
    private var cache: [UUID: AlarmScheduleRequest] = [:]

    init(fileManager: FileManager = .default, fileURL: URL? = nil) {
        if let explicit = fileURL {
            self.fileURL = explicit
        } else {
            let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let dir = support.appendingPathComponent("ht.alarmo", isDirectory: true)
            if !fileManager.fileExists(atPath: dir.path) {
                try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
            }
            self.fileURL = dir.appendingPathComponent("alarm_schedule_requests.json")
        }
        cache = Self.loadFromDisk(fileURL: self.fileURL)
    }

    func upsert(_ request: AlarmScheduleRequest) {
        cache[request.id] = request
        persist()
    }

    func remove(id: UUID) {
        cache[id] = nil
        persist()
    }

    func request(for id: UUID) -> AlarmScheduleRequest? {
        cache[id]
    }

    func allRequests() -> [AlarmScheduleRequest] {
        cache.values.sorted { $0.fireDate < $1.fireDate }
    }

    func purgeNotIn(_ ids: Set<UUID>) {
        cache = cache.filter { ids.contains($0.key) }
        persist()
    }

    private static func loadFromDisk(fileURL: URL) -> [UUID: AlarmScheduleRequest] {
        guard let data = try? Data(contentsOf: fileURL) else { return [:] }
        guard let decoded = try? JSONDecoder().decode([AlarmScheduleRequest].self, from: data) else { return [:] }
        return Dictionary(uniqueKeysWithValues: decoded.map { ($0.id, $0) })
    }

    private func persist() {
        let values = cache.values.sorted { $0.fireDate < $1.fireDate }
        guard let data = try? JSONEncoder().encode(values) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }
}

final class AlarmManagerFacade: AlarmScheduler, AlarmSchedulerProtocol {
    static let shared = AlarmManagerFacade()

    private let logger = Logger(subsystem: "ht.alarmo", category: "AlarmManagerFacade")

    private let alarmKitScheduler: any AlarmScheduler
    private let legacyScheduler: any AlarmScheduler & AlarmSchedulerProtocol
    private let requestStore: AlarmScheduleRequestStore

    private(set) var selectedPath: AlarmSchedulerPath

    init(
        pathResolver: @escaping () -> AlarmSchedulerPath = { AlarmManagerFacade.defaultPathResolver() },
        alarmKitScheduler: any AlarmScheduler = AlarmSchedulerIOS26AlarmKit(),
        legacyScheduler: any AlarmScheduler & AlarmSchedulerProtocol = AlarmSchedulerLegacyNotification(),
        requestStore: AlarmScheduleRequestStore = AlarmScheduleRequestStore()
    ) {
        self.alarmKitScheduler = alarmKitScheduler
        self.legacyScheduler = legacyScheduler
        self.requestStore = requestStore

        let requested = pathResolver()
        if requested == .alarmKit && alarmKitScheduler.isSupportedOnCurrentDevice {
            self.selectedPath = .alarmKit
        } else {
            if requested == .alarmKit && !alarmKitScheduler.isSupportedOnCurrentDevice {
                logger.warning("AlarmKit requested but unsupported. Falling back to legacy notification scheduler.")
            }
            self.selectedPath = .legacyNotification
            LegacyAlarmModeMessenger.shared.postIfNeeded()
        }
    }

    nonisolated static func defaultPathResolver() -> AlarmSchedulerPath {
        if #available(iOS 26.0, *) {
            return .alarmKit
        }
        return .legacyNotification
    }

    private var activeScheduler: any AlarmScheduler {
        switch selectedPath {
        case .alarmKit:
            return alarmKitScheduler
        case .legacyNotification:
            return legacyScheduler
        }
    }

    var implementationName: String { activeScheduler.implementationName }
    var isSupportedOnCurrentDevice: Bool { activeScheduler.isSupportedOnCurrentDevice }

    // MARK: New AlarmScheduler API

    func scheduleAlarm(
        id: UUID,
        title: String,
        date: Date,
        sound: String,
        snoozeEnabled: Bool
    ) async throws {
        do {
            try await activeScheduler.scheduleAlarm(
                id: id,
                title: title,
                date: date,
                sound: sound,
                snoozeEnabled: snoozeEnabled
            )
        } catch {
            guard selectedPath == .alarmKit else { throw error }
            let message = Self.userFacingAlarmKitFailureMessage(error)
            logger.error("AlarmKit schedule failed for \(id.uuidString, privacy: .public): \(message, privacy: .public)")
            AlarmKitSchedulingMessenger.shared.postIfNeeded(message: message)
            if Self.shouldDowngradeToLegacyPath(after: error) {
                downgradeToLegacyNotificationPath(reason: message)
            }
            do {
                try await legacyScheduler.scheduleAlarm(
                    id: id,
                    title: title,
                    date: date,
                    sound: sound,
                    snoozeEnabled: snoozeEnabled
                )
                logger.warning("Fell back to legacy notification scheduler for \(id.uuidString, privacy: .public)")
            } catch {
                throw error
            }
        }

        let request = AlarmScheduleRequest(
            id: id,
            title: title,
            fireDate: date,
            enabled: true,
            soundName: sound,
            repeats: false,
            snoozeEnabled: snoozeEnabled
        )
        await requestStore.upsert(request)
    }

    func cancelAlarm(id: UUID) async {
        await activeScheduler.cancelAlarm(id: id)
        // Cleanup any old legacy notifications from previous app versions.
        await legacyScheduler.cancelAlarm(id: id)
        await requestStore.remove(id: id)
    }

    func rescheduleAlarm(id: UUID, newDate: Date) async throws {
        guard var existing = await requestStore.request(for: id) else {
            throw AlarmSchedulingError.missingScheduledAlarm(id)
        }

        existing = AlarmScheduleRequest(
            id: existing.id,
            title: existing.title,
            fireDate: newDate,
            enabled: existing.enabled,
            soundName: existing.soundName,
            repeats: existing.repeats,
            snoozeEnabled: existing.snoozeEnabled
        )
        await requestStore.upsert(existing)

        do {
            try await activeScheduler.rescheduleAlarm(id: id, newDate: newDate)
        } catch {
            guard selectedPath == .alarmKit else { throw error }
            let message = Self.userFacingAlarmKitFailureMessage(error)
            logger.error("AlarmKit reschedule failed for \(id.uuidString, privacy: .public): \(message, privacy: .public)")
            AlarmKitSchedulingMessenger.shared.postIfNeeded(message: message)
            if Self.shouldDowngradeToLegacyPath(after: error) {
                downgradeToLegacyNotificationPath(reason: message)
            }
            do {
                try await legacyScheduler.rescheduleAlarm(id: id, newDate: newDate)
                logger.warning("Fell back to legacy notification reschedule for \(id.uuidString, privacy: .public)")
            } catch {
                throw error
            }
        }
    }

    func listScheduledAlarms() async -> [ScheduledAlarmDescriptor] {
        let backend = await activeScheduler.listScheduledAlarms()
        if !backend.isEmpty { return backend }

        let records = await requestStore.allRequests()
        return records.map {
            ScheduledAlarmDescriptor(
                id: $0.id,
                title: $0.title,
                fireDate: $0.fireDate,
                enabled: $0.enabled,
                soundName: $0.soundName,
                repeats: $0.repeats,
                snoozeEnabled: $0.snoozeEnabled,
                backendIdentifier: $0.id.uuidString
            )
        }
    }

    func snoozeAlarm(id: UUID, interval: TimeInterval) async throws {
        do {
            try await activeScheduler.snoozeAlarm(id: id, interval: interval)
        } catch {
            guard selectedPath == .alarmKit else { throw error }
            let message = Self.userFacingAlarmKitFailureMessage(error)
            logger.error("AlarmKit snooze failed for \(id.uuidString, privacy: .public): \(message, privacy: .public)")
            AlarmKitSchedulingMessenger.shared.postIfNeeded(message: message)
            if Self.shouldDowngradeToLegacyPath(after: error) {
                downgradeToLegacyNotificationPath(reason: message)
            }
            do {
                try await legacyScheduler.snoozeAlarm(id: id, interval: interval)
                logger.warning("Fell back to legacy notification snooze for \(id.uuidString, privacy: .public)")
            } catch {
                throw error
            }
        }
    }

    func markAlarmFired(id: UUID) async {
        await activeScheduler.markAlarmFired(id: id)
    }

    // MARK: Existing compatibility API

    /// Schedule an app `Alarm` model using the runtime-selected scheduler path.
    ///
    /// On iOS 26+, this uses AlarmKit as the primary path (system-level alarm behavior on lock screen/silent mode).
    /// If AlarmKit scheduling fails, we fallback to legacy local notifications so users still receive alerts.
    func schedule(alarm: Alarm) {
        Task {
            guard alarm.enabled else {
                await cancelAlarm(id: alarm.id)
                return
            }

            var shouldScheduleLegacy = (selectedPath == .legacyNotification)

            if selectedPath == .alarmKit, let alarmKitScheduler = alarmKitScheduler as? AlarmSchedulerIOS26AlarmKit {
                let granted = await requestAlarmAuthorizationIfNeeded()
                if !granted {
                    logger.error("AlarmKit authorization unavailable for \(alarm.id.uuidString, privacy: .public); using legacy scheduler fallback.")
                    shouldScheduleLegacy = true
                    if Self.shouldDowngradeToLegacyPath(after: AlarmSchedulingError.alarmKitPermissionDenied) {
                        downgradeToLegacyNotificationPath(reason: "AlarmKit authorization unavailable")
                    }
                } else {
                    do {
                        try await alarmKitScheduler.scheduleAppAlarm(alarm)
                        shouldScheduleLegacy = false
                        // Clear stale legacy requests from previous fallback/older builds
                        // so lock-screen behavior is driven by AlarmKit only.
                        await legacyScheduler.cancelAlarm(id: alarm.id)
                        logger.log("AlarmKit schedule succeeded for \(alarm.id.uuidString, privacy: .public)")
                    } catch {
                        let message = Self.userFacingAlarmKitFailureMessage(error)
                        logger.error("AlarmKit app schedule failed for \(alarm.id.uuidString, privacy: .public): \(message, privacy: .public)")
                        AlarmKitSchedulingMessenger.shared.postIfNeeded(message: message)
                        if Self.shouldDowngradeToLegacyPath(after: error) {
                            logger.warning("AlarmKit downgrade engaged for \(alarm.id.uuidString, privacy: .public); using legacy scheduler.")
                            downgradeToLegacyNotificationPath(reason: message)
                            shouldScheduleLegacy = true
                        } else {
                            do {
                                try await alarmKitScheduler.scheduleAppAlarm(alarm)
                                shouldScheduleLegacy = false
                                await legacyScheduler.cancelAlarm(id: alarm.id)
                                logger.log("AlarmKit retry schedule succeeded for \(alarm.id.uuidString, privacy: .public)")
                            } catch {
                                let retryMessage = Self.userFacingAlarmKitFailureMessage(error)
                                logger.error("AlarmKit retry schedule failed for \(alarm.id.uuidString, privacy: .public): \(retryMessage, privacy: .public)")
                                AlarmKitSchedulingMessenger.shared.postIfNeeded(message: retryMessage)
                                // Do not drop the alarm entirely; fallback to legacy notification scheduling.
                                shouldScheduleLegacy = true
                            }
                        }
                    }
                }
            }

            if shouldScheduleLegacy {
                legacyScheduler.schedule(alarm: alarm)
            }

            if let mapped = AlarmScheduleMapper.map(alarm: alarm) {
                await requestStore.upsert(mapped)
            }
        }
    }

    func cancel(alarmId: UUID) {
        Task { await cancelAlarm(id: alarmId) }
    }

    func scheduleSnooze(alarm: Alarm, totalSeconds: Int) {
        Task {
            var shouldScheduleLegacy = (selectedPath == .legacyNotification)
            if selectedPath == .alarmKit {
                do {
                    try await activeScheduler.snoozeAlarm(id: alarm.id, interval: TimeInterval(max(totalSeconds, 1)))
                    shouldScheduleLegacy = false
                    legacyScheduler.cancelRuntimeRingNotifications(for: alarm)
                } catch {
                    let message = Self.userFacingAlarmKitFailureMessage(error)
                    logger.error("AlarmKit snooze failed for \(alarm.id.uuidString, privacy: .public): \(message, privacy: .public)")
                    AlarmKitSchedulingMessenger.shared.postIfNeeded(message: message)
                    if Self.shouldDowngradeToLegacyPath(after: error) {
                        logger.warning("AlarmKit snooze downgrade engaged for \(alarm.id.uuidString, privacy: .public); using legacy scheduler.")
                        downgradeToLegacyNotificationPath(reason: message)
                        shouldScheduleLegacy = true
                    } else {
                        // Never drop snooze scheduling entirely on transient AlarmKit failures.
                        shouldScheduleLegacy = true
                    }
                }
            }
            if shouldScheduleLegacy {
                legacyScheduler.scheduleSnooze(alarm: alarm, totalSeconds: totalSeconds)
            }
        }
    }

    func cancelRuntimeRingNotifications(for alarm: Alarm) {
        Task {
            // Runtime follow-up chains are currently notification-based in app logic.
            legacyScheduler.cancelRuntimeRingNotifications(for: alarm)
        }
    }

    func reconcilePersistedAlarms(_ alarms: [Alarm]) {
        Task {
            await purgeLegacyAlarmNotificationsIfNeeded()
            for alarm in alarms {
                if alarm.enabled {
                    schedule(alarm: alarm)
                } else {
                    await cancelAlarm(id: alarm.id)
                }
            }
            let activeIDs = Set(alarms.filter(\.enabled).map(\.id))
            await requestStore.purgeNotIn(activeIDs)
        }
    }

    private func purgeLegacyAlarmNotificationsIfNeeded() async {
        guard selectedPath == .alarmKit else { return }

        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingRequestsAsync()
        let pendingIDs = pending
            .filter(Self.isLikelyLegacyAlarmNotificationRequest)
            .map(\.identifier)
        if !pendingIDs.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: pendingIDs)
        }

        let delivered = await center.deliveredNotificationsAsync()
        let deliveredIDs = delivered
            .map(\.request)
            .filter(Self.isLikelyLegacyAlarmNotificationRequest)
            .map(\.identifier)
        if !deliveredIDs.isEmpty {
            center.removeDeliveredNotifications(withIdentifiers: deliveredIDs)
        }
    }

    private static func isLikelyLegacyAlarmNotificationRequest(_ request: UNNotificationRequest) -> Bool {
        if request.content.categoryIdentifier == AppNotificationCategory.alarmRing {
            return true
        }
        if request.content.userInfo["alarmId"] as? String != nil {
            return true
        }

        let id = request.identifier
        return id.contains("-once")
            || id.contains("-daily")
            || id.contains("-day-")
            || id.contains("-snooze-")
            || id.contains("-runtime-")
            || id.contains("-followup-")
    }

    func diagnosticsSnapshot() async -> AlarmSchedulerDiagnostics {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        let pending = await UNUserNotificationCenter.current().pendingRequestsAsync()
        return AlarmSchedulerDiagnostics(
            iOSVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            schedulerPath: selectedPath,
            schedulerImplementation: implementationName,
            alarmKitSupported: alarmKitScheduler.isSupportedOnCurrentDevice,
            notificationAuthorization: settings.authorizationStatus,
            pendingNotificationIdentifiers: pending.map(\.identifier).sorted()
        )
    }

    func requestAlarmAuthorizationIfNeeded() async -> Bool {
        guard let alarmKitScheduler = alarmKitScheduler as? AlarmSchedulerIOS26AlarmKit else { return true }
        guard alarmKitScheduler.isSupportedOnCurrentDevice else { return true }
        do {
            let granted = try await alarmKitScheduler.requestAuthorizationIfNeeded()
            if granted, selectedPath != .alarmKit {
                selectedPath = .alarmKit
                logger.log("AlarmKit authorization granted; switching scheduler path back to AlarmKit.")
            }
            return granted
        } catch {
            let message = Self.userFacingAlarmKitFailureMessage(error)
            logger.error("AlarmKit authorization request failed: \(message, privacy: .public)")
            AlarmKitSchedulingMessenger.shared.recordLatestMessage(message)
            if Self.shouldDowngradeToLegacyPath(after: error) {
                downgradeToLegacyNotificationPath(reason: message)
            }
            return false
        }
    }

    private func downgradeToLegacyNotificationPath(reason: String) {
        guard selectedPath == .alarmKit else { return }
        selectedPath = .legacyNotification
        logger.warning("Downgrading scheduler path to legacy notifications for current run. Reason: \(reason, privacy: .public)")
        LegacyAlarmModeMessenger.shared.postIfNeeded()
    }

    private static func shouldDowngradeToLegacyPath(after error: Error) -> Bool {
        let nsError = error as NSError
        // Keep AlarmKit as the primary path even when individual schedule attempts
        // fail, so the app can recover on subsequent retries instead of remaining
        // stuck on legacy notifications for the rest of the run.
        if nsError.domain == "com.apple.AlarmKit.Alarm", nsError.code == 1 {
            return false
        }
        if let schedulingError = error as? AlarmSchedulingError {
            switch schedulingError {
            case .unsupportedAlarmKit:
                return true
            default:
                return false
            }
        }
        return false
    }

    private static func userFacingAlarmKitFailureMessage(_ error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == "com.apple.AlarmKit.Alarm", nsError.code == 1 {
            #if targetEnvironment(simulator)
            return "AlarmKit authorization is unreliable in the iOS simulator. Test alarm authorization and lock-screen ringing on a real iPhone or iPad running iOS 26+."
            #else
            return "Alarm permission request failed. Open Settings > Awayk and enable Alarms, then try again. If the Alarms option is missing, reinstall the app and request permission again on iOS 26+."
            #endif
        }

        if let schedulingError = error as? AlarmSchedulingError {
            switch schedulingError {
            case .alarmKitPermissionDenied:
                return "AlarmKit permission is denied. Enable Alarm permissions for Awayk in Settings and try again."
            case .unsupportedAlarmKit:
                return "AlarmKit is unavailable on this iOS version. Use iOS 26+ for system alarm behavior."
            default:
                return schedulingError.localizedDescription
            }
        }
        return error.localizedDescription
    }

}

final class LegacyAlarmModeMessenger {
    static let shared = LegacyAlarmModeMessenger()

    private let defaults = UserDefaults.standard
    private let noticeKey = "alarmo.legacyAlarmMode.noticeShown"

    private init() {}

    func postIfNeeded() {
        guard !defaults.bool(forKey: noticeKey) else { return }
        defaults.set(true, forKey: noticeKey)
        NotificationCenter.default.post(name: .legacyAlarmModeNoticeRequested, object: nil)
    }

    #if DEBUG
    func resetForDebug() {
        defaults.removeObject(forKey: noticeKey)
    }
    #endif
}

final class AlarmKitSchedulingMessenger {
    static let shared = AlarmKitSchedulingMessenger()

    private let defaults = UserDefaults.standard
    private let noticeKey = "alarmo.alarmKitScheduling.noticeShown"
    private let messageKey = "alarmo.alarmKitScheduling.lastMessage"

    private init() {}

    func postIfNeeded(message: String) {
        defaults.set(message, forKey: messageKey)
        guard !defaults.bool(forKey: noticeKey) else { return }
        defaults.set(true, forKey: noticeKey)
        NotificationCenter.default.post(name: .alarmKitSchedulingFailureNoticeRequested, object: nil)
    }

    func recordLatestMessage(_ message: String) {
        defaults.set(message, forKey: messageKey)
    }

    func latestMessage() -> String {
        defaults.string(forKey: messageKey) ?? "AlarmKit scheduling failed."
    }

    #if DEBUG
    func resetForDebug() {
        defaults.removeObject(forKey: noticeKey)
        defaults.removeObject(forKey: messageKey)
    }
    #endif
}

extension Notification.Name {
    nonisolated static let alarmKitOnlyModeNoticeRequested = Notification.Name("alarmo.alarmKitOnly.noticeRequested")
    nonisolated static let legacyAlarmModeNoticeRequested = Notification.Name("alarmo.legacyAlarmMode.noticeRequested")
    nonisolated static let alarmKitSchedulingFailureNoticeRequested = Notification.Name("alarmo.alarmKitScheduling.failureNoticeRequested")
    nonisolated static let alarmKitCustomUIHandoffRequested = Notification.Name("alarmo.alarmKit.customUIHandoffRequested")
}

extension UNUserNotificationCenter {
    func pendingRequestsAsync() async -> [UNNotificationRequest] {
        await withCheckedContinuation { continuation in
            getPendingNotificationRequests { requests in
                continuation.resume(returning: requests)
            }
        }
    }

    func deliveredNotificationsAsync() async -> [UNNotification] {
        await withCheckedContinuation { continuation in
            getDeliveredNotifications { delivered in
                continuation.resume(returning: delivered)
            }
        }
    }
}

extension AlarmSchedulerLegacyNotification: AlarmScheduler {
    var implementationName: String { "AlarmSchedulerLegacyNotification" }
    var isSupportedOnCurrentDevice: Bool { true }

    func scheduleAlarm(
        id: UUID,
        title: String,
        date: Date,
        sound: String,
        snoozeEnabled: Bool
    ) async throws {
        // Local-notification scheduling is a reminder fallback for pre-iOS-26 devices.
        // On older iOS versions, this path cannot guarantee native Clock-alarm behavior
        // while the phone is locked and in Silent mode.
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard settings.authorizationStatus == .authorized ||
                settings.authorizationStatus == .provisional ||
                settings.authorizationStatus == .ephemeral else {
            throw AlarmSchedulingError.notificationsNotAuthorized
        }

        let alarm = makeTemporaryAlarm(
            id: id,
            title: title,
            date: date,
            sound: sound,
            snoozeEnabled: snoozeEnabled
        )
        schedule(alarm: alarm)
    }

    func cancelAlarm(id: UUID) async {
        cancel(alarmId: id)
    }

    func rescheduleAlarm(id: UUID, newDate: Date) async throws {
        let descriptors = await listScheduledAlarms()
        let existing = descriptors.first(where: { $0.id == id })
        try await scheduleAlarm(
            id: id,
            title: existing?.title ?? "Alarm",
            date: newDate,
            sound: existing?.soundName ?? "cockpitalert",
            snoozeEnabled: existing?.snoozeEnabled ?? true
        )
    }

    func listScheduledAlarms() async -> [ScheduledAlarmDescriptor] {
        let requests = await UNUserNotificationCenter.current().pendingRequestsAsync()
        var byAlarmID: [UUID: ScheduledAlarmDescriptor] = [:]

        for request in requests {
            guard let alarmID = Self.alarmID(from: request) else { continue }

            let fireDate: Date?
            if let cal = request.trigger as? UNCalendarNotificationTrigger {
                fireDate = cal.nextTriggerDate()
            } else if let interval = request.trigger as? UNTimeIntervalNotificationTrigger {
                fireDate = interval.nextTriggerDate()
            } else {
                fireDate = nil
            }

            let descriptor = ScheduledAlarmDescriptor(
                id: alarmID,
                title: request.content.title.nonEmpty ?? "Alarm",
                fireDate: fireDate,
                enabled: true,
                soundName: request.content.sound?.description ?? "default",
                repeats: request.trigger?.repeats ?? false,
                snoozeEnabled: true,
                backendIdentifier: request.identifier
            )

            if let existing = byAlarmID[alarmID] {
                if let lhs = descriptor.fireDate, let rhs = existing.fireDate {
                    if lhs < rhs {
                        byAlarmID[alarmID] = descriptor
                    }
                } else if existing.fireDate == nil {
                    byAlarmID[alarmID] = descriptor
                }
            } else {
                byAlarmID[alarmID] = descriptor
            }
        }

        return byAlarmID.values.sorted { lhs, rhs in
            switch (lhs.fireDate, rhs.fireDate) {
            case let (l?, r?):
                return l < r
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                return lhs.backendIdentifier < rhs.backendIdentifier
            }
        }
    }

    func snoozeAlarm(id: UUID, interval: TimeInterval) async throws {
        let descriptors = await listScheduledAlarms()
        let title = descriptors.first(where: { $0.id == id })?.title ?? "Alarm"
        let sound = descriptors.first(where: { $0.id == id })?.soundName ?? "cockpitalert"
        try await scheduleAlarm(
            id: id,
            title: title,
            date: Date().addingTimeInterval(interval),
            sound: sound,
            snoozeEnabled: true
        )
    }

    func markAlarmFired(id: UUID) async {
        // No-op for notification path.
    }

    private static func alarmID(from request: UNNotificationRequest) -> UUID? {
        if let alarmIdString = request.content.userInfo["alarmId"] as? String,
           let id = UUID(uuidString: alarmIdString) {
            return id
        }

        let identifier = request.identifier
        guard identifier.count >= 36 else { return nil }
        return UUID(uuidString: String(identifier.prefix(36)))
    }

    private func makeTemporaryAlarm(
        id: UUID,
        title: String,
        date: Date,
        sound: String,
        snoozeEnabled: Bool
    ) -> Alarm {
        let components = Calendar.current.dateComponents([.hour, .minute, .second], from: date)
        return Alarm(
            id: id,
            name: title,
            emoji: "⏰",
            hour: components.hour ?? 7,
            minute: components.minute ?? 0,
            second: components.second ?? 0,
            isDaily: false,
            repeatMask: 0,
            enabled: true,
            wakeUpCheckEnabled: false,
            soundName: sound,
            soundVolume: 1,
            vibrateEnabled: true,
            gentleWakeUpSeconds: 0,
            timeReminderEnabled: false,
            weatherReminderEnabled: false,
            labelReminderEnabled: false,
            extraLoudEnabled: false,
            bypassSilentMode: true,
            snoozeMinutes: snoozeEnabled ? 5 : 0,
            snoozeCount: 0,
            wallpaperId: "default",
            createdAt: Date()
        )
    }
}

private extension String {
    var nonEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
