import Foundation
import Combine

@MainActor
final class AccountabilityEnforcementManager: ObservableObject {
    static let shared = AccountabilityEnforcementManager()

    private let settings = SettingsStore.shared
    private let authManager = ScreenTimeAuthorizationManager.shared
    private let shieldManager = AppShieldManager.shared
    private let creditsManager = PenaltyCreditsManager.shared

    @Published private(set) var isFocusEnforcementActive = false
    @Published private(set) var activeFocusTaskId: UUID?
    @Published private(set) var activeAlarmId: UUID?

    private init() {}

    func beginFocusSession(taskId: UUID?) {
        activeFocusTaskId = taskId
        isFocusEnforcementActive = true
        if shouldBlockApps {
            applyShieldIfPossible()
        }
        detectPotentialTimeTamper()
    }

    func endFocusSession() {
        isFocusEnforcementActive = false
        activeFocusTaskId = nil
        if activeAlarmId == nil {
            shieldManager.clearShield()
        }
    }

    @discardableResult
    func handleFocusEarlyStopPenalty() -> Bool {
        guard settings.penaltyEnabled, settings.penaltyRules.focusEarlyStopTriggersPenalty else { return true }
        return creditsManager.consumeCredits(
            amountEuro: settings.penaltyAmountEuro,
            eventType: .focusEarlyStop,
            note: "Focus session stopped early",
            sourceFocusTaskId: activeFocusTaskId
        )
    }

    @discardableResult
    func handleFocusOverridePenalty() -> Bool {
        guard settings.penaltyEnabled, settings.penaltyRules.focusOverrideTriggersPenalty else { return true }
        return creditsManager.consumeCredits(
            amountEuro: settings.penaltyAmountEuro,
            eventType: .focusOverrideBlock,
            note: "Attempted to override app block",
            sourceFocusTaskId: activeFocusTaskId
        )
    }

    func beginAlarmEnforcement(alarm: Alarm) {
        activeAlarmId = alarm.id
        if shouldBlockAppsForAlarm(alarm) {
            applyShield(data: effectiveSelectionData(for: alarm))
        }
        detectPotentialTimeTamper()
    }

    func endAlarmEnforcement() {
        activeAlarmId = nil
        if !isFocusEnforcementActive {
            shieldManager.clearShield()
        }
    }

    @discardableResult
    func handleAlarmExcessSnoozePenalty(alarm: Alarm, snoozeCount: Int = 0) -> Bool {
        guard alarm.penaltyEnabled,
              alarm.penaltyRules.triggerSnoozeThresholdEnabled,
              alarm.penaltyRules.alarmSnoozeThreshold > 0,
              snoozeCount >= alarm.penaltyRules.alarmSnoozeThreshold else {
            return true
        }
        return creditsManager.consumeCredits(
            amountEuro: alarm.penaltyAmountEuro,
            eventType: .alarmExcessSnooze,
            note: "Snooze threshold reached (\(snoozeCount)/\(alarm.penaltyRules.alarmSnoozeThreshold))",
            sourceAlarmId: alarm.id
        )
    }

    @discardableResult
    func handleAlarmMissionFailurePenalty(alarm: Alarm) -> Bool {
        guard alarm.penaltyEnabled, alarm.penaltyRules.alarmMissionFailTriggersPenalty else { return true }
        return creditsManager.consumeCredits(
            amountEuro: alarm.penaltyAmountEuro,
            eventType: .alarmMissionFailed,
            note: "Mission failed or timed out",
            sourceAlarmId: alarm.id
        )
    }

    func ensureShieldRestoredOnLaunch() {
        let shouldRestore = isFocusEnforcementActive || activeAlarmId != nil
        shieldManager.ensureShieldRestoredOnAppLaunch(
            isEnforcementActive: shouldRestore,
            selectionData: settings.blockedAppsSelectionData
        )
    }

    private var shouldBlockApps: Bool {
        settings.accountabilityEnabled && settings.blockAppsEnabled
    }

    private func shouldBlockAppsForAlarm(_ alarm: Alarm) -> Bool {
        alarm.blockAppsEnabled
    }

    private func effectiveSelectionData(for alarm: Alarm) -> Data {
        if let specific = alarm.blockedSelectionData, !specific.isEmpty {
            return specific
        }
        return settings.blockedAppsSelectionData
    }

    private func applyShieldIfPossible() {
        applyShield(data: settings.blockedAppsSelectionData)
    }

    private func applyShield(data: Data) {
        guard authManager.isAuthorized else { return }
        shieldManager.applyShield(selectionData: data)
    }

    private func detectPotentialTimeTamper() {
        if let buildDate = Bundle.main.infoDictionary?["CFBundleVersion"] as? String, buildDate.isEmpty {
            // no-op guard for static analyzers
        }
        // Simple local tamper signal: if clock appears behind last recorded penalty timestamp.
        if let last = settings.lastPenaltyDate, Date() < last {
            settings.markPotentialTimeTamper()
        }
    }
}
