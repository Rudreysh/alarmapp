import Foundation
import SwiftUI
import Combine

class SettingsStore: ObservableObject {
    static let shared = SettingsStore()
    
    // User Defaults Keys
    private enum Keys {
        static let isSignedIn = "settings.isSignedIn"
        static let appleUserId = "settings.appleUserId"
        static let points = "settings.points"
        static let themeMode = "settings.themeMode"
        static let soundOutputMode = "settings.soundOutputMode"
        static let missionTimeLimitSeconds = "settings.missionTimeLimitSeconds"
        static let preventPowerOffEnabled = "settings.preventPowerOffEnabled"
        static let perCheatAmountCents = "settings.perCheatAmountCents"
        static let isPenaltyPaymentConnected = "settings.isPenaltyPaymentConnected"
        static let cheatEvents = "settings.cheatEvents"
        static let penaltyRecords = "settings.penaltyRecords"
        static let notificationPrefs = "settings.notificationPrefs"
        static let batterySavingMode = "settings.batterySavingMode"
        static let selectedLanguage = "settings.selectedLanguage"
    }
    
    @AppStorage(Keys.isSignedIn) var isSignedIn: Bool = false
    @AppStorage(Keys.appleUserId) var appleUserId: String = ""
    @AppStorage(Keys.points) var points: Int = 13
    
    @Published var themeMode: ThemeMode {
        didSet { saveToDefaults(themeMode, key: Keys.themeMode) }
    }
    
    @Published var soundOutputMode: SoundOutputMode {
        didSet { saveToDefaults(soundOutputMode, key: Keys.soundOutputMode) }
    }
    
    @AppStorage(Keys.missionTimeLimitSeconds) var missionTimeLimitSeconds: Int = 20
    @AppStorage(Keys.preventPowerOffEnabled) var preventPowerOffEnabled: Bool = false
    @AppStorage(Keys.perCheatAmountCents) var perCheatAmountCents: Int = 100
    @AppStorage(Keys.isPenaltyPaymentConnected) var isPenaltyPaymentConnected: Bool = false
    
    @AppStorage(Keys.batterySavingMode) var batterySavingMode: Bool = false
    @AppStorage(Keys.selectedLanguage) var selectedLanguage: String = "system"
    
    @Published var notificationPrefs: NotificationPrefs {
        didSet { saveComplexToDefaults(notificationPrefs, key: Keys.notificationPrefs) }
    }
    
    @Published var cheatEvents: [CheatEvent] = [] {
        didSet { saveComplexToDefaults(cheatEvents, key: Keys.cheatEvents) }
    }
    
    @Published var penaltyRecords: [PenaltyRecord] = [] {
        didSet { saveComplexToDefaults(penaltyRecords, key: Keys.penaltyRecords) }
    }
    
    var missionTimeLimitLabel: String {
        if missionTimeLimitSeconds == 20 {
            return "20 sec (Default)"
        }
        return "\(missionTimeLimitSeconds) sec"
    }
    
    private init() {
        print("[SettingsStore] Initializing...")
        // Load complex types from Defaults
        self.themeMode = Self.loadFromDefaults(ThemeMode.self, key: Keys.themeMode) ?? .dark
        self.soundOutputMode = Self.loadFromDefaults(SoundOutputMode.self, key: Keys.soundOutputMode) ?? .currentDevice
        self.notificationPrefs = Self.loadComplexFromDefaults(NotificationPrefs.self, key: Keys.notificationPrefs) ?? NotificationPrefs()
        self.cheatEvents = Self.loadComplexFromDefaults([CheatEvent].self, key: Keys.cheatEvents) ?? []
        self.penaltyRecords = Self.loadComplexFromDefaults([PenaltyRecord].self, key: Keys.penaltyRecords) ?? []
    }
    
    // Persistence Helpers
    private func saveToDefaults<T: RawRepresentable>(_ value: T, key: String) where T.RawValue == String {
        UserDefaults.standard.set(value.rawValue, forKey: key)
    }
    
    private static func loadFromDefaults<T: RawRepresentable>(_ type: T.Type, key: String) -> T? where T.RawValue == String {
        guard let rawValue = UserDefaults.standard.string(forKey: key) else { return nil }
        return T(rawValue: rawValue)
    }
    
    private func saveComplexToDefaults<T: Encodable>(_ value: T, key: String) {
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    private static func loadComplexFromDefaults<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
