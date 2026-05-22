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
    case forceClose
    case uninstallTamper
    case forcedRestart
    case airplaneModeAbuse
    case abruptPowerLoss
    case snoozeThresholdExceeded
}

struct PenaltyRules: Codable, Equatable {
    var focusEarlyStopTriggersPenalty: Bool = true
    var focusOverrideTriggersPenalty: Bool = true
    var alarmSnoozeThreshold: Int = 3
    var alarmMissionTimeoutSeconds: Int = 180
    var alarmMissionFailTriggersPenalty: Bool = false
    var triggerShutdownAttemptEnabled: Bool = true
    var triggerForceCloseEnabled: Bool = true
    var triggerUninstallTamperEnabled: Bool = true
    var triggerForcedRestartEnabled: Bool = true
    var triggerBatteryDrainEnabled: Bool = true
    var triggerAirplaneModeAbuseEnabled: Bool = true
    var triggerSnoozeThresholdEnabled: Bool = true
    var emergencyCancellationTapTarget: Int = 500
    var lowBatteryExemptThresholdPercent: Int = 5
    var autoApproveFirstViolation: Bool = true
    var autoApproveLowBattery: Bool = true

    static let `default` = PenaltyRules()

    private enum CodingKeys: String, CodingKey {
        case focusEarlyStopTriggersPenalty
        case focusOverrideTriggersPenalty
        case alarmSnoozeThreshold
        case alarmMissionTimeoutSeconds
        case alarmMissionFailTriggersPenalty
        case triggerShutdownAttemptEnabled
        case triggerForceCloseEnabled
        case triggerUninstallTamperEnabled
        case triggerForcedRestartEnabled
        case triggerBatteryDrainEnabled
        case triggerAirplaneModeAbuseEnabled
        case triggerSnoozeThresholdEnabled
        case emergencyCancellationTapTarget
        case lowBatteryExemptThresholdPercent
        case autoApproveFirstViolation
        case autoApproveLowBattery
    }

