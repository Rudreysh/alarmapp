import Foundation

@MainActor
final class PenaltyEngine {
    static let shared = PenaltyEngine()

    private let creditsManager = PenaltyCreditsManager.shared
    private let settings = SettingsStore.shared

    private init() {}

    func shouldChargePenalty(
        alarm: Alarm,
        rules: PenaltyRules,
        session: AlarmSession?,
        violation: AlarmViolationType
    ) -> Bool {
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
            let threshold = max(1, rules.alarmSnoozeThreshold)
            print("[PenaltyEngine] Snooze check: count=\(session.snoozeCount), threshold=\(threshold)")
            return session.snoozeCount > threshold
        }
    }

    @discardableResult
    func chargeIfNeeded(
        alarm: Alarm,
        session: inout AlarmSession,
        violation: AlarmViolationType,
        note: String
    ) -> Bool {
        // For snooze-threshold, we allow recurring penalties on each snooze tap
        // after threshold is exceeded. For shutdown/tamper, keep idempotent per session.
        if violation != .snoozeThresholdExceeded,
           let existing = session.violations.first(where: { $0.type == violation }) {
            print("[PenaltyEngine] Skip: already charged for \(violation.rawValue) in current session at \(existing.timestamp), amount=\(existing.chargedAmount)")
            return false
        }
        guard shouldChargePenalty(alarm: alarm, rules: settings.penaltyRules, session: session, violation: violation) else {
            return false
        }

        let eventType: PenaltyEventType
        switch violation {
        case .shutdownAttempt:
            eventType = .shutdownAttempt
        case .uninstallTamper:
            eventType = .uninstallTamper
        case .snoozeThresholdExceeded:
            eventType = .snoozeThresholdExceeded
        }

        let consumed = creditsManager.consumeCredits(
            amountEuro: settings.penaltyAmountEuro,
            eventType: eventType,
            note: note,
            sourceAlarmId: alarm.id
        )
        if consumed {
            print("[PenaltyEngine] Charged \(settings.penaltyCurrency.symbol)\(settings.penaltyAmountEuro) for \(violation.rawValue)")
            session.status = .failed
            session.violations.append(
                ViolationEvent(type: violation, chargedAmount: settings.penaltyAmountEuro)
            )
        } else {
            print("[PenaltyEngine] Charge blocked: insufficient credits for \(violation.rawValue)")
        }
        return consumed
    }
}
