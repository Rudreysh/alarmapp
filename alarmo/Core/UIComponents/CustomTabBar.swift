import SwiftUI

struct CustomTabBar<Tab: Hashable>: View {
    let tabs: [TabBarItem<Tab>]
    @Binding var selected: Tab

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Colors.cardStroke)
                .frame(height: 1)

            let totalWidth = UIScreen.main.bounds.width
            let itemWidth = totalWidth / CGFloat(tabs.count)
            let _ = print("TabBar Layout (Fixed): TotalWidth=\(totalWidth), ItemWidth=\(itemWidth), Selected=\(selected)")
            
            HStack(spacing: 0) {
                ForEach(tabs) { item in
                    Button(action: { selected = item.id }) {
                        VStack(spacing: 4) {
                            Image(systemName: item.systemImage)
                                .font(.system(size: 20, weight: .semibold))
                                .frame(width: 28, height: 28)
                            Text(item.title)
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(selected == item.id ? Colors.textPrimary : Colors.tabBarInactive)
                        .frame(width: itemWidth, height: AppConstants.tabBarHeight - 36) // Adjust for padding
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(item.title))
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .frame(height: AppConstants.tabBarHeight, alignment: .top)
        .background(Colors.tabBarBackground)
    }
}

struct TabBarItem<Tab: Hashable>: Identifiable {
    let id: Tab
    let title: String
    let systemImage: String
}
