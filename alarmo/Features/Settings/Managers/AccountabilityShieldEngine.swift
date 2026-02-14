import Foundation
import UIKit
import Combine
import Network

@MainActor
final class AccountabilityShieldEngine: ObservableObject {
    static let shared = AccountabilityShieldEngine()
    let objectWillChange = ObservableObjectPublisher()

    private let settings = SettingsStore.shared
    private let creditsManager = PenaltyCreditsManager.shared
    private let subscription = SubscriptionManager.shared

    private var heartbeatTimer: Timer?
    private var graceTimer: Timer?
    private var pathMonitor: NWPathMonitor?
    private let pathQueue = DispatchQueue(label: "shield.path.monitor")
    private var lastPathStatus: NWPath.Status?

    private init() {
        startGracePeriodScheduler()
        processPendingViolations()
    }

    // MARK: - Session lifecycle

    func sessionDidStart(alarm: Alarm, session: AlarmSession?) {
        UIDevice.current.isBatteryMonitoringEnabled = true
        var resolved = session ?? AlarmSession(alarmId: alarm.id)
        resolved.alarmId = alarm.id
        resolved.isActive = true
        resolved.penaltyEnabled = alarm.penaltyEnabled
        resolved.status = .ringing
        resolved.lastHeartbeatAt = Date()
        resolved.startedBatteryLevel = UIDevice.current.batteryLevel >= 0 ? UIDevice.current.batteryLevel : nil
        resolved.lastBatteryLevel = resolved.startedBatteryLevel
        settings.activeAlarmSession = resolved
        startHeartbeat()
        startPathMonitorIfNeeded()
    }

    func syncSession(_ session: AlarmSession?) {
        guard var session else {
            settings.activeAlarmSession = nil
            stopHeartbeat()
            stopPathMonitor()
            return
        }
        session.lastHeartbeatAt = Date()
        if UIDevice.current.batteryLevel >= 0 {
            session.lastBatteryLevel = UIDevice.current.batteryLevel
        }
        settings.activeAlarmSession = session
    }

    func sessionDidEnd(reason: String?, completed: Bool) {
        sessionDidEnd(alarm: nil, reason: reason, completed: completed)
    }

    func sessionDidEnd(alarm: Alarm?, reason: String?, completed: Bool) {
        guard var session = settings.activeAlarmSession else {
            stopHeartbeat()
            stopPathMonitor()
            return
        }
        if !completed,
           session.airplaneEmergencyActive,
           !isEmergencyCancellationCompleted(),
           let alarm {
            _ = reportViolation(
                alarm: alarm,
                session: &session,
                type: .airplaneModeAbuse,
                note: "Emergency cancellation flow incomplete",
                confidence: .medium
            )
        }
        session.lastHeartbeatAt = Date()
        session.endedAt = Date()
        session.endReason = reason
        session.isActive = false
        session.status = completed ? .completed : .failed
        settings.activeAlarmSession = session
        stopHeartbeat()
        stopPathMonitor()
    }

    func sessionDidEnterMission() {
        guard var session = settings.activeAlarmSession else { return }
        session.status = .missionInProgress
        session.lastHeartbeatAt = Date()
        settings.activeAlarmSession = session
    }

    func sessionDidCompleteMission() {
        guard var session = settings.activeAlarmSession else { return }
        session.missionStatus = .completed
        session.status = .ringing
        session.lastHeartbeatAt = Date()
        settings.activeAlarmSession = session
    }

    func sessionDidSnooze() {
        guard var session = settings.activeAlarmSession else { return }
        session.status = .snoozed
        session.lastHeartbeatAt = Date()
        settings.activeAlarmSession = session
    }
    
    // MARK: - Penalty rules and violation creation

