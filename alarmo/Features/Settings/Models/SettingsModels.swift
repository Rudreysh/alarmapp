import Foundation
import SwiftUI

enum ThemeMode: String, Codable, CaseIterable {
    case dark = "Dark"
    case light = "Light"
    case system = "Follow system setting"
    
    var colorScheme: ColorScheme? {
        switch self {
        case .dark: return .dark
        case .light: return .light
        case .system: return nil
        }
    }
}

enum SoundOutputMode: String, Codable, CaseIterable {
    case currentDevice = "Current device"
    case externalPreferred = "Connected external speaker"
}

struct CheatEvent: Codable, Identifiable {
    let id: UUID
    let date: Date
    let reason: CheatReason
    
    init(id: UUID = UUID(), date: Date = Date(), reason: CheatReason) {
        self.id = id
        self.date = date
        self.reason = reason
    }
}

enum CheatReason: String, Codable {
    case appKilled = "App force-killed during mission"
    case backgrounded = "App backgrounded during mission"
    case missionSkipped = "Mission skipped illegally"
}

struct PenaltyRecord: Codable, Identifiable {
    let id: UUID
    let date: Date
    let amountCents: Int
    let status: PenaltyStatus
    let cheatEventId: UUID
    
    init(id: UUID = UUID(), date: Date = Date(), amountCents: Int, status: PenaltyStatus, cheatEventId: UUID) {
        self.id = id
        self.date = date
        self.amountCents = amountCents
        self.status = status
        self.cheatEventId = cheatEventId
    }
}

enum PenaltyStatus: String, Codable {
    case pending
    case paid
}

enum PenaltyCurrency: String, Codable, CaseIterable {
    case eur = "EUR"
    case usd = "USD"
    case gbp = "GBP"
    case inr = "INR"
    
    var symbol: String {
        switch self {
        case .eur: return "€"
        case .usd: return "$"
        case .gbp: return "£"
        case .inr: return "₹"
        }
    }
}

struct AccountabilityAuditEvent: Codable, Identifiable {
    let id: UUID
    let date: Date
    let eventType: PenaltyEventType
    let amountEuro: Int
    let sourceAlarmId: UUID?
    let sourceFocusTaskId: UUID?
    let note: String?
    
    init(
        id: UUID = UUID(),
        date: Date = Date(),
        eventType: PenaltyEventType,
        amountEuro: Int,
        sourceAlarmId: UUID? = nil,
        sourceFocusTaskId: UUID? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.date = date
        self.eventType = eventType
        self.amountEuro = amountEuro
        self.sourceAlarmId = sourceAlarmId
        self.sourceFocusTaskId = sourceFocusTaskId
        self.note = note
    }
}

struct NotificationFeaturePrefs: Codable {
    var enabled: Bool = true
    var cadence: AppNotificationCadence = .smart
    var maxPerDay: Int = 3

    init(enabled: Bool = true, cadence: AppNotificationCadence = .smart, maxPerDay: Int = 3) {
        self.enabled = enabled
        self.cadence = cadence
        self.maxPerDay = max(1, maxPerDay)
    }

    enum CodingKeys: String, CodingKey {
        case enabled
        case cadence
        case maxPerDay
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        cadence = try container.decodeIfPresent(AppNotificationCadence.self, forKey: .cadence) ?? .smart
        maxPerDay = max(1, try container.decodeIfPresent(Int.self, forKey: .maxPerDay) ?? 3)
    }
}

struct NotificationQuietHoursPrefs: Codable {
    var enabled: Bool = false
    var startHour: Int = 22
    var endHour: Int = 7
    var allowTimeSensitive: Bool = true

    init(
        enabled: Bool = false,
        startHour: Int = 22,
        endHour: Int = 7,
        allowTimeSensitive: Bool = true
    ) {
        self.enabled = enabled
        self.startHour = min(23, max(0, startHour))
        self.endHour = min(23, max(0, endHour))
        self.allowTimeSensitive = allowTimeSensitive
    }

    enum CodingKeys: String, CodingKey {
        case enabled
        case startHour
        case endHour
        case allowTimeSensitive
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
        startHour = min(23, max(0, try container.decodeIfPresent(Int.self, forKey: .startHour) ?? 22))
        endHour = min(23, max(0, try container.decodeIfPresent(Int.self, forKey: .endHour) ?? 7))
        allowTimeSensitive = try container.decodeIfPresent(Bool.self, forKey: .allowTimeSensitive) ?? true
    }
}

struct AlarmNotificationRulesPrefs: Codable {
    var tomorrowCheckEnabled: Bool = true
    var bedtimeReminderEnabled: Bool = true
    var missedAlarmFollowUpEnabled: Bool = true
    var upcomingAlarmWarningEnabled: Bool = false
    var upcomingAlarmLeadMinutes: Int = 15

    init() {}

    enum CodingKeys: String, CodingKey {
        case tomorrowCheckEnabled
        case bedtimeReminderEnabled
        case missedAlarmFollowUpEnabled
        case upcomingAlarmWarningEnabled
        case upcomingAlarmLeadMinutes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tomorrowCheckEnabled = try container.decodeIfPresent(Bool.self, forKey: .tomorrowCheckEnabled) ?? true
        bedtimeReminderEnabled = try container.decodeIfPresent(Bool.self, forKey: .bedtimeReminderEnabled) ?? true
        missedAlarmFollowUpEnabled = try container.decodeIfPresent(Bool.self, forKey: .missedAlarmFollowUpEnabled) ?? true
        upcomingAlarmWarningEnabled = try container.decodeIfPresent(Bool.self, forKey: .upcomingAlarmWarningEnabled) ?? false
        upcomingAlarmLeadMinutes = max(1, min(120, try container.decodeIfPresent(Int.self, forKey: .upcomingAlarmLeadMinutes) ?? 15))
    }
}

