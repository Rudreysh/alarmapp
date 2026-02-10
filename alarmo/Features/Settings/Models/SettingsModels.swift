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

struct NotificationPrefs: Codable {
    var weatherEnabled: Bool = false
    var alarmReminderEnabled: Bool = false
    var newsEnabled: Bool = true
    var eventEnabled: Bool = true
}

struct LanguageOption: Identifiable, Hashable {
    let id: String
    let name: String
    let displayName: String
}