    @discardableResult
    func reportViolation(
        alarm: Alarm,
        session: inout AlarmSession,
        type: AlarmViolationType,
        note: String,
        confidence: ViolationConfidence = .medium
    ) -> Bool {
        guard subscription.isPro else {
            print("[Shield] Skip: PRO required")
            return false
        }
        #if !targetEnvironment(simulator)
        guard settings.hasValidPenaltyPaymentMethod else {
            print("[Shield] Skip: payment method missing")
            return false
        }
        guard settings.penaltyTermsAccepted else {
            print("[Shield] Skip: terms not accepted")
            return false
        }
        #endif
        guard settings.accountabilityEnabled else {
            print("[Shield] Skip: Accountability Shield disabled globally")
            return false
        }
        guard alarm.penaltyEnabled, session.penaltyEnabled else {
            print("[Shield] Skip: penalty disabled for alarm/session")
            return false
        }
        guard session.isActive else {
            print("[Shield] Skip: no active alarm session")
            return false
        }
        guard isTriggerEnabled(type) else {
            print("[Shield] Skip: trigger disabled for \(type.rawValue)")
            return false
        }
        if type == .snoozeThresholdExceeded {
            let globalThreshold = max(1, settings.snoozePenaltyThreshold)
            let alarmLimit = alarm.snoozeCount
            
            // We need to apply the same logic as PenaltyEngine:
            // If EITHER the global threshold IS MET (>=) OR the unique alarm limit is EXCEEDED (>)
            // However, since PenaltyEngine already decided "true" to call us, we should rely on that or re-verify loosely.
            // The issue in the logs was: "[Shield] Snooze threshold not crossed. count=2, threshold=3"
            // This check was ONLY looking at global settings.
            
            let crossedGlobal = session.snoozeCount >= globalThreshold
            let crossedAlarm = session.snoozeCount > alarmLimit
            
            if !crossedGlobal && !crossedAlarm {
                print("[Shield] Snooze threshold check failed. count=\(session.snoozeCount), global=\(globalThreshold), alarmLimit=\(alarmLimit)")
                return false
            }
        }
        if session.violations.contains(where: { $0.type == type }) {
             // For snooze, we might want multiple violations if they keep snoozing?
             // Usually shielding implies "one penalty per session" for snooze abuse to avoid draining wallet instantly.
             // We stick to idempotency for now.
            print("[Shield] Idempotency skip: \(type.rawValue) already recorded for session")
            return false
        }

        var violation = ViolationEvent(
            type: type,
            timestamp: Date(),
            chargedAmount: max(1, min(10, settings.penaltyAmountEuro)),
            status: .pendingGracePeriod,
            gracePeriodExpiresAt: Date().addingTimeInterval(24 * 3600),
            confidence: confidence,
            evidence: note
        )
        session.violations.append(violation)
        session.status = .failed
        session.lastHeartbeatAt = Date()
        settings.activeAlarmSession = session

        settings.violations.append(violation)
        print("[Shield] Violation queued: \(type.rawValue), grace until \(violation.gracePeriodExpiresAt?.description ?? "-")")

        // Keep existing visible debug behavior while moving to grace-period processing.
        #if DEBUG
        settings.appendPenaltyAudit(
            AccountabilityAuditEvent(
                eventType: mapToPenaltyEventType(type),
                amountEuro: violation.chargedAmount,
                sourceAlarmId: alarm.id,
                note: "DEBUG_TRIGGER_ONLY: \(note)"
            )
        )
        #endif

        // Immediate automated exemption checks for clearly excusable conditions.
        autoResolveIfExemptable(&violation)
        updateStoredViolation(violation)
        return true
    }

    func requestExemption(violationId: UUID, reasonCategory: String, reasonText: String?) {
        guard var violation = settings.violations.first(where: { $0.id == violationId }) else { return }
        guard violation.status == .pendingGracePeriod || violation.status == .pendingReview else { return }

        var request = ExemptionRequest(
            violationId: violationId,
            reasonCategory: reasonCategory,
            reasonText: reasonText,
            status: .pending
        )
        settings.exemptionRequests.append(request)

        violation.exemptionRequestId = request.id
        violation.status = .pendingReview
        updateStoredViolation(violation)

        // Automated v1 triage.
        let isFirstViolation = settings.violations.filter { $0.status == .charged || $0.status == .paymentFailed }.isEmpty
        let shouldAutoApprove = (settings.penaltyRules.autoApproveFirstViolation && isFirstViolation)
            || (settings.penaltyRules.autoApproveLowBattery && violation.type == .severeBatteryDrain)

        if shouldAutoApprove {
            request.status = .approved
            request.decisionAt = Date()
            request.decisionNote = "Auto-approved by policy"
            replaceExemptionRequest(request)
            violation.status = .excused
            updateStoredViolation(violation)
        }
    }

    func requestExemption(violationId: UUID, reason: String) {
        requestExemption(violationId: violationId, reasonCategory: "General", reasonText: reason)
    }

    func resolveExemption(violationId: UUID, approve: Bool, note: String?) {
        guard var violation = settings.violations.first(where: { $0.id == violationId }),
              let requestId = violation.exemptionRequestId,
              var request = settings.exemptionRequests.first(where: { $0.id == requestId }) else { return }

        request.status = approve ? .approved : .denied
        request.decisionAt = Date()
        request.decisionNote = note
        replaceExemptionRequest(request)

        violation.status = approve ? .excused : .pendingGracePeriod
        if !approve, violation.gracePeriodExpiresAt == nil || (violation.gracePeriodExpiresAt ?? .distantPast) < Date() {
            violation.gracePeriodExpiresAt = Date().addingTimeInterval(24 * 3600)
        }
        updateStoredViolation(violation)
    }

