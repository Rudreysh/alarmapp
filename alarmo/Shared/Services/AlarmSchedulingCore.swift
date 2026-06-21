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
    nonisolated private static let uiShellSurfaceIDsKey = "alarmo.alarmKit.uiShellSurfaceIDs"
    /// Surfaces the user consumed via Slide/Open-to-Stop — no longer valid live owners.
    nonisolated private static let consumedBySlideToStopKey = "alarmo.alarmKit.consumedBySlideToStop"
    nonisolated private static let lastSlideToStopAtBySourceKey = "alarmo.alarmKit.lastSlideToStopAtBySource"
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

        // Hard 24h ceiling only. Short TTLs are forbidden here: a healthy locked
        // alarm may never refresh this timestamp (the engineLiveHealthy path in
        // processAlarmKitAlertingAlarm skips request()), and a <=10min cap
        // reintroduced the multi-snooze silence bug. We also reject future-dated
        // timestamps from a device clock change, which would otherwise keep stale
        // state alive forever.
        guard timestamp > 0 else {
            clear()
            return nil
        }
        let age = now.timeIntervalSince1970 - timestamp
        guard age >= 0, age < 24 * 60 * 60 else {
            print("[AlarmHandoffStore] cleared pending reason=\(age < 0 ? "future-timestamp" : "hard-expiry") ageSeconds=\(Int(age))")
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

    /// Surfaces scheduled with silent AlarmKit audio so the lock-screen UI (slide-to-stop
    /// + snooze) is visible while the app engine owns audible output.
    nonisolated static func markUIShellSurface(_ surfaceAlarmID: String) {
        var ids = Set(UserDefaults.standard.stringArray(forKey: uiShellSurfaceIDsKey) ?? [])
        ids.insert(surfaceAlarmID)
        UserDefaults.standard.set(Array(ids), forKey: uiShellSurfaceIDsKey)
    }

    nonisolated static func isUIShellSurface(_ surfaceAlarmID: String) -> Bool {
        Set(UserDefaults.standard.stringArray(forKey: uiShellSurfaceIDsKey) ?? []).contains(surfaceAlarmID)
    }

    nonisolated static func removeUIShellSurface(_ surfaceAlarmID: String) {
        var ids = Set(UserDefaults.standard.stringArray(forKey: uiShellSurfaceIDsKey) ?? [])
        ids.remove(surfaceAlarmID)
        UserDefaults.standard.set(Array(ids), forKey: uiShellSurfaceIDsKey)
    }

    nonisolated static func clearUIShellSurfaces() {
        UserDefaults.standard.removeObject(forKey: uiShellSurfaceIDsKey)
    }

    nonisolated static func markSurfaceConsumedBySlideToStop(
        sourceAlarmId: String,
        surfaceAlarmId: String,
        now: Date = Date()
    ) {
        var consumed = Set(UserDefaults.standard.stringArray(forKey: consumedBySlideToStopKey) ?? [])
        consumed.insert(surfaceAlarmId)
        UserDefaults.standard.set(Array(consumed), forKey: consumedBySlideToStopKey)

        var lastAt = loadLastSlideToStopAtBySource()
        lastAt[sourceAlarmId] = now.timeIntervalSince1970
        persistLastSlideToStopAtBySource(lastAt)
        print("[SlideToStop] surface consumed source=\(sourceAlarmId) surface=\(surfaceAlarmId)")
    }

    nonisolated static func isSurfaceConsumedBySlideToStop(_ surfaceAlarmId: String) -> Bool {
        Set(UserDefaults.standard.stringArray(forKey: consumedBySlideToStopKey) ?? [])
            .contains(surfaceAlarmId)
    }

    nonisolated static func lastSlideToStopAt(for sourceAlarmId: String) -> Date? {
        let map = loadLastSlideToStopAtBySource()
        guard let ts = map[sourceAlarmId], ts > 0 else { return nil }
        return Date(timeIntervalSince1970: ts)
    }

    nonisolated static func clearConsumedSurfaces(reason: String) {
        UserDefaults.standard.removeObject(forKey: consumedBySlideToStopKey)
        UserDefaults.standard.removeObject(forKey: lastSlideToStopAtBySourceKey)
        print("[SlideToStop] cleared consumed surfaces reason=\(reason)")
    }

    // MARK: - Schedule-time locked continuity guard (survives force-close)

    nonisolated private static let lockedContinuityGuardKey = "alarmo.alarmKit.lockedContinuityGuard"

    nonisolated static func recordLockedContinuityGuard(sourceAlarmId: String, surfaceIds: [UUID]) {
        var map = loadLockedContinuityGuardMap()
        map[sourceAlarmId] = surfaceIds.map(\.uuidString)
        persistLockedContinuityGuardMap(map)
        print("[ContinuityGuard] recorded \(surfaceIds.count) surfaces source=\(sourceAlarmId)")
    }

    nonisolated static func lockedContinuityGuardSurfaceIds(sourceAlarmId: String) -> [UUID] {
        let map = loadLockedContinuityGuardMap()
        return (map[sourceAlarmId] ?? []).compactMap(UUID.init(uuidString:))
    }

    nonisolated static func allLockedContinuityGuardSurfaceIds() -> [UUID] {
        let map = loadLockedContinuityGuardMap()
        return map.values
            .flatMap { $0 }
            .compactMap(UUID.init(uuidString:))
    }

    nonisolated static func clearLockedContinuityGuard(sourceAlarmId: String, reason: String) {
        var map = loadLockedContinuityGuardMap()
        map.removeValue(forKey: sourceAlarmId)
        persistLockedContinuityGuardMap(map)
        print("[ContinuityGuard] cleared source=\(sourceAlarmId) reason=\(reason)")
    }

    nonisolated static func clearAllLockedContinuityGuards(reason: String) {
        UserDefaults.standard.removeObject(forKey: lockedContinuityGuardKey)
        print("[ContinuityGuard] cleared all reason=\(reason)")
    }

    nonisolated private static func loadLockedContinuityGuardMap() -> [String: [String]] {
        guard let data = UserDefaults.standard.data(forKey: lockedContinuityGuardKey),
              let decoded = try? JSONDecoder().decode([String: [String]].self, from: data) else {
            return [:]
        }
        return decoded
    }

    nonisolated private static func persistLockedContinuityGuardMap(_ map: [String: [String]]) {
        if let data = try? JSONEncoder().encode(map) {
            UserDefaults.standard.set(data, forKey: lockedContinuityGuardKey)
        }
    }

    nonisolated private static func loadLastSlideToStopAtBySource() -> [String: TimeInterval] {
        guard let data = UserDefaults.standard.data(forKey: lastSlideToStopAtBySourceKey),
              let decoded = try? JSONDecoder().decode([String: TimeInterval].self, from: data) else {
            return [:]
        }
        return decoded
    }

    nonisolated private static func persistLastSlideToStopAtBySource(_ map: [String: TimeInterval]) {
        if let data = try? JSONEncoder().encode(map) {
            UserDefaults.standard.set(data, forKey: lastSlideToStopAtBySourceKey)
        }
    }

    nonisolated static func sourceAlarmID(forSurfaceAlarmID surfaceAlarmID: String) -> String {
        if let pending = pendingRequest(), pending.surfaceAlarmID == surfaceAlarmID {
            return pending.sourceAlarmID
        }
        let map = loadSurfaceSourceMap()
        if let mapped = map[surfaceAlarmID] {
            // Lifecycle-based: the mapping is valid as long as it exists. Removing
            // the time-based expiry fixes surface→source resolution on later
            // snoozes (e.g. two 9-min snoozes exceeded the old 10-min cap, the
            // lookup fell back to the surface UUID, the source alarm was not found,
            // and the engine never started → silent alarm).
            return mapped.sourceAlarmID
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
        clearUIShellSurfaces()
    }

    // Compatibility helper expected by newer app bootstrap code.
    nonisolated static func pruneOrphanedMappings(now: Date = Date()) {
        // Called at app init (before the live alarm store is available), so a
        // lifecycle check is not possible here. Use a generous 48h safety net to
        // drop only genuinely abandoned mappings; valid same-day/overnight snooze
        // mappings are preserved. The old 10-min cap silenced repeated snoozes.
        let safetyNetAge: TimeInterval = 48 * 60 * 60
        let cutoff = now.timeIntervalSince1970 - safetyNetAge
        var map = loadSurfaceSourceMap()
        let before = map.count
        map = map.filter { $0.value.timestamp >= cutoff }
        if map.count != before {
            persistSurfaceSourceMap(map)
        }

        if let pendingTimestamp = UserDefaults.standard.object(forKey: timestampKey) as? TimeInterval,
           pendingTimestamp < cutoff {
            clear()
        }
    }

    /// Store-aware cleanup run once at startup (from `NotificationManager.configure`)
    /// after the live `AlarmStore` is available — something `pruneOrphanedMappings()`
    /// cannot do because it runs pre-AlarmStore at app init. Removes stale handoff
    /// state that would otherwise ghost-start a ring via
    /// `AppRootView.handlePendingCustomAlarmUIHandoff` on a normal foreground launch.
    nonisolated static func pruneWithAlarmStore(
        _ alarmStore: AlarmStore,
        now: Date = Date(),
        runtimeIsActive: Bool = false,
        appIsForeground: Bool = false
    ) {
        if AlarmAuthHandoffStore.shouldPreserveHandoffDuringPrune(
            runtimeIsActive: runtimeIsActive,
            appIsForeground: appIsForeground,
            now: now
        ) {
            print("[AlarmHandoffStore] prune skipped — auth handoff must be preserved")
            return
        }

        let nowTs = now.timeIntervalSince1970

        // --- Pending scalar keys ---
        if let sourceStr = UserDefaults.standard.string(forKey: sourceAlarmIDKey) {
            let ts = UserDefaults.standard.double(forKey: timestampKey)
            let age = nowTs - ts
            let sourceExists = UUID(uuidString: sourceStr).flatMap { alarmStore.alarm(by: $0) } != nil

            let reason: String?
            if ts <= 0 { reason = "invalid-timestamp" }
            else if age < 0 { reason = "future-timestamp" }
            else if age >= 24 * 60 * 60 { reason = "hard-expiry" }
            else if !sourceExists && age >= 30 * 60 { reason = "missing-source" }
            // Aggressive case: stale pending for a still-existing (recurring) alarm.
            // Safety = NOT runtime-active AND a normal foreground launch (never the
            // .background alarm-recovery launch). No map-presence requirement — that
            // would leave the ghost bug unfixed when the map entry is missing.
            // Threshold is 6h, not 60m: the "Alarmo persists until reinstall" state is
            // hours/days old, while a genuine same-night alarm can ring 1-3h with
            // runtimeIsActive still false at configure() time (observation/recovery
            // run AFTER configure). 6h fixes the stale-state bug without risking a
            // real long-ringing alarm. missing-source stays at 30m because a deleted
            // alarm can never be a live source.
            else if sourceExists && age >= 6 * 60 * 60 && !runtimeIsActive && appIsForeground {
                reason = "inactive-existing-source"
            } else { reason = nil }

            if let reason {
                print("[AlarmHandoffStore] cleared pending reason=\(reason) ageSeconds=\(Int(age))")
                clear()
            }
        }

        // --- Surface map ---
        var map = loadSurfaceSourceMap()
        let before = map.count
        map = map.filter { _, entry in
            let age = nowTs - entry.timestamp
            if age < 0 { return false }                 // future-dated → remove
            if age < 60 * 60 { return true }            // keep recent unconditionally (active/snooze)
            if age >= 48 * 60 * 60 { return false }     // 48h safety net
            return UUID(uuidString: entry.sourceAlarmID).flatMap { alarmStore.alarm(by: $0) } != nil
        }
        if map.count != before {
            print("[AlarmHandoffStore] pruned surface mappings removed=\(before - map.count) remaining=\(map.count)")
            persistSurfaceSourceMap(map)
        }
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

/// Persisted runtime state for slide-to-stop / Open-to-Stop → authentication → custom UI.
/// Survives process death so failed auth and manual app-open can restore the alarm flow.
enum AlarmAuthHandoffStore {
    enum RuntimeAlarmState: String {
        case ringing
        case stopped
        case snoozed
    }

    /// Which user-initiated path requested the open-to-stop handoff. Lets
    /// downstream restore code know whether a handoff originated from an
    /// AlarmKit slide-to-stop, the "Unlock to Stop" notification action, or a
    /// recovery-prompt tap. Diagnostic only — never used to mark final stop.
    enum HandoffSource: String {
        case alarmKitOpenToStop
        case unlockToStopNotification
        case recoveryPromptTap
    }

    private static let activeRingingAlarmIdKey = "alarmo.authHandoff.activeRingingAlarmId"
    private static let activeRunIdKey = "alarmo.authHandoff.activeRunId"
    private static let surfaceAlarmIdKey = "alarmo.authHandoff.surfaceAlarmId"
    private static let alarmStateKey = "alarmo.authHandoff.alarmState"
    private static let pendingCustomUIHandoffKey = "alarmo.authHandoff.pendingCustomUIHandoff"
    private static let handoffRequestedAtKey = "alarmo.authHandoff.handoffRequestedAt"
    private static let handoffSourceKey = "alarmo.authHandoff.handoffSource"
    private static let handoffReasonKey = "alarmo.authHandoff.handoffReason"
    private static let waitingForAuthenticationKey = "alarmo.authHandoff.waitingForAuthentication"
    private static let finalStopOrSnoozePressedKey = "alarmo.authHandoff.finalStopOrSnoozePressed"
    private static let missionCompletedKey = "alarmo.authHandoff.missionCompleted"
    private static let authRecoveryPendingKey = "alarmo.authHandoff.authRecoveryPending"
    private static let ringSessionSnoozeAlarmIdKey = "alarmo.authHandoff.ringSessionSnoozeAlarmId"
    private static let ringSessionSnoozeCountKey = "alarmo.authHandoff.ringSessionSnoozeCount"

    static let handoffHardExpiry: TimeInterval = 24 * 60 * 60

    /// Shared persistence for every user-initiated "open to stop" handoff path
    /// (AlarmKit slide-to-stop / Open-to-Stop, the blue "Unlock to Stop"
    /// notification action, and the recovery-prompt tap). This NEVER marks the
    /// alarm as finally stopped — it only records that the alarm is still
    /// ringing and that the app should foreground into the custom UI. The real
    /// final stop happens only from Stop/Snooze inside AlarmRingingView (or
    /// mission-complete).
    ///
    /// Writes:
    /// - activeRingingAlarmId, activeRunId
    /// - alarmState = ringing
    /// - pendingCustomAlarmUIHandoff = true
    /// - waitingForAuthentication = true
    /// - handoffRequestedAt = now
    /// - finalStopOrSnoozePressed = false
    /// - handoffSource = <source>
    nonisolated static func persistOpenToStopHandoff(
        sourceAlarmId: String,
        surfaceAlarmId: String? = nil,
        runId: String? = nil,
        handoffSource: HandoffSource,
        reason: String,
        now: Date = Date()
    ) {
        UserDefaults.standard.set(sourceAlarmId, forKey: activeRingingAlarmIdKey)
        if let runId {
            UserDefaults.standard.set(runId, forKey: activeRunIdKey)
        }
        if let surfaceAlarmId {
            UserDefaults.standard.set(surfaceAlarmId, forKey: surfaceAlarmIdKey)
        }
        UserDefaults.standard.set(RuntimeAlarmState.ringing.rawValue, forKey: alarmStateKey)
        UserDefaults.standard.set(true, forKey: pendingCustomUIHandoffKey)
        UserDefaults.standard.set(now.timeIntervalSince1970, forKey: handoffRequestedAtKey)
        UserDefaults.standard.set(true, forKey: waitingForAuthenticationKey)
        UserDefaults.standard.set(false, forKey: finalStopOrSnoozePressedKey)
        UserDefaults.standard.set(false, forKey: authRecoveryPendingKey)
        UserDefaults.standard.set(handoffSource.rawValue, forKey: handoffSourceKey)
        UserDefaults.standard.set(reason, forKey: handoffReasonKey)

        let hasIncompleteMission: Bool = {
            guard let uuid = UUID(uuidString: sourceAlarmId),
                  let alarm = AlarmStore.shared.alarm(by: uuid) else { return false }
            return alarm.missions.contains(where: { $0.type != .off })
        }()
        UserDefaults.standard.set(!hasIncompleteMission, forKey: missionCompletedKey)

        print("[HandoffStore] persisted open-to-stop handoff source=\(sourceAlarmId) runId=\(runId ?? "nil") reason=\(reason)")
        print("[FinalStop] SET false reason=open-to-stop-handoff source=\(sourceAlarmId)")
    }

    nonisolated static func activeRunId() -> String? {
        UserDefaults.standard.string(forKey: activeRunIdKey)
    }

    nonisolated static func handoffSource() -> HandoffSource? {
        guard let raw = UserDefaults.standard.string(forKey: handoffSourceKey) else { return nil }
        return HandoffSource(rawValue: raw)
    }

    nonisolated static func handoffReason() -> String? {
        UserDefaults.standard.string(forKey: handoffReasonKey)
    }

    nonisolated static func persistStopIntentHandoff(
        sourceAlarmId: UUID,
        surfaceAlarmId: UUID,
        runId: String? = nil,
        handoffSource: HandoffSource = .alarmKitOpenToStop,
        now: Date = Date()
    ) {
        let source = sourceAlarmId.uuidString
        let surface = surfaceAlarmId.uuidString
        print("[AuthHandoff] StopIntent invoked source=\(source)")

        // Core state write shared by all open-to-stop paths.
        persistOpenToStopHandoff(
            sourceAlarmId: source,
            surfaceAlarmId: surface,
            runId: runId,
            handoffSource: handoffSource,
            reason: "stop-intent",
            now: now
        )

        AlarmCustomUIHandoffStore.request(alarmID: sourceAlarmId, surfaceAlarmID: surfaceAlarmId, now: now)
        AlarmCustomUIHandoffStore.markSurfaceConsumedBySlideToStop(
            sourceAlarmId: source,
            surfaceAlarmId: surface,
            now: now
        )
        print("[AuthHandoff] persisted pending handoff before authentication source=\(source)")
        print("[AuthHandoff] finalStop=false; waiting for app unlock source=\(source)")
        print("[AuthHandoff] final stop NOT set because app handoff is pending source=\(source)")

        // Pre-arm AlarmKit recovery (auth-timeout / not-unlocked fallback) so the
        // alarm re-alerts audibly if the user never authenticates or opens the app.
        NotificationManager.shared.scheduleAuthHandoffTimeout(sourceAlarmId: source)
        NotificationManager.shared.recordHardwareSuppressionEvent(sourceAlarmId: source)
    }

    /// Establishes a clean "ringing" handoff state when a NEW alarm ring session
    /// begins. CRITICAL: resets `finalStopOrSnoozePressed` to false — otherwise a
    /// repeating alarm inherits the stale `true` left by the previous Stop, which
    /// poisons every recovery path (engine takeover, AlarmKit re-alert, app-open
    /// restore all bail on `isFinalStopOrSnoozePressed()`), leaving the alarm
    /// audibly dead. Idempotent for the same source: only resets the final-stop
    /// flag if it was set, so it won't clobber a live auth handoff.
    /// Keeps recovery / continuity surfaces in a ringing session without resetting
    /// slide-to-stop consumed-surface tracking.
    nonisolated static func ensureRingingForRecovery(sourceAlarmId: String) {
        guard alarmState() != .ringing else { return }
        UserDefaults.standard.set(sourceAlarmId, forKey: activeRingingAlarmIdKey)
        UserDefaults.standard.set(RuntimeAlarmState.ringing.rawValue, forKey: alarmStateKey)
        UserDefaults.standard.set(false, forKey: finalStopOrSnoozePressedKey)
        print("[AuthHandoff] ensureRingingForRecovery source=\(sourceAlarmId)")
    }

    nonisolated static func markRingingStarted(sourceAlarmId: String, now: Date = Date()) {
        let wasFinalStop = UserDefaults.standard.bool(forKey: finalStopOrSnoozePressedKey)
        let priorSource = UserDefaults.standard.string(forKey: activeRingingAlarmIdKey)
        // Preserve an in-flight auth handoff for the SAME alarm (slide-to-stop
        // waiting for unlock) — that path manages its own state and must not be
        // reset out from under itself.
        if priorSource == sourceAlarmId,
           UserDefaults.standard.bool(forKey: waitingForAuthenticationKey),
           !wasFinalStop {
            print("[FinalStop] preserving live auth handoff; not re-initializing ringing state source=\(sourceAlarmId)")
            return
        }
        let wasSnoozed = alarmState(now: now) == .snoozed
        if !wasSnoozed {
            resetRingSessionSnoozeCount(sourceAlarmId: sourceAlarmId)
        }
        if wasFinalStop {
            print("[FinalStop] SET false reason=new-ring-session source=\(sourceAlarmId) (was true from previous stop/snooze)")
        }
        UserDefaults.standard.set(sourceAlarmId, forKey: activeRingingAlarmIdKey)
        UserDefaults.standard.set(RuntimeAlarmState.ringing.rawValue, forKey: alarmStateKey)
        UserDefaults.standard.set(now.timeIntervalSince1970, forKey: handoffRequestedAtKey)
        UserDefaults.standard.set(false, forKey: finalStopOrSnoozePressedKey)
        UserDefaults.standard.set(false, forKey: waitingForAuthenticationKey)
        UserDefaults.standard.set(false, forKey: authRecoveryPendingKey)
        UserDefaults.standard.set(false, forKey: pendingCustomUIHandoffKey)
        let hasIncompleteMission: Bool = {
            guard let uuid = UUID(uuidString: sourceAlarmId),
                  let alarm = AlarmStore.shared.alarm(by: uuid) else { return false }
            return alarm.missions.contains(where: { $0.type != .off })
        }()
        UserDefaults.standard.set(!hasIncompleteMission, forKey: missionCompletedKey)
        AlarmCustomUIHandoffStore.clearConsumedSurfaces(reason: "new-ring-session")
        print("[AuthHandoff] ringing state initialized source=\(sourceAlarmId) finalStop=false state=ringing")
    }

    nonisolated static func surfaceAlarmId() -> String? {
        UserDefaults.standard.string(forKey: surfaceAlarmIdKey)
    }

    nonisolated static func updateSurfaceAlarmId(_ surfaceAlarmId: UUID) {
        UserDefaults.standard.set(surfaceAlarmId.uuidString, forKey: surfaceAlarmIdKey)
    }

    nonisolated static func alarmState(now: Date = Date()) -> RuntimeAlarmState? {
        guard let raw = UserDefaults.standard.string(forKey: alarmStateKey) else { return nil }
        guard !isHandoffExpired(now: now) else { return nil }
        return RuntimeAlarmState(rawValue: raw)
    }

    nonisolated static func isPendingCustomUIHandoff() -> Bool {
        UserDefaults.standard.bool(forKey: pendingCustomUIHandoffKey)
    }

    nonisolated static func isWaitingForAuthentication() -> Bool {
        UserDefaults.standard.bool(forKey: waitingForAuthenticationKey)
    }

    nonisolated static func isFinalStopOrSnoozePressed() -> Bool {
        UserDefaults.standard.bool(forKey: finalStopOrSnoozePressedKey)
    }

    // MARK: - App heartbeat (force-close / aliveness detection)

    private static let heartbeatAtKey = "alarmo.heartbeat.lastTimestamp"
    private static let heartbeatRunIdKey = "alarmo.heartbeat.runId"
    private static let heartbeatPlayingKey = "alarmo.heartbeat.isPlaying"

    /// Heartbeats older than this are treated as "app likely not alive enough".
    static let heartbeatStaleThreshold: TimeInterval = 90

    nonisolated private static func heartbeatDefaults() -> UserDefaults {
        UserDefaults(suiteName: "group.ht.alarmo") ?? .standard
    }

    /// Writes a liveness heartbeat. Call frequently (every ~30–60s, faster while an
    /// alarm is upcoming/active) so recovery code can tell whether the app is alive.
    nonisolated static func writeHeartbeat(runId: String?, isPlaying: Bool, now: Date = Date()) {
        let defaults = heartbeatDefaults()
        defaults.set(now.timeIntervalSince1970, forKey: heartbeatAtKey)
        defaults.set(runId, forKey: heartbeatRunIdKey)
        defaults.set(isPlaying, forKey: heartbeatPlayingKey)
    }

    nonisolated static func lastHeartbeatAt() -> Date? {
        let ts = heartbeatDefaults().double(forKey: heartbeatAtKey)
        return ts > 0 ? Date(timeIntervalSince1970: ts) : nil
    }

    /// True when no fresh heartbeat exists (app likely force-closed or suspended
    /// long enough that the AppEngine cannot be trusted to ring).
    nonisolated static func isHeartbeatStale(now: Date = Date()) -> Bool {
        guard let last = lastHeartbeatAt() else { return true }
        return now.timeIntervalSince(last) > heartbeatStaleThreshold
    }

    nonisolated static func isMissionCompleted() -> Bool {
        UserDefaults.standard.bool(forKey: missionCompletedKey)
    }

    nonisolated static func isAuthRecoveryPending() -> Bool {
        UserDefaults.standard.bool(forKey: authRecoveryPendingKey)
    }

    nonisolated static func setAuthRecoveryPending(_ pending: Bool) {
        UserDefaults.standard.set(pending, forKey: authRecoveryPendingKey)
    }

    nonisolated static func setMissionCompleted(_ completed: Bool) {
        UserDefaults.standard.set(completed, forKey: missionCompletedKey)
    }

    nonisolated static func activeRingingAlarmId(now: Date = Date()) -> String? {
        guard !isFinalStopOrSnoozePressed() else { return nil }
        guard alarmState(now: now) == .ringing else { return nil }
        guard let source = UserDefaults.standard.string(forKey: activeRingingAlarmIdKey) else { return nil }
        guard !isHandoffExpired(now: now) else {
            clear(reason: "hard-expiry")
            return nil
        }
        return source
    }

    /// True only when a genuine active ring session should restore the full-screen UI.
    /// A lingering `activeRingingAlarmId` from a previous session, or a future-alarm
    /// readiness notification tap, must NOT satisfy this check.
    nonisolated static func isActivelyRinging(now: Date = Date()) -> Bool {
        guard activeRingingAlarmId(now: now) != nil else { return false }
        guard alarmState(now: now) == .ringing else { return false }
        guard !isFinalStopOrSnoozePressed() else { return false }
        return true
    }

    nonisolated static func shouldRestoreOnAppOpen(now: Date = Date()) -> Bool {
        isActivelyRinging(now: now)
    }

    nonisolated static func shouldPreserveHandoffDuringPrune(
        runtimeIsActive: Bool,
        appIsForeground: Bool,
        now: Date = Date()
    ) -> Bool {
        if shouldRestoreOnAppOpen(now: now) { return true }
        if isWaitingForAuthentication() { return true }
        if isAuthRecoveryPending() { return true }
        if isPendingCustomUIHandoff(), !isFinalStopOrSnoozePressed() { return true }
        _ = runtimeIsActive
        _ = appIsForeground
        return false
    }

    nonisolated static func markAppBecameActive(now: Date = Date()) {
        guard let source = UserDefaults.standard.string(forKey: activeRingingAlarmIdKey) else { return }
        UserDefaults.standard.set(false, forKey: waitingForAuthenticationKey)
        UserDefaults.standard.set(false, forKey: authRecoveryPendingKey)
        NotificationManager.shared.cancelAuthHandoffTimeout(sourceAlarmId: source)
        NotificationManager.shared.cancelPendingAuthRecovery(sourceAlarmId: source)
        _ = now
    }

    nonisolated static func ringSessionSnoozeCount(for sourceAlarmId: String) -> Int {
        guard UserDefaults.standard.string(forKey: ringSessionSnoozeAlarmIdKey) == sourceAlarmId else {
            return 0
        }
        return max(0, UserDefaults.standard.integer(forKey: ringSessionSnoozeCountKey))
    }

    @discardableResult
    nonisolated static func recordRingSessionSnooze(sourceAlarmId: String) -> Int {
        let prior = ringSessionSnoozeCount(for: sourceAlarmId)
        let next = prior + 1
        UserDefaults.standard.set(sourceAlarmId, forKey: ringSessionSnoozeAlarmIdKey)
        UserDefaults.standard.set(next, forKey: ringSessionSnoozeCountKey)
        return next
    }

    nonisolated static func syncRingSessionSnoozeCount(sourceAlarmId: String, count: Int) {
        UserDefaults.standard.set(sourceAlarmId, forKey: ringSessionSnoozeAlarmIdKey)
        UserDefaults.standard.set(max(0, count), forKey: ringSessionSnoozeCountKey)
    }

    nonisolated static func resetRingSessionSnoozeCount(sourceAlarmId: String? = nil) {
        if let sourceAlarmId,
           UserDefaults.standard.string(forKey: ringSessionSnoozeAlarmIdKey) != sourceAlarmId {
            return
        }
        UserDefaults.standard.removeObject(forKey: ringSessionSnoozeAlarmIdKey)
        UserDefaults.standard.removeObject(forKey: ringSessionSnoozeCountKey)
    }

    nonisolated static func clearOnFinalStop(preserveSnooze: Bool = false, reason: String = "final-stop") {
        if let source = UserDefaults.standard.string(forKey: activeRingingAlarmIdKey) {
            print("[AuthHandoff] final stop/snooze completed; cleared handoff state source=\(source) reason=\(reason)")
            print("[FinalStop] cleared active ringing state source=\(source)")
            NotificationManager.shared.cancelAllHardwareRecoveryState(sourceAlarmId: source)
            AlarmCustomUIHandoffStore.clearConsumedSurfaces(reason: reason)
        }
        if !preserveSnooze {
            resetRingSessionSnoozeCount()
        }
        print("[FinalStop] SET true reason=\(reason)")
        UserDefaults.standard.set(true, forKey: finalStopOrSnoozePressedKey)
        if preserveSnooze {
            UserDefaults.standard.set(RuntimeAlarmState.snoozed.rawValue, forKey: alarmStateKey)
        } else {
            UserDefaults.standard.set(RuntimeAlarmState.stopped.rawValue, forKey: alarmStateKey)
        }
        UserDefaults.standard.set(false, forKey: pendingCustomUIHandoffKey)
        UserDefaults.standard.set(false, forKey: waitingForAuthenticationKey)
        UserDefaults.standard.set(false, forKey: authRecoveryPendingKey)
        UserDefaults.standard.removeObject(forKey: activeRingingAlarmIdKey)
        UserDefaults.standard.removeObject(forKey: activeRunIdKey)
        UserDefaults.standard.removeObject(forKey: surfaceAlarmIdKey)
        UserDefaults.standard.removeObject(forKey: handoffRequestedAtKey)
        UserDefaults.standard.removeObject(forKey: handoffSourceKey)
        UserDefaults.standard.removeObject(forKey: handoffReasonKey)
    }

    nonisolated static func clear(reason: String) {
        if let source = UserDefaults.standard.string(forKey: activeRingingAlarmIdKey) {
            NotificationManager.shared.cancelAuthHandoffTimeout(sourceAlarmId: source)
            NotificationManager.shared.cancelPendingAuthRecovery(sourceAlarmId: source)
            print("[AuthHandoff] cleared handoff state source=\(source) reason=\(reason)")
        }
        UserDefaults.standard.removeObject(forKey: activeRingingAlarmIdKey)
        UserDefaults.standard.removeObject(forKey: activeRunIdKey)
        UserDefaults.standard.removeObject(forKey: surfaceAlarmIdKey)
        UserDefaults.standard.removeObject(forKey: alarmStateKey)
        UserDefaults.standard.removeObject(forKey: pendingCustomUIHandoffKey)
        UserDefaults.standard.removeObject(forKey: handoffRequestedAtKey)
        UserDefaults.standard.removeObject(forKey: handoffSourceKey)
        UserDefaults.standard.removeObject(forKey: handoffReasonKey)
        UserDefaults.standard.removeObject(forKey: waitingForAuthenticationKey)
        UserDefaults.standard.removeObject(forKey: finalStopOrSnoozePressedKey)
        UserDefaults.standard.removeObject(forKey: missionCompletedKey)
        UserDefaults.standard.removeObject(forKey: authRecoveryPendingKey)
        resetRingSessionSnoozeCount()
    }

    nonisolated private static func isHandoffExpired(now: Date) -> Bool {
        let ts = UserDefaults.standard.double(forKey: handoffRequestedAtKey)
        guard ts > 0 else { return true }
        let age = now.timeIntervalSince1970 - ts
        return age < 0 || age >= handoffHardExpiry
    }
}

/// Distinguishes AlarmKit ringer surfaces from custom local notifications and internal tracking.
enum AlarmSurfaceKind: String {
    case audibleAlarmKit
    case silentAlarmKitShell
    case customControlNotification
    case internalTrackedOnly
    case none
}

struct AlarmSurfaceStatus: Equatable {
    let kind: AlarmSurfaceKind
    let exists: Bool
    /// True only when the surface is a trusted audible owner (not suppression-risk, not control-only).
    let trustedAsAudible: Bool
    let sourceAlarmId: String
    let runId: String?

    static func none(sourceAlarmId: String) -> AlarmSurfaceStatus {
        AlarmSurfaceStatus(
            kind: .none,
            exists: false,
            trustedAsAudible: false,
            sourceAlarmId: sourceAlarmId,
            runId: nil
        )
    }
}

enum AlarmSurfacePolicy {
    /// Only a trusted audible AlarmKit alerting surface may suppress audible recovery.
    static func canSurfaceSuppressAudibleRecovery(_ status: AlarmSurfaceStatus) -> Bool {
        switch status.kind {
        case .audibleAlarmKit:
            return status.exists && status.trustedAsAudible
        case .silentAlarmKitShell, .customControlNotification, .internalTrackedOnly, .none:
            return false
        }
    }
}

/// Silence-risk when AppEngine is prepared but neither AppEngine nor AlarmKit is audible.
enum ForbiddenAudioStateEvaluator {
    static func isForbiddenSilentState(
        phase: AlarmAudioPhase,
        appInactive: Bool,
        alarmStateRinging: Bool,
        finalStop: Bool,
        engineActuallyAudible: Bool,
        alarmKitAlerting: Bool,
        recoveryPending: Bool
    ) -> Bool {
        guard !finalStop, alarmStateRinging, appInactive else { return false }
        guard !engineActuallyAudible else { return false }
        guard !alarmKitAlerting else { return false }
        guard !recoveryPending else { return false }
        return phase == .appEnginePreparing
    }
}

/// Pure dead-audio risk evaluation (unit-testable without UIApplication).
enum DeadAudioRiskEvaluator {
    static func isDeadAudioRisk(
        phase: AlarmAudioPhase,
        appInactive: Bool,
        enginePlaying: Bool,
        finalStop: Bool,
        alarmStateRinging: Bool
    ) -> Bool {
        guard !finalStop, alarmStateRinging, appInactive, !enginePlaying else { return false }
        switch phase {
        case .appEnginePreparing, .alarmKitFallback, .alarmKitSettling:
            // alarmKitSettling: AlarmKit owned audible output but iOS may have
            // killed it on side-button / screen-off while the engine was still
            // silently preparing — this is the primary "sound gone" failure mode.
            return true
        case .waitingForAlarmKit, .appEngineFadingIn, .appEnginePrimary, .stopped:
            return false
        }
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

            // Pre-arm the force-close warning so it surfaces even if the user
            // swipes the app away before the alarm fires. Cancelled while the app
            // is alive and the AppEngine is verified audible.
            if let fireDate = AlarmStore.nextFireDate(for: alarm, from: Date()) {
                let sourceId = alarm.id.uuidString
                let alarmName = alarm.name
                await MainActor.run {
                    NotificationManager.shared.scheduleForceClosedWarning(
                        sourceAlarmId: sourceId,
                        fireDate: fireDate,
                        alarmName: alarmName
                    )
                }
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

            // Cancel AlarmKit registrations with no backing store row — orphans from
            // a replaced/deleted alarm that still fire with their OLD sound (the
            // "I changed the sound but hear the previous one" bug). Pass ALL store
            // ids (enabled + disabled) so only genuinely-gone alarms are purged.
            if selectedPath == .alarmKit,
               let alarmKitScheduler = alarmKitScheduler as? AlarmSchedulerIOS26AlarmKit {
                await alarmKitScheduler.cancelOrphanedRegistrations(
                    knownStoreIds: Set(alarms.map(\.id))
                )
            }
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
            return "Alarm permission request failed. Open Settings > Alarmo and enable Alarms, then try again. If the Alarms option is missing, reinstall the app and request permission again on iOS 26+."
            #endif
        }

        if let schedulingError = error as? AlarmSchedulingError {
            switch schedulingError {
            case .alarmKitPermissionDenied:
                return "AlarmKit permission is denied. Enable Alarm permissions for Alarmo in Settings and try again."
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