struct NotificationPrefs: Codable {
    var weatherEnabled: Bool = false
    var alarmReminderEnabled: Bool = false
    var newsEnabled: Bool = true
    var eventEnabled: Bool = true
    var quietHours: NotificationQuietHoursPrefs = NotificationQuietHoursPrefs()
    var weekendDigestOnly: Bool = false
    var alarm: NotificationFeaturePrefs = NotificationFeaturePrefs(enabled: true, cadence: .smart, maxPerDay: 6)
    var habits: NotificationFeaturePrefs = NotificationFeaturePrefs(enabled: true, cadence: .smart, maxPerDay: 4)
    var tasks: NotificationFeaturePrefs = NotificationFeaturePrefs(enabled: true, cadence: .smart, maxPerDay: 6)
    var pomodoro: NotificationFeaturePrefs = NotificationFeaturePrefs(enabled: true, cadence: .smart, maxPerDay: 8)
    var stopwatch: NotificationFeaturePrefs = NotificationFeaturePrefs(enabled: false, cadence: .off, maxPerDay: 3)
    var accountability: NotificationFeaturePrefs = NotificationFeaturePrefs(enabled: true, cadence: .smart, maxPerDay: 6)
    var marketing: NotificationFeaturePrefs = NotificationFeaturePrefs(enabled: false, cadence: .off, maxPerDay: 1)
    var alarmRules: AlarmNotificationRulesPrefs = AlarmNotificationRulesPrefs()

    enum CodingKeys: String, CodingKey {
        case weatherEnabled
        case alarmReminderEnabled
        case newsEnabled
        case eventEnabled
        case quietHours
        case weekendDigestOnly
        case alarm
        case habits
        case tasks
        case pomodoro
        case stopwatch
        case accountability
        case marketing
        case alarmRules
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        weatherEnabled = try container.decodeIfPresent(Bool.self, forKey: .weatherEnabled) ?? false
        alarmReminderEnabled = try container.decodeIfPresent(Bool.self, forKey: .alarmReminderEnabled) ?? false
        newsEnabled = try container.decodeIfPresent(Bool.self, forKey: .newsEnabled) ?? true
        eventEnabled = try container.decodeIfPresent(Bool.self, forKey: .eventEnabled) ?? true
        quietHours = try container.decodeIfPresent(NotificationQuietHoursPrefs.self, forKey: .quietHours) ?? NotificationQuietHoursPrefs()
        weekendDigestOnly = try container.decodeIfPresent(Bool.self, forKey: .weekendDigestOnly) ?? false
        alarm = try container.decodeIfPresent(NotificationFeaturePrefs.self, forKey: .alarm) ?? NotificationFeaturePrefs(enabled: true, cadence: .smart, maxPerDay: 6)
        habits = try container.decodeIfPresent(NotificationFeaturePrefs.self, forKey: .habits) ?? NotificationFeaturePrefs(enabled: true, cadence: .smart, maxPerDay: 4)
        tasks = try container.decodeIfPresent(NotificationFeaturePrefs.self, forKey: .tasks) ?? NotificationFeaturePrefs(enabled: true, cadence: .smart, maxPerDay: 6)
        pomodoro = try container.decodeIfPresent(NotificationFeaturePrefs.self, forKey: .pomodoro) ?? NotificationFeaturePrefs(enabled: true, cadence: .smart, maxPerDay: 8)
        stopwatch = try container.decodeIfPresent(NotificationFeaturePrefs.self, forKey: .stopwatch) ?? NotificationFeaturePrefs(enabled: false, cadence: .off, maxPerDay: 3)
        accountability = try container.decodeIfPresent(NotificationFeaturePrefs.self, forKey: .accountability) ?? NotificationFeaturePrefs(enabled: true, cadence: .smart, maxPerDay: 6)
        marketing = try container.decodeIfPresent(NotificationFeaturePrefs.self, forKey: .marketing) ?? NotificationFeaturePrefs(enabled: false, cadence: .off, maxPerDay: 1)
        alarmRules = try container.decodeIfPresent(AlarmNotificationRulesPrefs.self, forKey: .alarmRules) ?? AlarmNotificationRulesPrefs()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(weatherEnabled, forKey: .weatherEnabled)
        try container.encode(alarmReminderEnabled, forKey: .alarmReminderEnabled)
        try container.encode(newsEnabled, forKey: .newsEnabled)
        try container.encode(eventEnabled, forKey: .eventEnabled)
        try container.encode(quietHours, forKey: .quietHours)
        try container.encode(weekendDigestOnly, forKey: .weekendDigestOnly)
        try container.encode(alarm, forKey: .alarm)
        try container.encode(habits, forKey: .habits)
        try container.encode(tasks, forKey: .tasks)
        try container.encode(pomodoro, forKey: .pomodoro)
        try container.encode(stopwatch, forKey: .stopwatch)
        try container.encode(accountability, forKey: .accountability)
        try container.encode(marketing, forKey: .marketing)
        try container.encode(alarmRules, forKey: .alarmRules)
    }
}

struct LanguageOption: Identifiable, Hashable {
    let id: String
    let name: String
    let displayName: String
}