    // MARK: - Force-close / restart / battery heuristics

    func reconcileActiveSessionOnLaunch(ringingAlarmId: UUID?, alarmStore: AlarmStore?) {
        guard var session = settings.activeAlarmSession, session.isActive else { return }
        if let ringingAlarmId, ringingAlarmId == session.alarmId {
            return
        }

        let now = Date()
        let gap = now.timeIntervalSince(session.lastHeartbeatAt)
        guard gap > 45 else { return }

        let lowBatteryThreshold = Float(settings.penaltyRules.lowBatteryExemptThresholdPercent) / 100.0
        let startBattery = session.startedBatteryLevel ?? -1
        let currentBattery = UIDevice.current.batteryLevel
        let batteryKnown = startBattery >= 0 && currentBattery >= 0
        let likelyNaturalDrain = batteryKnown && (startBattery <= lowBatteryThreshold || currentBattery <= lowBatteryThreshold)

        let type: AlarmViolationType
        let confidence: ViolationConfidence
        if likelyNaturalDrain {
            type = .severeBatteryDrain
            confidence = .high
        } else if gap > 180 {
            type = .forcedRestart
            confidence = .medium
        } else {
            type = .forceClose
            confidence = .medium
        }

        guard let alarm = alarmStore?.alarm(by: session.alarmId) else { return }
        _ = reportViolation(
            alarm: alarm,
            session: &session,
            type: type,
            note: "Post-facto reconcile. heartbeat-gap=\(Int(gap))s",
            confidence: confidence
        )
        settings.activeAlarmSession = session
    }

    func reconcilePreviousSession() {
        reconcileActiveSessionOnLaunch(ringingAlarmId: nil, alarmStore: AlarmStore.shared)
        processPendingViolations()
    }

    func markAirplaneModeAbuseRequired() {
        guard settings.penaltyRules.triggerAirplaneModeAbuseEnabled else { return }
        guard var session = settings.activeAlarmSession, session.isActive else { return }
        session.airplaneEmergencyActive = true
        session.emergencyTapTarget = max(100, settings.penaltyRules.emergencyCancellationTapTarget)
        settings.activeAlarmSession = session
    }

    func registerEmergencyTap() -> Int {
        guard var session = settings.activeAlarmSession, session.airplaneEmergencyActive else { return 0 }
        session.emergencyTapCount += 1
        session.lastHeartbeatAt = Date()
        settings.activeAlarmSession = session
        return max(0, session.emergencyTapTarget - session.emergencyTapCount)
    }

    func isEmergencyCancellationCompleted() -> Bool {
        guard let session = settings.activeAlarmSession, session.airplaneEmergencyActive else { return true }
        return session.emergencyTapCount >= session.emergencyTapTarget
    }

    // MARK: - Grace and charge execution

    func processPendingViolations(now: Date = Date()) {
        for violation in settings.violations {
            guard violation.status == .pendingGracePeriod else { continue }
            guard let expiry = violation.gracePeriodExpiresAt, now >= expiry else { continue }

            if violation.exemptionRequestId != nil,
               let request = settings.exemptionRequests.first(where: { $0.id == violation.exemptionRequestId }),
               request.status == .pending {
                var pending = violation
                pending.status = .pendingReview
                updateStoredViolation(pending)
                continue
            }

            executeCharge(for: violation)
        }
    }

    // MARK: - Private

    private func isTriggerEnabled(_ type: AlarmViolationType) -> Bool {
        let rules = settings.penaltyRules
        switch type {
        case .shutdownAttempt: return rules.triggerShutdownAttemptEnabled
        case .forceClose: return rules.triggerForceCloseEnabled
        case .uninstallTamper: return rules.triggerUninstallTamperEnabled
        case .forcedRestart: return rules.triggerForcedRestartEnabled
        case .airplaneModeAbuse: return rules.triggerAirplaneModeAbuseEnabled
        case .severeBatteryDrain: return rules.triggerBatteryDrainEnabled
        case .snoozeThresholdExceeded: return rules.triggerSnoozeThresholdEnabled
        case .alarmMissionFailed: return rules.alarmMissionFailTriggersPenalty
        default: return false
        }
    }

