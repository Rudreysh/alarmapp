import Foundation
import SwiftUI

enum PhraseCategory: String, Codable, CaseIterable, Identifiable {
    case short = "Short"
    case selfAffirmation = "Self-Affirmation"
    case motivational = "Motivational"
    case difficult = "Difficult"
    case myPhrases = "My Phrases"
    
    var id: String { self.rawValue }
}

struct Phrase: Identifiable, Codable, Equatable {
    let id: UUID
    var text: String
    var category: PhraseCategory
    var isUserCreated: Bool
    
    init(id: UUID = UUID(), text: String, category: PhraseCategory, isUserCreated: Bool = false) {
        self.id = id
        self.text = text
        self.category = category
        self.isUserCreated = isUserCreated
    }
}

struct TypingSettings: Codable {
    var repeatCount: Int = 1
    var selectedPhraseIDs: Set<UUID> = []
    var soundEnabled: Bool = true
    
    // Default phrases to ensure it's never empty
    static let defaultPhrases: [Phrase] = [
        Phrase(text: "Keep going", category: .short),
        Phrase(text: "Stay brave", category: .short),
        Phrase(text: "Dream big", category: .short),
        Phrase(text: "You got this", category: .short),
        Phrase(text: "Shine today", category: .short),
        Phrase(text: "Stay strong", category: .short),
        Phrase(text: "Choose joy", category: .short),
        Phrase(text: "Rise and shine", category: .short),
        Phrase(text: "Be fearless", category: .short),
        
        Phrase(text: "My life is a gift.", category: .selfAffirmation),
        Phrase(text: "I am delighted to be alive.", category: .selfAffirmation),
        Phrase(text: "I receive love and happiness.", category: .selfAffirmation),
        Phrase(text: "I am happy, joyful, and free.", category: .selfAffirmation),
        
        Phrase(text: "Work hard in silence, let your success be your noise.", category: .motivational),
        Phrase(text: "Don't expect everyone to understand your journey, especially...", category: .motivational),
        
        Phrase(text: "Peter Piper picked a peck of pickled peppers.", category: .difficult),
        Phrase(text: "I scream, you scream, we all scream for ice cream.", category: .difficult),
        Phrase(text: "I saw Susie sitting in a shoeshine shop.", category: .difficult)
    ]
}
