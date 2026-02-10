import Foundation

enum EnforcementMode: String, Codable, CaseIterable {
    case none
    case blockApps
    case penaltyOnly
    case blockAppsAndPenalty

    var blocksApps: Bool {
        self == .blockApps || self == .blockAppsAndPenalty
    }

    var usesPenalty: Bool {
        self == .penaltyOnly || self == .blockAppsAndPenalty
    }
}

enum PenaltyStrategy: String, Codable, CaseIterable {
    case credits
}

enum PenaltyEventType: String, Codable, CaseIterable {
    case focusEarlyStop
    case focusOverrideBlock
    case alarmExcessSnooze
    case alarmMissionFailed
    case shutdownAttempt
    case uninstallTamper
    case snoozeThresholdExceeded
}

struct PenaltyRules: Codable, Equatable {
    var focusEarlyStopTriggersPenalty: Bool = true
    var focusOverrideTriggersPenalty: Bool = true
    var alarmSnoozeThreshold: Int = 3
    var alarmMissionTimeoutSeconds: Int = 180
    var alarmMissionFailTriggersPenalty: Bool = false
    var triggerShutdownAttemptEnabled: Bool = true
    var triggerUninstallTamperEnabled: Bool = true
    var triggerSnoozeThresholdEnabled: Bool = true

    static let `default` = PenaltyRules()

    init(
        focusEarlyStopTriggersPenalty: Bool = true,
        focusOverrideTriggersPenalty: Bool = true,
        alarmSnoozeThreshold: Int = 3,
        alarmMissionTimeoutSeconds: Int = 180,
        alarmMissionFailTriggersPenalty: Bool = false,
        triggerShutdownAttemptEnabled: Bool = true,
        triggerUninstallTamperEnabled: Bool = true,
        triggerSnoozeThresholdEnabled: Bool = true
    ) {
        self.focusEarlyStopTriggersPenalty = focusEarlyStopTriggersPenalty
        self.focusOverrideTriggersPenalty = focusOverrideTriggersPenalty
        self.alarmSnoozeThreshold = min(10, max(1, alarmSnoozeThreshold))
        self.alarmMissionTimeoutSeconds = max(30, alarmMissionTimeoutSeconds)
        self.alarmMissionFailTriggersPenalty = alarmMissionFailTriggersPenalty
        self.triggerShutdownAttemptEnabled = triggerShutdownAttemptEnabled
        self.triggerUninstallTamperEnabled = triggerUninstallTamperEnabled
        self.triggerSnoozeThresholdEnabled = triggerSnoozeThresholdEnabled
    }

    private enum CodingKeys: String, CodingKey {
        case focusEarlyStopTriggersPenalty
        case focusOverrideTriggersPenalty
        case alarmSnoozeThreshold
        case alarmMissionTimeoutSeconds
        case alarmMissionFailTriggersPenalty
        case triggerShutdownAttemptEnabled
        case triggerUninstallTamperEnabled
        case triggerSnoozeThresholdEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.focusEarlyStopTriggersPenalty = try container.decodeIfPresent(Bool.self, forKey: .focusEarlyStopTriggersPenalty) ?? true
        self.focusOverrideTriggersPenalty = try container.decodeIfPresent(Bool.self, forKey: .focusOverrideTriggersPenalty) ?? true
        self.alarmSnoozeThreshold = min(10, max(1, try container.decodeIfPresent(Int.self, forKey: .alarmSnoozeThreshold) ?? 3))
        self.alarmMissionTimeoutSeconds = max(30, try container.decodeIfPresent(Int.self, forKey: .alarmMissionTimeoutSeconds) ?? 180)
        self.alarmMissionFailTriggersPenalty = try container.decodeIfPresent(Bool.self, forKey: .alarmMissionFailTriggersPenalty) ?? false
        self.triggerShutdownAttemptEnabled = try container.decodeIfPresent(Bool.self, forKey: .triggerShutdownAttemptEnabled) ?? true
        self.triggerUninstallTamperEnabled = try container.decodeIfPresent(Bool.self, forKey: .triggerUninstallTamperEnabled) ?? true
        self.triggerSnoozeThresholdEnabled = try container.decodeIfPresent(Bool.self, forKey: .triggerSnoozeThresholdEnabled) ?? true
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(focusEarlyStopTriggersPenalty, forKey: .focusEarlyStopTriggersPenalty)
        try container.encode(focusOverrideTriggersPenalty, forKey: .focusOverrideTriggersPenalty)
        try container.encode(min(10, max(1, alarmSnoozeThreshold)), forKey: .alarmSnoozeThreshold)
        try container.encode(max(30, alarmMissionTimeoutSeconds), forKey: .alarmMissionTimeoutSeconds)
        try container.encode(alarmMissionFailTriggersPenalty, forKey: .alarmMissionFailTriggersPenalty)
        try container.encode(triggerShutdownAttemptEnabled, forKey: .triggerShutdownAttemptEnabled)
        try container.encode(triggerUninstallTamperEnabled, forKey: .triggerUninstallTamperEnabled)
        try container.encode(triggerSnoozeThresholdEnabled, forKey: .triggerSnoozeThresholdEnabled)
    }
}

struct PenaltyEventRecord: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var date: Date = Date()
    var eventType: PenaltyEventType
    var amountEuro: Int
    var sourceId: UUID?
    var note: String?
}

enum AlarmViolationType: String, Codable, Hashable, CaseIterable {
    case shutdownAttempt
    case uninstallTamper
    case snoozeThresholdExceeded
}

enum AlarmMissionStatus: String, Codable {
    case inProgress
    case completed
}

enum AlarmSessionStatus: String, Codable {
    case ringing
    case snoozed
    case completed
    case failed
}

struct ViolationEvent: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var type: AlarmViolationType
    var timestamp: Date = Date()
    var chargedAmount: Int
}

struct AlarmSession: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var alarmId: UUID
    var startedAt: Date = Date()
    var isActive: Bool = true
    var snoozeCount: Int = 0
    var hasMissions: Bool = false
    var missionStatus: AlarmMissionStatus = .inProgress
    var status: AlarmSessionStatus = .ringing
    var violations: [ViolationEvent] = []
}
