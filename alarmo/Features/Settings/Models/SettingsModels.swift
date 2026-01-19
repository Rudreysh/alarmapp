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
