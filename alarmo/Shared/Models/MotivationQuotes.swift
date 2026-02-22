import Foundation

struct MotivationQuote: Identifiable {
    let id = UUID()
    let text: String
    let author: String
}

struct MotivationQuotes {
    static let all: [MotivationQuote] = [
        MotivationQuote(text: "The only way to do great work is to love what you do.", author: "Steve Jobs"),
        MotivationQuote(text: "Your time is limited, so don't waste it living someone else's life.", author: "Steve Jobs"),
        MotivationQuote(text: "The best way to get started is to quit talking and begin doing.", author: "Walt Disney"),
        MotivationQuote(text: "Don't let yesterday take up too much of today.", author: "Will Rogers"),
        MotivationQuote(text: "You learn more from failure than from success. Don't let it stop you.", author: "Unknown"),
        MotivationQuote(text: "It’s not whether you get knocked down, it’s whether you get up.", author: "Vince Lombardi"),
        MotivationQuote(text: "If you are working on something that you really care about, you don’t have to be pushed. The vision pulls you.", author: "Steve Jobs"),
        MotivationQuote(text: "People who are crazy enough to think they can change the world, are the ones who do.", author: "Rob Siltanen"),
        MotivationQuote(text: "Failure will never overtake me if my determination to succeed is strong enough.", author: "Og Mandino"),
        MotivationQuote(text: "Knowing is not enough; we must apply. Wishing is not enough; we must do.", author: "Johann Wolfgang Von Goethe"),
        MotivationQuote(text: "We generate fears while we sit. We overcome them by action.", author: "Dr. Henry Link"),
        MotivationQuote(text: "Whether you think you can or you think you can’t, you’re right.", author: "Henry Ford"),
        MotivationQuote(text: "Security is mostly a superstition. Life is either a daring adventure or nothing.", author: "Helen Keller"),
        MotivationQuote(text: "The only limit to our realization of tomorrow will be our doubts of today.", author: "Franklin D. Roosevelt"),
        MotivationQuote(text: "Creativity is intelligence having fun.", author: "Albert Einstein"),
        MotivationQuote(text: "What you lack in talent can be made up with desire, hustle and giving 110% all the time.", author: "Don Zimmer"),
        MotivationQuote(text: "Do what you can with all you have, wherever you are.", author: "Theodore Roosevelt"),
        MotivationQuote(text: "Develop an 'Attitude of Gratitude'. Say thank you to everyone you meet for everything they do for you.", author: "Brian Tracy"),
        MotivationQuote(text: "You are never too old to set another goal or to dream a new dream.", author: "C.S. Lewis"),
        MotivationQuote(text: "To see what is right and not do it is a lack of courage.", author: "Confucius"),
        MotivationQuote(text: "Reading is to the mind what exercise is to the body.", author: "Joseph Addison"),
        MotivationQuote(text: "Fake it until you make it! Act as if you had all the confidence you require until it becomes your reality.", author: "Brian Tracy"),
        MotivationQuote(text: "The future belongs to the competent. Get good, get better, be the best!", author: "Brian Tracy"),
        MotivationQuote(text: "For every reason it’s not possible, there are hundreds of people who have faced the same circumstances and succeeded.", author: "Jack Canfield"),
        MotivationQuote(text: "Things work out best for those who make the best of how things work out.", author: "John Wooden"),
        MotivationQuote(text: "A room without books is like a body without a soul.", author: "Marcus Tullius Cicero"),
        MotivationQuote(text: "I think goals should never be easy, they should force you to work, even if they are uncomfortable at the time.", author: "Michael Phelps"),
        MotivationQuote(text: "The only way to achieve the impossible is to believe it is possible.", author: "Charles Kingsleigh"),
        MotivationQuote(text: "Success is walking from failure to failure with no loss of enthusiasm.", author: "Winston Churchill"),
        MotivationQuote(text: "Just when the caterpillar thought the world was ending, he turned into a butterfly.", author: "Proverb")
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
}
