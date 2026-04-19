import SwiftUI

struct DailyInsightCard: View {
    @State private var currentInsight: DailyInsight

    init() {
        _currentInsight = State(initialValue: DailyInsightsStore.shared.randomInsight())
    }

    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                currentInsight = DailyInsightsStore.shared.randomInsight(excluding: currentInsight.id)
            }
        }) {
            HStack(spacing: Spacing.m) {
                Image(systemName: symbol(for: currentInsight))
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(Colors.accentTeal)
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Daily Insight")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Colors.accentTeal)
                        .textCase(.uppercase)

                    Text(currentInsight.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Colors.textPrimary)

                    Text(currentInsight.description)
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
                    .stroke(Colors.accentTeal.opacity(0.15), lineWidth: 1)
            )
            .appShadow(Shadows.card)
        }
        .buttonStyle(PressedScaleButtonStyle())
        .accessibilityLabel(Text(currentInsight.title))
    }

    private func symbol(for insight: DailyInsight) -> String {
        let source = "\(insight.title) \(insight.description)".lowercased()
        if source.contains("sleep") || source.contains("melatonin") || source.contains("night") {
            return "moon.stars.fill"
        }
        if source.contains("light") || source.contains("sun") || source.contains("morning") {
            return "sun.max.fill"
        }
        if source.contains("focus") || source.contains("attention") {
            return "scope"
        }
        if source.contains("memory") || source.contains("brain") || source.contains("neural") {
            return "brain.head.profile"
        }
        if source.contains("emotion") || source.contains("mood") || source.contains("serotonin") {
            return "heart.text.square.fill"
        }
        return "sparkles"
    }
}