    init(
        focusEarlyStopTriggersPenalty: Bool = true,
        focusOverrideTriggersPenalty: Bool = true,
        alarmSnoozeThreshold: Int = 3,
        alarmMissionTimeoutSeconds: Int = 180,
        alarmMissionFailTriggersPenalty: Bool = false,
        triggerShutdownAttemptEnabled: Bool = true,
        triggerForceCloseEnabled: Bool = true,
        triggerUninstallTamperEnabled: Bool = true,
        triggerForcedRestartEnabled: Bool = true,
        triggerBatteryDrainEnabled: Bool = true,
        triggerAirplaneModeAbuseEnabled: Bool = true,
        triggerSnoozeThresholdEnabled: Bool = true,
        emergencyCancellationTapTarget: Int = 500,
        lowBatteryExemptThresholdPercent: Int = 5,
        autoApproveFirstViolation: Bool = true,
        autoApproveLowBattery: Bool = true
    ) {
        self.focusEarlyStopTriggersPenalty = focusEarlyStopTriggersPenalty
        self.focusOverrideTriggersPenalty = focusOverrideTriggersPenalty
        self.alarmSnoozeThreshold = min(10, max(1, alarmSnoozeThreshold))
        self.alarmMissionTimeoutSeconds = max(30, alarmMissionTimeoutSeconds)
        self.alarmMissionFailTriggersPenalty = alarmMissionFailTriggersPenalty
        self.triggerShutdownAttemptEnabled = triggerShutdownAttemptEnabled
        self.triggerForceCloseEnabled = triggerForceCloseEnabled
        self.triggerUninstallTamperEnabled = triggerUninstallTamperEnabled
        self.triggerForcedRestartEnabled = triggerForcedRestartEnabled
        self.triggerBatteryDrainEnabled = triggerBatteryDrainEnabled
        self.triggerAirplaneModeAbuseEnabled = triggerAirplaneModeAbuseEnabled
        self.triggerSnoozeThresholdEnabled = triggerSnoozeThresholdEnabled
        self.emergencyCancellationTapTarget = max(100, emergencyCancellationTapTarget)
        self.lowBatteryExemptThresholdPercent = min(20, max(1, lowBatteryExemptThresholdPercent))
        self.autoApproveFirstViolation = autoApproveFirstViolation
        self.autoApproveLowBattery = autoApproveLowBattery
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.focusEarlyStopTriggersPenalty = try container.decodeIfPresent(Bool.self, forKey: .focusEarlyStopTriggersPenalty) ?? true
        self.focusOverrideTriggersPenalty = try container.decodeIfPresent(Bool.self, forKey: .focusOverrideTriggersPenalty) ?? true
        self.alarmSnoozeThreshold = min(10, max(1, try container.decodeIfPresent(Int.self, forKey: .alarmSnoozeThreshold) ?? 3))
        self.alarmMissionTimeoutSeconds = max(30, try container.decodeIfPresent(Int.self, forKey: .alarmMissionTimeoutSeconds) ?? 180)
        self.alarmMissionFailTriggersPenalty = try container.decodeIfPresent(Bool.self, forKey: .alarmMissionFailTriggersPenalty) ?? false
        self.triggerShutdownAttemptEnabled = try container.decodeIfPresent(Bool.self, forKey: .triggerShutdownAttemptEnabled) ?? true
        self.triggerForceCloseEnabled = try container.decodeIfPresent(Bool.self, forKey: .triggerForceCloseEnabled) ?? true
        self.triggerUninstallTamperEnabled = try container.decodeIfPresent(Bool.self, forKey: .triggerUninstallTamperEnabled) ?? true
        self.triggerForcedRestartEnabled = try container.decodeIfPresent(Bool.self, forKey: .triggerForcedRestartEnabled) ?? true
        self.triggerBatteryDrainEnabled = try container.decodeIfPresent(Bool.self, forKey: .triggerBatteryDrainEnabled) ?? true
        self.triggerAirplaneModeAbuseEnabled = try container.decodeIfPresent(Bool.self, forKey: .triggerAirplaneModeAbuseEnabled) ?? true
        self.triggerSnoozeThresholdEnabled = try container.decodeIfPresent(Bool.self, forKey: .triggerSnoozeThresholdEnabled) ?? true
        self.emergencyCancellationTapTarget = max(100, try container.decodeIfPresent(Int.self, forKey: .emergencyCancellationTapTarget) ?? 500)
        self.lowBatteryExemptThresholdPercent = min(20, max(1, try container.decodeIfPresent(Int.self, forKey: .lowBatteryExemptThresholdPercent) ?? 5))
        self.autoApproveFirstViolation = try container.decodeIfPresent(Bool.self, forKey: .autoApproveFirstViolation) ?? true
        self.autoApproveLowBattery = try container.decodeIfPresent(Bool.self, forKey: .autoApproveLowBattery) ?? true
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(focusEarlyStopTriggersPenalty, forKey: .focusEarlyStopTriggersPenalty)
        try container.encode(focusOverrideTriggersPenalty, forKey: .focusOverrideTriggersPenalty)
        try container.encode(min(10, max(1, alarmSnoozeThreshold)), forKey: .alarmSnoozeThreshold)
        try container.encode(max(30, alarmMissionTimeoutSeconds), forKey: .alarmMissionTimeoutSeconds)
        try container.encode(alarmMissionFailTriggersPenalty, forKey: .alarmMissionFailTriggersPenalty)
        try container.encode(triggerShutdownAttemptEnabled, forKey: .triggerShutdownAttemptEnabled)
        try container.encode(triggerForceCloseEnabled, forKey: .triggerForceCloseEnabled)
        try container.encode(triggerUninstallTamperEnabled, forKey: .triggerUninstallTamperEnabled)
        try container.encode(triggerForcedRestartEnabled, forKey: .triggerForcedRestartEnabled)
        try container.encode(triggerBatteryDrainEnabled, forKey: .triggerBatteryDrainEnabled)
        try container.encode(triggerAirplaneModeAbuseEnabled, forKey: .triggerAirplaneModeAbuseEnabled)
        try container.encode(triggerSnoozeThresholdEnabled, forKey: .triggerSnoozeThresholdEnabled)
        try container.encode(max(100, emergencyCancellationTapTarget), forKey: .emergencyCancellationTapTarget)
        try container.encode(min(20, max(1, lowBatteryExemptThresholdPercent)), forKey: .lowBatteryExemptThresholdPercent)
        try container.encode(autoApproveFirstViolation, forKey: .autoApproveFirstViolation)
        try container.encode(autoApproveLowBattery, forKey: .autoApproveLowBattery)
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
    case forceClose
    case uninstallTamper
    case forcedRestart
    case airplaneModeAbuse
    case severeBatteryDrain
    case snoozeThresholdExceeded
    case alarmMissionFailed
}

enum AlarmMissionStatus: String, Codable {
    case inProgress
    case completed
}

enum AlarmSessionStatus: String, Codable {
    case idle
    case ringing
    case snoozed
    case missionInProgress
    case completed
    case failed
}

enum ViolationStatus: String, Codable, Equatable {
    case pendingGracePeriod
    case pendingReview
    case excused
    case charged
    case paymentFailed
}

enum ExemptionStatus: String, Codable, Equatable {
    case pending
    case approved
    case denied
}

enum ViolationConfidence: String, Codable, Equatable {
    case low
    case medium
    case high
}

struct ExemptionRequest: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var violationId: UUID?
    var date: Date = Date()
    var reasonCategory: String
    var reasonText: String?
    var status: ExemptionStatus = .pending
    var decisionAt: Date?
    var decisionNote: String?
}

