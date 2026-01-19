import SwiftUI

struct ProgressHeader: View {
    let step: Int
    let total: Int

    var body: some View {
        HStack(spacing: Spacing.s) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Colors.textTertiary.opacity(0.4))
                        .frame(height: 3)
                    Capsule()
                        .fill(Colors.textPrimary)
                        .frame(width: proxy.size.width * progress, height: 3)
                }
            }
            .frame(height: 3)

            Text("\(step)/\(total)")
                .captionText()
                .foregroundColor(Colors.textSecondary)
        }
    }

    private var progress: CGFloat {
        guard total > 0 else { return 0 }
        return CGFloat(step) / CGFloat(total)
    }
}
