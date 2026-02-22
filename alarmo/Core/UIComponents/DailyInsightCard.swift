
import SwiftUI

struct DailyInsightCard: View {
    @State private var currentTip: Tip
    
    init() {
        _currentTip = State(initialValue: Self.tips.randomElement()!)
    }
    
    // Simple Tip Model
    struct Tip {
        let icon: String
        let title: String
        let subtitle: String
        let action: () -> Void
    }
    
    // Static collection of tips
    static let tips: [Tip] = [
        Tip(icon: "moon.stars.fill", title: "Sleep Consistency", subtitle: "Go to bed at the same time every night.", action: {}),
        Tip(icon: "cup.and.saucer.fill", title: "Caffeine Cutoff", subtitle: "Avoid caffeine 6 hours before bed.", action: {}),
        Tip(icon: "sun.max.fill", title: "Get Sunlight", subtitle: "Direct sunlight in the morning resets your rhythm.", action: {}),
        Tip(icon: "book.fill", title: "Read, Don't Scroll", subtitle: "Reading reduces stress by 68% before bed.", action: {}),
        Tip(icon: "drop.fill", title: "Hydrate First", subtitle: "Drink water immediately after waking up.", action: {}),
        Tip(icon: "brain.head.profile", title: "Brain Dump", subtitle: "Write down worries before sleeping.", action: {})
    ]

    var body: some View {
        Button(action: {
            // Cycle to next tip on tap for demo purposes
            withAnimation {
                if let index = Self.tips.firstIndex(where: { $0.title == currentTip.title }) {
                    let nextIndex = (index + 1) % Self.tips.count
                    currentTip = Self.tips[nextIndex]
                }
            }
        }) {
            HStack(spacing: Spacing.m) {
                Image(systemName: currentTip.icon)
                    .font(.system(size: 26, weight: .semibold)) // Slightly smaller than 28
                    .foregroundColor(Colors.accentTeal) // Use accent color
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Daily Insight") // Consistent header like "Tip of the Day"
                        .font(.system(size: 11, weight: .bold)) // Uppercase/small
                        .foregroundColor(Colors.accentTeal)
                        .textCase(.uppercase)
                    
                    Text(currentTip.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Colors.textPrimary)
                    
                    Text(currentTip.subtitle)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(Colors.textSecondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.9)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Colors.textSecondary.opacity(0.5))
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .background(Colors.promoCardBackground)
            .cornerRadius(22)
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Colors.accentTeal.opacity(0.15), lineWidth: 1) // Subtle border
            )
            .appShadow(Shadows.card)
        }
        .buttonStyle(PressedScaleButtonStyle())
        .accessibilityLabel(Text(currentTip.title))
    }
}