    private func mapToPenaltyEventType(_ violation: AlarmViolationType) -> PenaltyEventType {
        switch violation {
        case .shutdownAttempt: return .shutdownAttempt
        case .forceClose: return .forceClose
        case .uninstallTamper: return .uninstallTamper
        case .forcedRestart: return .forcedRestart
        case .airplaneModeAbuse: return .airplaneModeAbuse
        case .severeBatteryDrain: return .abruptPowerLoss
        case .snoozeThresholdExceeded: return .snoozeThresholdExceeded
        case .alarmMissionFailed: return .alarmMissionFailed
        default: return .snoozeThresholdExceeded // Safe default
        }
    }

    private func executeCharge(for violation: ViolationEvent) {
        var updated = violation
        updated.chargeAttempts += 1
        updated.lastChargeAttemptAt = Date()

        let consumed = creditsManager.consumeCredits(
            amountEuro: max(1, min(10, updated.chargedAmount)),
            eventType: mapToPenaltyEventType(updated.type),
            note: "Grace expired for violation \(updated.id)"
        )

        let transaction = PenaltyTransaction(
            violationId: updated.id,
            amountEuro: updated.chargedAmount,
            success: consumed,
            transactionReference: consumed ? "credits-\(UUID().uuidString.prefix(8))" : nil,
            failureReason: consumed ? nil : "insufficient_credits_or_payment_unavailable"
        )
        settings.penaltyTransactions.append(transaction)
        updated.transactionId = transaction.id

        if consumed {
            updated.status = .charged
            updateStoredViolation(updated)
            return
        }

        if updated.chargeAttempts >= 2 {
            updated.status = .paymentFailed
            settings.accountabilityEnabled = false
        } else {
            updated.status = .pendingGracePeriod
            updated.gracePeriodExpiresAt = Date().addingTimeInterval(24 * 3600)
        }
        updateStoredViolation(updated)
    }

    private func autoResolveIfExemptable(_ violation: inout ViolationEvent) {
        let isFirst = settings.violations.filter { $0.status == .charged || $0.status == .paymentFailed }.isEmpty
        if settings.penaltyRules.autoApproveFirstViolation && isFirst {
            violation.status = .excused
            return
        }
        if settings.penaltyRules.autoApproveLowBattery && violation.type == .severeBatteryDrain {
            violation.status = .excused
        }
    }

    private func startHeartbeat() {
        stopHeartbeat()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.pulseHeartbeat()
            }
        }
    }

    private func stopHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }

    private func pulseHeartbeat() {
        guard var session = settings.activeAlarmSession, session.isActive else {
            stopHeartbeat()
            return
        }
        session.lastHeartbeatAt = Date()
        if UIDevice.current.batteryLevel >= 0 {
            session.lastBatteryLevel = UIDevice.current.batteryLevel
        }
        settings.activeAlarmSession = session
    }

    private func startGracePeriodScheduler() {
        graceTimer?.invalidate()
        graceTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.processPendingViolations()
            }
        }
    }

    private func startPathMonitorIfNeeded() {
        guard settings.penaltyRules.triggerAirplaneModeAbuseEnabled else { return }
        stopPathMonitor()
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.handlePathUpdate(path.status)
            }
        }
        monitor.start(queue: pathQueue)
        pathMonitor = monitor
    }

    private func stopPathMonitor() {
        pathMonitor?.cancel()
        pathMonitor = nil
        lastPathStatus = nil
    }

    private func handlePathUpdate(_ status: NWPath.Status) {
        defer { lastPathStatus = status }
        guard var session = settings.activeAlarmSession, session.isActive else { return }
        guard settings.penaltyRules.triggerAirplaneModeAbuseEnabled else { return }
        guard status == .unsatisfied, lastPathStatus != .unsatisfied else { return }
        session.airplaneEmergencyActive = true
        session.emergencyTapTarget = max(100, settings.penaltyRules.emergencyCancellationTapTarget)
        session.lastHeartbeatAt = Date()
        settings.activeAlarmSession = session
        print("[Shield] Airplane/network abuse signal detected. Emergency cancellation mode enabled.")
    }

    private func updateStoredViolation(_ violation: ViolationEvent) {
        guard let idx = settings.violations.firstIndex(where: { $0.id == violation.id }) else { return }
        settings.violations[idx] = violation
        if var session = settings.activeAlarmSession,
           let localIdx = session.violations.firstIndex(where: { $0.id == violation.id }) {
            session.violations[localIdx] = violation
            settings.activeAlarmSession = session
        }
    }

    private func replaceExemptionRequest(_ request: ExemptionRequest) {
        if let idx = settings.exemptionRequests.firstIndex(where: { $0.id == request.id }) {
            settings.exemptionRequests[idx] = request
        } else {
            settings.exemptionRequests.append(request)
        }
    }
}
