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
}

struct PenaltyRules: Codable, Equatable {
    var focusEarlyStopTriggersPenalty: Bool = true
    var focusOverrideTriggersPenalty: Bool = true
    var alarmSnoozeThreshold: Int = 3
    var alarmMissionTimeoutSeconds: Int = 180
    var alarmMissionFailTriggersPenalty: Bool = false

    static let `default` = PenaltyRules()
}

struct PenaltyEventRecord: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var date: Date = Date()
    var eventType: PenaltyEventType
    var amountEuro: Int
    var sourceId: UUID?
    var note: String?
}
