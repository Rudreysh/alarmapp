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
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: symbol(for: currentInsight))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Colors.accentTeal)
                        .frame(width: 24, height: 24)
                        .background(Colors.accentTeal.opacity(0.12))
                        .clipShape(Circle())

                    Text("Daily Insight")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Colors.accentTeal)
                        .textCase(.uppercase)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Colors.textSecondary.opacity(0.6))
                }

                Text(currentInsight.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(currentInsight.description)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(Colors.textSecondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
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
