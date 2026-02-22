
import SwiftUI

struct MorningMotivationCard: View {
    @State private var currentQuote: Quote
    
    init() {
        _currentQuote = State(initialValue: Self.quotes.randomElement()!)
    }
    
    struct Quote {
        let text: String
        let author: String
    }
    
    static let quotes: [Quote] = [
        Quote(text: "The only way to do great work is to love what you do.", author: "Steve Jobs"),
        Quote(text: "Your time is limited, so don't waste it living someone else's life.", author: "Steve Jobs"),
        Quote(text: "The best way to get started is to quit talking and begin doing.", author: "Walt Disney"),
        Quote(text: "Don't let yesterday take up too much of today.", author: "Will Rogers"),
        Quote(text: "You learn more from failure than from success. Don't let it stop you.", author: "Unknown"),
        Quote(text: "It’s not whether you get knocked down, it’s whether you get up.", author: "Vince Lombardi"),
        Quote(text: "If you are working on something that you really care about, you don’t have to be pushed. The vision pulls you.", author: "Steve Jobs"),
        Quote(text: "People who are crazy enough to think they can change the world, are the ones who do.", author: "Rob Siltanen"),
        Quote(text: "Failure will never overtake me if my determination to succeed is strong enough.", author: "Og Mandino"),
        Quote(text: "Knowing is not enough; we must apply. Wishing is not enough; we must do.", author: "Johann Wolfgang Von Goethe"),
        Quote(text: "We generate fears while we sit. We overcome them by action.", author: "Dr. Henry Link"),
        Quote(text: "Whether you think you can or you think you can’t, you’re right.", author: "Henry Ford"),
        Quote(text: "Security is mostly a superstition. Life is either a daring adventure or nothing.", author: "Helen Keller"),
        Quote(text: "The only limit to our realization of tomorrow will be our doubts of today.", author: "Franklin D. Roosevelt"),
        Quote(text: "Creativity is intelligence having fun.", author: "Albert Einstein"),
        Quote(text: "What you lack in talent can be made up with desire, hustle and giving 110% all the time.", author: "Don Zimmer"),
        Quote(text: "Do what you can with all you have, wherever you are.", author: "Theodore Roosevelt")
    ]
    
    var body: some View {
        Button(action: {
            withAnimation {
                currentQuote = Self.quotes.randomElement()!
            }
        }) {
            HStack(spacing: 12) {
                Image(systemName: "quote.opening")
                    .font(.system(size: 14))
                    .foregroundColor(Colors.accentTeal.opacity(0.8))
                    .alignmentGuide(.firstTextBaseline) { d in d[.bottom] }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(currentQuote.text)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Colors.textPrimary.opacity(0.9))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true) // Allow wrapping
                    
                    Text("— " + currentQuote.author)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(Colors.textSecondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Colors.cardSurface.opacity(0.6))
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Colors.cardStroke.opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(PressedScaleButtonStyle())
    }
}
