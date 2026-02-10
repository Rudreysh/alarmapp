import SwiftUI

struct CustomTabBar<Tab: Hashable>: View {
    let tabs: [TabBarItem<Tab>]
    @Binding var selected: Tab

    var body: some View {
        HStack(spacing: 6) {
            ForEach(tabs) { item in
                Button(action: { selected = item.id }) {
                    VStack(spacing: 4) {
                        Image(systemName: item.systemImage)
                            .font(.system(size: 20, weight: .semibold))
                        Text(item.title)
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(selected == item.id ? Colors.textPrimary : Colors.tabBarInactive)
                    .frame(maxWidth: .infinity)
                }
                .accessibilityLabel(Text(item.title))
            }
        }
        .padding(.top, Spacing.s)
        .padding(.bottom, Spacing.s)
        .background(Colors.tabBarBackground)
        .overlay(
            Rectangle()
                .fill(Colors.cardStroke)
                .frame(height: 1),
            alignment: .top
        )
    }
}

struct TabBarItem<Tab: Hashable>: Identifiable {
    let id: Tab
    let title: String
    let systemImage: String
}
