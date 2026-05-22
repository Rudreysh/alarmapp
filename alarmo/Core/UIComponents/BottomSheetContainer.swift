import SwiftUI

struct BottomSheetContainer<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .padding(.top, Spacing.l)
        .padding(.bottom, Spacing.xl)
        .padding(.horizontal, Spacing.l)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.12, blue: 0.22),
                    Color(red: 0.03, green: 0.07, blue: 0.14),
                    Color(red: 0.02, green: 0.04, blue: 0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(30, corners: [.topLeft, .topRight])
    }
}
