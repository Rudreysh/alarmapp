import SwiftUI

struct PageDots: View {
    let count: Int
    let activeIndex: Int

    var body: some View {
        HStack(spacing: Spacing.s) {
            ForEach(0..<count, id: \.self) { index in
                Circle()
                    .fill(index == activeIndex ? Colors.textPrimary : Colors.textTertiary)
                    .frame(width: index == activeIndex ? 8 : 6, height: index == activeIndex ? 8 : 6)
            }
        }
        .accessibilityHidden(true)
    }
}
