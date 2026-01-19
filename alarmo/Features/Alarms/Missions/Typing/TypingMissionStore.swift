import Foundation
import Combine

class TypingMissionStore: ObservableObject {
    static let shared = TypingMissionStore()
    
    @Published var allPhrases: [Phrase] = []
    @Published var userPhrases: [Phrase] = []
    
    private let userDefaults = UserDefaults.standard
    private let userPhrasesKey = "typing_user_phrases"
    private let settingsKeyPrefix = "typing_settings_"
    
    init() {
        loadUserPhrases()
        setupAllPhrases()
    }
    
    func setupAllPhrases() {
        var phrases = TypingSettings.defaultPhrases
        phrases.append(contentsOf: userPhrases)
        self.allPhrases = phrases
    }
    
    func loadUserPhrases() {
        if let data = userDefaults.data(forKey: userPhrasesKey),
           let decoded = try? JSONDecoder().decode([Phrase].self, from: data) {
            self.userPhrases = decoded
        }
    }
    
    func saveUserPhrase(_ text: String) {
        let newPhrase = Phrase(text: text, category: .myPhrases, isUserCreated: true)
        userPhrases.append(newPhrase)
        saveUserPhrases()
        setupAllPhrases()
        
        // Auto select the new phrase
        var settings = loadSettings(for: "default") // Or current ID
        settings.selectedPhraseIDs.insert(newPhrase.id)
        saveSettings(settings, for: "default")
    }
    
    private func saveUserPhrases() {
        if let encoded = try? JSONEncoder().encode(userPhrases) {
            userDefaults.set(encoded, forKey: userPhrasesKey)
        }
    }
    
    func loadSettings(for missionId: String) -> TypingSettings {
        let key = settingsKeyPrefix + missionId
        if let data = userDefaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode(TypingSettings.self, from: data) {
            // Ensure we have at least some phrases selected if the store has phrases
            var settings = decoded
            if settings.selectedPhraseIDs.isEmpty && !allPhrases.isEmpty {
                // Default to all Short phrases
                let shortIDs = allPhrases.filter { $0.category == .short }.map { $0.id }
                settings.selectedPhraseIDs = Set(shortIDs)
            }
            return settings
        }
        
        // Default settings
        let shortIDs = TypingSettings.defaultPhrases.filter { $0.category == .short }.map { $0.id }
        return TypingSettings(repeatCount: 1, selectedPhraseIDs: Set(shortIDs))
    }
    
    func saveSettings(_ settings: TypingSettings, for missionId: String) {
        let key = settingsKeyPrefix + missionId
        if let encoded = try? JSONEncoder().encode(settings) {
            userDefaults.set(encoded, forKey: key)
        }
    }
}
