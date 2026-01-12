import SwiftUI

enum MainTab: String, CaseIterable {
    case alarm
    case sleep
    case morning
    case report
    case setting
}

struct MainTabContainerView: View {
    @State private var selectedTab: MainTab = .alarm
    @ObservedObject var preferences: AppPreferences
    @ObservedObject var alarmStore: AlarmStore

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .alarm:
                    HomeView(viewModel: HomeViewModel(preferences: preferences), alarmStore: alarmStore)
                case .sleep:
                    PlaceholderTabView(title: "Sleep")
                case .morning:
                    PlaceholderTabView(title: "Morning")
                case .report:
                    PlaceholderTabView(title: "Report")
                case .setting:
                    PlaceholderTabView(title: "Setting")
                }
            }

            CustomTabBar(
                tabs: [
                    TabBarItem(id: MainTab.alarm, title: "Alarm", systemImage: "alarm"),
                    TabBarItem(id: MainTab.sleep, title: "Sleep", systemImage: "moon.zzz"),
                    TabBarItem(id: MainTab.morning, title: "Morning", systemImage: "sun.max"),
                    TabBarItem(id: MainTab.report, title: "Report", systemImage: "doc.text"),
                    TabBarItem(id: MainTab.setting, title: "Setting", systemImage: "gearshape")
                ],
                selected: $selectedTab
            )
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

private struct PlaceholderTabView: View {
    let title: String

    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()
            Text(title)
                .screenTitle()
                .foregroundColor(Colors.textPrimary)
        }
    }
}
