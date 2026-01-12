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
            LinearGradient(colors: [Colors.sheetGradientTop, Colors.sheetGradientBottom], startPoint: .top, endPoint: .bottom)
        )
        .cornerRadius(30, corners: [.topLeft, .topRight])
    }
}
