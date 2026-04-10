import SwiftUI

/// Renders long quotes in a bounded number of lines without truncation by adapting font size.
struct AdaptiveQuoteText: View {
    let quote: String
    let maxWidth: CGFloat
    let maxLines: Int
    let maxFontSize: CGFloat
    let minFontSize: CGFloat
    let weight: Font.Weight
    let truncateToMaxLines: Bool

    init(
        quote: String,
        maxWidth: CGFloat,
        maxLines: Int = 3,
        maxFontSize: CGFloat = 24,
        minFontSize: CGFloat = 14,
        weight: Font.Weight = .medium,
        truncateToMaxLines: Bool = false
    ) {
        self.quote = quote
        self.maxWidth = maxWidth
        self.maxLines = maxLines
        self.maxFontSize = maxFontSize
        self.minFontSize = minFontSize
        self.weight = weight
        self.truncateToMaxLines = truncateToMaxLines
    }

    var body: some View {
        Text("\"\(quote)\"")
            .font(.system(size: estimatedFontSize, weight: weight, design: .serif))
            .italic()
            .multilineTextAlignment(.center)
            .lineLimit(truncateToMaxLines ? maxLines : nil)
            .truncationMode(.tail)
            .minimumScaleFactor(0.75)
            .allowsTightening(true)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 6)
            .frame(maxWidth: maxWidth, alignment: .center)
            .layoutPriority(1)
    }

    private var estimatedFontSize: CGFloat {
        let normalizedCount = max(quote.trimmingCharacters(in: .whitespacesAndNewlines).count, 1)
        let suggestedLines: Int
        switch normalizedCount {
        case ..<55: suggestedLines = 2
        case ..<85: suggestedLines = 3
        case ..<115: suggestedLines = 4
        case ..<145: suggestedLines = 5
        default: suggestedLines = 6
        }
        let lines = CGFloat(max(1, truncateToMaxLines ? maxLines : max(maxLines, suggestedLines)))
        let availableWidth = max(maxWidth, 40)

        // Conservative estimate to keep text inside 2-3 lines without clipping.
        let estimatedCharacterWidthFactor: CGFloat = 0.60
        let estimated = (availableWidth * lines) / (CGFloat(normalizedCount) * estimatedCharacterWidthFactor)

        return min(max(estimated, minFontSize), maxFontSize)
    }
}