struct PenaltyTransaction: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var violationId: UUID?
    var date: Date = Date()
    var amountEuro: Int
    var success: Bool
    var transactionReference: String?
    var failureReason: String?
}

struct ViolationEvent: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var type: AlarmViolationType
    var timestamp: Date = Date()
    var chargedAmount: Int
    var status: ViolationStatus = .pendingGracePeriod
    var gracePeriodExpiresAt: Date?
    var exemptionRequestId: UUID?
    var confidence: ViolationConfidence = .medium
    var evidence: String?
    var chargeAttempts: Int = 0
    var lastChargeAttemptAt: Date?
    var transactionId: UUID?

    private enum CodingKeys: String, CodingKey {
        case id, type, timestamp, chargedAmount, status, gracePeriodExpiresAt, exemptionRequestId
        case confidence, evidence, chargeAttempts, lastChargeAttemptAt, transactionId
    }

    init(
        id: UUID = UUID(),
        type: AlarmViolationType,
        timestamp: Date = Date(),
        chargedAmount: Int,
        status: ViolationStatus = .pendingGracePeriod,
        gracePeriodExpiresAt: Date? = nil,
        exemptionRequestId: UUID? = nil,
        confidence: ViolationConfidence = .medium,
        evidence: String? = nil,
        chargeAttempts: Int = 0,
        lastChargeAttemptAt: Date? = nil,
        transactionId: UUID? = nil
    ) {
        self.id = id
        self.type = type
        self.timestamp = timestamp
        self.chargedAmount = chargedAmount
        self.status = status
        self.gracePeriodExpiresAt = gracePeriodExpiresAt
        self.exemptionRequestId = exemptionRequestId
        self.confidence = confidence
        self.evidence = evidence
        self.chargeAttempts = chargeAttempts
        self.lastChargeAttemptAt = lastChargeAttemptAt
        self.transactionId = transactionId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.type = try container.decode(AlarmViolationType.self, forKey: .type)
        self.timestamp = try container.decodeIfPresent(Date.self, forKey: .timestamp) ?? Date()
        self.chargedAmount = try container.decodeIfPresent(Int.self, forKey: .chargedAmount) ?? 0
        self.status = try container.decodeIfPresent(ViolationStatus.self, forKey: .status) ?? .pendingGracePeriod
        self.gracePeriodExpiresAt = try container.decodeIfPresent(Date.self, forKey: .gracePeriodExpiresAt)
        self.exemptionRequestId = try container.decodeIfPresent(UUID.self, forKey: .exemptionRequestId)
        self.confidence = try container.decodeIfPresent(ViolationConfidence.self, forKey: .confidence) ?? .medium
        self.evidence = try container.decodeIfPresent(String.self, forKey: .evidence)
        self.chargeAttempts = try container.decodeIfPresent(Int.self, forKey: .chargeAttempts) ?? 0
        self.lastChargeAttemptAt = try container.decodeIfPresent(Date.self, forKey: .lastChargeAttemptAt)
        self.transactionId = try container.decodeIfPresent(UUID.self, forKey: .transactionId)
    }
}

