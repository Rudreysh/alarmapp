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
        static let accountabilityEnabled = "settings.accountabilityEnabled"
        static let enforcementMode = "settings.enforcementMode"
        static let blockAppsEnabled = "settings.blockAppsEnabled"
        static let blockedAppsSelectionData = "settings.blockedAppsSelectionData"
        static let blockedMockAppsData = "settings.blockedMockAppsData"
        static let blockedMockCategoriesData = "settings.blockedMockCategoriesData"
        static let selectedBlockListId = "settings.selectedBlockListId"
        static let penaltyEnabled = "settings.penaltyEnabled"
        static let penaltyAmountEuro = "settings.penaltyAmountEuro"
        static let penaltyCreditsBalance = "settings.penaltyCreditsBalance"
        static let penaltyRules = "settings.penaltyRules"
        static let lastPenaltyEventAt = "settings.lastPenaltyEventAt"
        static let accountabilityAuditEvents = "settings.accountabilityAuditEvents"
        static let potentialTimeTamperEvents = "settings.potentialTimeTamperEvents"
        static let penaltyCurrency = "settings.penaltyCurrency"
        static let activeAlarmSession = "settings.activeAlarmSession"
        static let violations = "settings.violations"
        static let exemptionRequests = "settings.exemptionRequests"
        static let penaltyTransactions = "settings.penaltyTransactions"
        static let penaltyPaymentToken = "settings.penaltyPaymentToken"
        static let penaltyCardBrand = "settings.penaltyCardBrand"
        static let penaltyCardLast4 = "settings.penaltyCardLast4"
        static let penaltyTermsAccepted = "settings.penaltyTermsAccepted"
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
    @AppStorage(Keys.accountabilityEnabled) var accountabilityEnabled: Bool = false
    @AppStorage(Keys.enforcementMode) var enforcementModeRaw: String = EnforcementMode.none.rawValue
    @AppStorage(Keys.blockAppsEnabled) var blockAppsEnabled: Bool = false
    @AppStorage(Keys.blockedAppsSelectionData) var blockedAppsSelectionData: Data = Data()
    @AppStorage(Keys.blockedMockAppsData) var blockedMockAppsData: Data = Data()
    @AppStorage(Keys.blockedMockCategoriesData) var blockedMockCategoriesData: Data = Data()
    @AppStorage(Keys.selectedBlockListId) var selectedBlockListId: String = ""
    @AppStorage(Keys.penaltyEnabled) var penaltyEnabled: Bool = false
    @AppStorage(Keys.penaltyAmountEuro) var penaltyAmountEuro: Int = 1
    @AppStorage(Keys.penaltyCreditsBalance) var penaltyCreditsBalance: Int = 0
    @AppStorage(Keys.lastPenaltyEventAt) var lastPenaltyEventAt: Double = 0
    @AppStorage(Keys.penaltyCurrency) var penaltyCurrencyRaw: String = PenaltyCurrency.eur.rawValue
    @AppStorage(Keys.penaltyPaymentToken) var penaltyPaymentToken: String = ""
    @AppStorage(Keys.penaltyCardBrand) var penaltyCardBrand: String = ""
    @AppStorage(Keys.penaltyCardLast4) var penaltyCardLast4: String = ""
    @AppStorage(Keys.penaltyTermsAccepted) var penaltyTermsAccepted: Bool = false
    
    @Published var notificationPrefs: NotificationPrefs {
        didSet { saveComplexToDefaults(notificationPrefs, key: Keys.notificationPrefs) }
    }
    
    @Published var cheatEvents: [CheatEvent] = [] {
        didSet { saveComplexToDefaults(cheatEvents, key: Keys.cheatEvents) }
    }
    
    @Published var penaltyRecords: [PenaltyRecord] = [] {
        didSet { saveComplexToDefaults(penaltyRecords, key: Keys.penaltyRecords) }
    }
    
    @Published var penaltyRules: PenaltyRules {
        didSet { saveComplexToDefaults(penaltyRules, key: Keys.penaltyRules) }
    }
    
    @Published var accountabilityAuditEvents: [AccountabilityAuditEvent] = [] {
        didSet { saveComplexToDefaults(accountabilityAuditEvents, key: Keys.accountabilityAuditEvents) }
    }
    
    @Published var potentialTimeTamperEvents: [Date] = [] {
        didSet { saveComplexToDefaults(potentialTimeTamperEvents, key: Keys.potentialTimeTamperEvents) }
    }

    @Published var activeAlarmSession: AlarmSession? {
        didSet { saveComplexToDefaults(activeAlarmSession, key: Keys.activeAlarmSession) }
    }
    
    @Published var violations: [ViolationEvent] = [] {
        didSet { saveComplexToDefaults(violations, key: Keys.violations) }
    }

    @Published var exemptionRequests: [ExemptionRequest] = [] {
        didSet { saveComplexToDefaults(exemptionRequests, key: Keys.exemptionRequests) }
    }

    @Published var penaltyTransactions: [PenaltyTransaction] = [] {
        didSet { saveComplexToDefaults(penaltyTransactions, key: Keys.penaltyTransactions) }
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
        self.penaltyRules = Self.loadComplexFromDefaults(PenaltyRules.self, key: Keys.penaltyRules) ?? .default
        self.accountabilityAuditEvents = Self.loadComplexFromDefaults([AccountabilityAuditEvent].self, key: Keys.accountabilityAuditEvents) ?? []
        self.potentialTimeTamperEvents = Self.loadComplexFromDefaults([Date].self, key: Keys.potentialTimeTamperEvents) ?? []
        self.activeAlarmSession = Self.loadComplexFromDefaults(AlarmSession.self, key: Keys.activeAlarmSession)
        self.violations = Self.loadComplexFromDefaults([ViolationEvent].self, key: Keys.violations) ?? []
        self.exemptionRequests = Self.loadComplexFromDefaults([ExemptionRequest].self, key: Keys.exemptionRequests) ?? []
        self.penaltyTransactions = Self.loadComplexFromDefaults([PenaltyTransaction].self, key: Keys.penaltyTransactions) ?? []
        
        if preventPowerOffEnabled && !accountabilityEnabled {
            accountabilityEnabled = true
        }
        if preventPowerOffEnabled {
            penaltyRules.triggerShutdownAttemptEnabled = true
        }
        if perCheatAmountCents > 0 && penaltyAmountEuro == 1 {
            penaltyAmountEuro = min(10, max(1, perCheatAmountCents / 100))
        }
    }

    var enforcementMode: EnforcementMode {
        get { EnforcementMode(rawValue: enforcementModeRaw) ?? .none }
        set { enforcementModeRaw = newValue.rawValue }
    }
    
    var penaltyCurrency: PenaltyCurrency {
        get { PenaltyCurrency(rawValue: penaltyCurrencyRaw) ?? .eur }
        set { penaltyCurrencyRaw = newValue.rawValue }
    }

    var triggerShutdownAttemptEnabled: Bool {
        get { penaltyRules.triggerShutdownAttemptEnabled }
        set {
            penaltyRules.triggerShutdownAttemptEnabled = newValue
            preventPowerOffEnabled = newValue
        }
    }

    var triggerUninstallTamperEnabled: Bool {
        get { penaltyRules.triggerUninstallTamperEnabled }
        set { penaltyRules.triggerUninstallTamperEnabled = newValue }
    }

    var triggerSnoozeThresholdEnabled: Bool {
        get { penaltyRules.triggerSnoozeThresholdEnabled }
        set { penaltyRules.triggerSnoozeThresholdEnabled = newValue }
    }

    var snoozePenaltyThreshold: Int {
        get { penaltyRules.alarmSnoozeThreshold }
        set { penaltyRules.alarmSnoozeThreshold = min(10, max(1, newValue)) }
    }

    var blockedMockApps: [String] {
        get { (try? JSONDecoder().decode([String].self, from: blockedMockAppsData)) ?? [] }
        set { blockedMockAppsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var blockedMockCategories: [String] {
        get { (try? JSONDecoder().decode([String].self, from: blockedMockCategoriesData)) ?? [] }
        set { blockedMockCategoriesData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var lastPenaltyDate: Date? {
        guard lastPenaltyEventAt > 0 else { return nil }
        return Date(timeIntervalSince1970: lastPenaltyEventAt)
    }

    func appendPenaltyAudit(_ event: AccountabilityAuditEvent) {
        accountabilityAuditEvents.append(event)
        lastPenaltyEventAt = event.date.timeIntervalSince1970
    }

    func markPotentialTimeTamper() {
        potentialTimeTamperEvents.append(Date())
    }

    var hasValidPenaltyPaymentMethod: Bool {
        isPenaltyPaymentConnected && !penaltyPaymentToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
