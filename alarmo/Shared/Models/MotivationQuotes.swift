import Foundation

enum MotivationQuoteCategory: String, CaseIterable {
    case admired
    case spiritual
    case religion
    case toughLove
    case shortDirect
    case wise

    static let allSelectionID = "all"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .admired: return "From people I admire"
        case .spiritual: return "Spiritual"
        case .religion: return "Religion"
        case .toughLove: return "Tough love"
        case .shortDirect: return "Short and to the point"
        case .wise: return "Thought-provoking and wise"
        }
    }
}

struct MotivationQuote: Identifiable {
    let id = UUID()
    let text: String
    let author: String
    let category: MotivationQuoteCategory
}

struct MotivationQuotes {
    static let all: [MotivationQuote] = [
        MotivationQuote(text: "The only way to do great work is to love what you do.", author: "Steve Jobs", category: .admired),
        MotivationQuote(text: "Your time is limited, so don't waste it living someone else's life.", author: "Steve Jobs", category: .admired),
        MotivationQuote(text: "The best way to get started is to quit talking and begin doing.", author: "Walt Disney", category: .admired),
        MotivationQuote(text: "Don't let yesterday take up too much of today.", author: "Will Rogers", category: .shortDirect),
        MotivationQuote(text: "You learn more from failure than from success. Don't let it stop you.", author: "Unknown", category: .toughLove),
        MotivationQuote(text: "It is not whether you get knocked down, it is whether you get up.", author: "Vince Lombardi", category: .toughLove),
        MotivationQuote(text: "If you are working on something that you really care about, you do not have to be pushed. The vision pulls you.", author: "Steve Jobs", category: .wise),
        MotivationQuote(text: "People who are crazy enough to think they can change the world are the ones who do.", author: "Rob Siltanen", category: .admired),
        MotivationQuote(text: "Failure will never overtake me if my determination to succeed is strong enough.", author: "Og Mandino", category: .toughLove),
        MotivationQuote(text: "Knowing is not enough; we must apply. Wishing is not enough; we must do.", author: "Johann Wolfgang Von Goethe", category: .wise),
        MotivationQuote(text: "We generate fears while we sit. We overcome them by action.", author: "Dr. Henry Link", category: .shortDirect),
        MotivationQuote(text: "Whether you think you can or you think you cannot, you are right.", author: "Henry Ford", category: .wise),
        MotivationQuote(text: "Security is mostly a superstition. Life is either a daring adventure or nothing.", author: "Helen Keller", category: .wise),
        MotivationQuote(text: "The only limit to our realization of tomorrow will be our doubts of today.", author: "Franklin D. Roosevelt", category: .wise),
        MotivationQuote(text: "Creativity is intelligence having fun.", author: "Albert Einstein", category: .shortDirect),
        MotivationQuote(text: "What you lack in talent can be made up with desire, hustle and giving 110 percent all the time.", author: "Don Zimmer", category: .toughLove),
        MotivationQuote(text: "Do what you can with all you have, wherever you are.", author: "Theodore Roosevelt", category: .shortDirect),
        MotivationQuote(text: "Develop an attitude of gratitude. Say thank you to everyone you meet for everything they do for you.", author: "Brian Tracy", category: .spiritual),
        MotivationQuote(text: "You are never too old to set another goal or to dream a new dream.", author: "C.S. Lewis", category: .religion),
        MotivationQuote(text: "To see what is right and not do it is a lack of courage.", author: "Confucius", category: .wise),
        MotivationQuote(text: "Reading is to the mind what exercise is to the body.", author: "Joseph Addison", category: .wise),
        MotivationQuote(text: "Fake it until you make it. Act as if you had all the confidence you require until it becomes your reality.", author: "Brian Tracy", category: .toughLove),
        MotivationQuote(text: "The future belongs to the competent. Get good, get better, be the best.", author: "Brian Tracy", category: .toughLove),
        MotivationQuote(text: "For every reason it is not possible, there are hundreds of people who have faced the same circumstances and succeeded.", author: "Jack Canfield", category: .wise),
        MotivationQuote(text: "Things work out best for those who make the best of how things work out.", author: "John Wooden", category: .spiritual),
        MotivationQuote(text: "A room without books is like a body without a soul.", author: "Marcus Tullius Cicero", category: .religion),
        MotivationQuote(text: "I think goals should never be easy. They should force you to work, even if they are uncomfortable at the time.", author: "Michael Phelps", category: .toughLove),
        MotivationQuote(text: "The only way to achieve the impossible is to believe it is possible.", author: "Charles Kingsleigh", category: .spiritual),
        MotivationQuote(text: "Success is walking from failure to failure with no loss of enthusiasm.", author: "Winston Churchill", category: .wise),
        MotivationQuote(text: "Just when the caterpillar thought the world was ending, he turned into a butterfly.", author: "Proverb", category: .spiritual)
    ]
    
    static func dailyQuotes() -> [MotivationQuote] {
        let calendar = Calendar.current
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: Date()) ?? 1
        
        // Select 3 deterministic "random" quotes for the day
        var selected: [MotivationQuote] = []
        let total = all.count
        
        // Use prime multipliers to scatter selection
        let seed1 = (dayOfYear * 7) % total
        let seed2 = (dayOfYear * 13 + 5) % total
        let seed3 = (dayOfYear * 19 + 11) % total
        
        selected.append(all[seed1])
        selected.append(all[seed2])
        selected.append(all[seed3])
        
        // Ensure uniqueness if small pool (fallback)
        if selected.count < 3 { return Array(all.prefix(3)) }
        
        return selected
    }

    static func filteredQuotes(for selectedCategoryIDs: Set<String>) -> [MotivationQuote] {
        if selectedCategoryIDs.contains(MotivationQuoteCategory.allSelectionID) || selectedCategoryIDs.isEmpty {
            return all
        }

        return all.filter { selectedCategoryIDs.contains($0.category.id) }
    }
}