struct AlarmSession: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var alarmId: UUID
    var startedAt: Date = Date()
    var isActive: Bool = true
    var penaltyEnabled: Bool = true
    var snoozeCount: Int = 0
    var hasMissions: Bool = false
    var missionStatus: AlarmMissionStatus = .inProgress
    var status: AlarmSessionStatus = .ringing
    var lastHeartbeatAt: Date = Date()
    var endedAt: Date?
    var endReason: String?
    var airplaneEmergencyActive: Bool = false
    var emergencyTapCount: Int = 0
    var emergencyTapTarget: Int = 500
    var startedBatteryLevel: Float?
    var lastBatteryLevel: Float?
    var violations: [ViolationEvent] = []

    private enum CodingKeys: String, CodingKey {
        case id, alarmId, startedAt, isActive, penaltyEnabled, snoozeCount
        case hasMissions, missionStatus, status, lastHeartbeatAt, endedAt, endReason
        case airplaneEmergencyActive, emergencyTapCount, emergencyTapTarget
        case startedBatteryLevel, lastBatteryLevel, violations
    }

    init(
        id: UUID = UUID(),
        alarmId: UUID,
        startedAt: Date = Date(),
        isActive: Bool = true,
        penaltyEnabled: Bool = true,
        snoozeCount: Int = 0,
        hasMissions: Bool = false,
        missionStatus: AlarmMissionStatus = .inProgress,
        status: AlarmSessionStatus = .ringing,
        lastHeartbeatAt: Date = Date(),
        endedAt: Date? = nil,
        endReason: String? = nil,
        airplaneEmergencyActive: Bool = false,
        emergencyTapCount: Int = 0,
        emergencyTapTarget: Int = 500,
        startedBatteryLevel: Float? = nil,
        lastBatteryLevel: Float? = nil,
        violations: [ViolationEvent] = []
    ) {
        self.id = id
        self.alarmId = alarmId
        self.startedAt = startedAt
        self.isActive = isActive
        self.penaltyEnabled = penaltyEnabled
        self.snoozeCount = snoozeCount
        self.hasMissions = hasMissions
        self.missionStatus = missionStatus
        self.status = status
        self.lastHeartbeatAt = lastHeartbeatAt
        self.endedAt = endedAt
        self.endReason = endReason
        self.airplaneEmergencyActive = airplaneEmergencyActive
        self.emergencyTapCount = emergencyTapCount
        self.emergencyTapTarget = max(100, emergencyTapTarget)
        self.startedBatteryLevel = startedBatteryLevel
        self.lastBatteryLevel = lastBatteryLevel
        self.violations = violations
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.alarmId = try container.decode(UUID.self, forKey: .alarmId)
        self.startedAt = try container.decodeIfPresent(Date.self, forKey: .startedAt) ?? Date()
        self.isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        self.penaltyEnabled = try container.decodeIfPresent(Bool.self, forKey: .penaltyEnabled) ?? true
        self.snoozeCount = try container.decodeIfPresent(Int.self, forKey: .snoozeCount) ?? 0
        self.hasMissions = try container.decodeIfPresent(Bool.self, forKey: .hasMissions) ?? false
        self.missionStatus = try container.decodeIfPresent(AlarmMissionStatus.self, forKey: .missionStatus) ?? .inProgress
        self.status = try container.decodeIfPresent(AlarmSessionStatus.self, forKey: .status) ?? .ringing
        self.lastHeartbeatAt = try container.decodeIfPresent(Date.self, forKey: .lastHeartbeatAt) ?? Date()
        self.endedAt = try container.decodeIfPresent(Date.self, forKey: .endedAt)
        self.endReason = try container.decodeIfPresent(String.self, forKey: .endReason)
        self.airplaneEmergencyActive = try container.decodeIfPresent(Bool.self, forKey: .airplaneEmergencyActive) ?? false
        self.emergencyTapCount = try container.decodeIfPresent(Int.self, forKey: .emergencyTapCount) ?? 0
        self.emergencyTapTarget = max(100, try container.decodeIfPresent(Int.self, forKey: .emergencyTapTarget) ?? 500)
        self.startedBatteryLevel = try container.decodeIfPresent(Float.self, forKey: .startedBatteryLevel)
        self.lastBatteryLevel = try container.decodeIfPresent(Float.self, forKey: .lastBatteryLevel)
        self.violations = try container.decodeIfPresent([ViolationEvent].self, forKey: .violations) ?? []
    }
}
