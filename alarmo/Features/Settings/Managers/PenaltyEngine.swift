import Foundation

@MainActor
final class PenaltyEngine {
    static let shared = PenaltyEngine()

    private let settings = SettingsStore.shared
    private let shieldEngine = AccountabilityShieldEngine.shared

    private init() {}

    func shouldChargePenalty(
        alarm: Alarm,
        rules: PenaltyRules,
        session: AlarmSession?,
        violation: AlarmViolationType
    ) -> Bool {
        // TEMPORARILY DISABLED (Penalty rollout paused):
        // Keep this method and its caller flow intact for future implementation.
        // All penalty charging decisions are currently forced OFF.
        _ = alarm
        _ = rules
        _ = session
        _ = violation
        return false

        /*
        guard alarm.penaltyEnabled else {
            print("[PenaltyEngine] Skip: penalty disabled for alarm \(alarm.id)")
            return false
        }
        guard let session, session.isActive else {
            print("[PenaltyEngine] Skip: no active session for alarm \(alarm.id)")
            return false
        }
        switch violation {
        case .shutdownAttempt:
            if !rules.triggerShutdownAttemptEnabled {
                print("[PenaltyEngine] Skip: shutdown trigger disabled")
            }
            return rules.triggerShutdownAttemptEnabled
        case .forceClose:
            if !rules.triggerForceCloseEnabled {
                print("[PenaltyEngine] Skip: force-close trigger disabled")
            }
            return rules.triggerForceCloseEnabled
        case .forcedRestart:
            if !rules.triggerForcedRestartEnabled {
                print("[PenaltyEngine] Skip: forced-restart trigger disabled")
            }
            return rules.triggerForcedRestartEnabled
        case .airplaneModeAbuse:
            if !rules.triggerAirplaneModeAbuseEnabled {
                print("[PenaltyEngine] Skip: airplane-abuse trigger disabled")
            }
            return rules.triggerAirplaneModeAbuseEnabled
        case .severeBatteryDrain:
            if !rules.triggerBatteryDrainEnabled {
                print("[PenaltyEngine] Skip: battery-drain trigger disabled")
            }
            return rules.triggerBatteryDrainEnabled
        case .uninstallTamper:
            if !rules.triggerUninstallTamperEnabled {
                print("[PenaltyEngine] Skip: uninstall/tamper trigger disabled")
            }
            return rules.triggerUninstallTamperEnabled
        case .snoozeThresholdExceeded:
            guard rules.triggerSnoozeThresholdEnabled else {
                print("[PenaltyEngine] Skip: snooze-threshold trigger disabled")
                return false
            }
            let globalThreshold = max(1, rules.alarmSnoozeThreshold)
            let alarmLimit = alarm.snoozeCount
            
            // Check global rule (>= threshold means penalty)
            let crossedGlobal = session.snoozeCount >= globalThreshold
            
            // Check alarm specific limit (> count means penalty)
            let crossedAlarm = session.snoozeCount > alarmLimit
            
            print("[PenaltyEngine] Snooze check: count=\(session.snoozeCount), globalThreshold=\(globalThreshold), alarmLimit=\(alarmLimit)")
            return crossedGlobal || crossedAlarm
        case .alarmMissionFailed:
            guard rules.alarmMissionFailTriggersPenalty else {
                print("[PenaltyEngine] Skip: alarm mission penalty disabled")
                return false
            }
            return true
        default: return false
        }
        */
    }

    @discardableResult
    func chargeIfNeeded(
        alarm: Alarm,
        session: inout AlarmSession,
        violation: AlarmViolationType,
        note: String
    ) -> Bool {
        // TEMPORARILY DISABLED (Penalty rollout paused):
        // This method intentionally does not queue or charge penalties.
        _ = alarm
        _ = session
        _ = violation
        _ = note
        return false

        /*
        if let existing = session.violations.first(where: { $0.type == violation }) {
            print("[PenaltyEngine] Skip: already charged for \(violation.rawValue) in current session at \(existing.timestamp), amount=\(existing.chargedAmount)")
            return false
        }
        guard shouldChargePenalty(alarm: alarm, rules: settings.penaltyRules, session: session, violation: violation) else {
            return false
        }
        let queued = shieldEngine.reportViolation(
            alarm: alarm,
            session: &session,
            type: violation,
            note: note
        )
        if queued {
            print("[PenaltyEngine] Violation queued with grace period for \(violation.rawValue)")
        }
        return queued
        */
    }
}
