import SwiftUI

struct Card<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(Spacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Colors.cardSurface)
            .overlay(
                RoundedRectangle(cornerRadius: Radii.card)
                    .stroke(Colors.cardStroke, lineWidth: 1)
            )
            .cornerRadius(Radii.card)
            .appShadow(Shadows.card)
    }
}
