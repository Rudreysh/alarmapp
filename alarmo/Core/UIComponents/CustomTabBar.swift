import SwiftUI

struct CustomTabBar<Tab: Hashable>: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var settingsStore = SettingsStore.shared
    let tabs: [TabBarItem<Tab>]
    @Binding var selected: Tab
    
    private var isTiimo: Bool {
        settingsStore.alarmThemeStyle == .tiimo
    }

    private var isLightMode: Bool {
        switch settingsStore.themeMode {
        case .light:
            return true
        case .dark:
            return false
        case .system:
            return colorScheme == .light
        }
    }
    
    private var tabBackground: Color {
        isTiimo ? Color.white : (isLightMode ? Color.white : Colors.tabBarBackground)
    }
    
    private var selectedTextColor: Color {
        isTiimo ? Color(hex: "#7F77DD") : (isLightMode ? Colors.textPrimary : Colors.textPrimary)
    }
    
    private var unselectedTextColor: Color {
        isTiimo ? Color(hex: "#B0AABF") : (isLightMode ? Colors.tabBarInactive : Colors.tabBarInactive)
    }

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(isTiimo ? Color(hex: "#F0EFFE") : Colors.cardStroke)
                .frame(height: isTiimo ? 0.5 : 1)

            let totalWidth = UIScreen.main.bounds.width
            let itemWidth = totalWidth / CGFloat(tabs.count)
            
            HStack(spacing: 0) {
                ForEach(tabs) { item in
                    Button(action: { selected = item.id }) {
                        VStack(spacing: 4) {
                            Image(systemName: item.systemImage)
                                .font(.system(size: 18, weight: .semibold))
                                .frame(width: 24, height: 24)
                            Text(item.title)
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundColor(selected == item.id ? selectedTextColor : unselectedTextColor)
                        .frame(width: itemWidth, height: AppConstants.tabBarHeight - 36)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(item.title))
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .frame(height: AppConstants.tabBarHeight, alignment: .top)
        .background(tabBackground)
    }
}

struct TabBarItem<Tab: Hashable>: Identifiable {
    let id: Tab
    let title: String
    let systemImage: String
}
