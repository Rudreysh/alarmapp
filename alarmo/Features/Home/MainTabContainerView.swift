import SwiftUI
import SwiftData

enum MainTab: String, CaseIterable {
    case alarm
    case timer
    case sleep
    case plan
    case report
    case setting
}

struct MainTabContainerView: View {
    @EnvironmentObject var navStore: NavigationStore
    @ObservedObject var preferences: AppPreferences
    @ObservedObject var alarmStore: AlarmStore
    
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var pomodoroEngine: PomodoroEngine

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch navStore.selectedTab {
                case .alarm:
                    HomeView(viewModel: HomeViewModel(preferences: preferences), alarmStore: alarmStore)
                case .timer:
                    TimerRootView(preferences: preferences, onClose: { navStore.selectedTab = .alarm })
                case .sleep:
                    PlaceholderTabView(title: "Sleep")
                case .plan:
                    PlanView()
                case .report:
                    PlaceholderTabView(title: "Report")
                case .setting:
                    SettingsRootView()
                }
            }

            CustomTabBar(
                tabs: [
                    TabBarItem(id: MainTab.alarm, title: "Alarm", systemImage: "alarm"),
                    TabBarItem(id: MainTab.timer, title: "Timer", systemImage: "timer"),
                    TabBarItem(id: MainTab.sleep, title: "Sleep", systemImage: "moon.zzz"),
                    TabBarItem(id: MainTab.plan, title: "Plan", systemImage: "calendar"),
                    TabBarItem(id: MainTab.report, title: "Report", systemImage: "doc.text"),
                    TabBarItem(id: MainTab.setting, title: "Setting", systemImage: "gearshape")
                ],
                selected: $navStore.selectedTab
            )
        }
        .ignoresSafeArea(edges: .bottom)
        .onAppear {
            pomodoroEngine.onSessionComplete = { taskId, segment, duration in
                guard segment == .focus, let taskId = taskId else { return }
                
                // Fetch the plan item and update progress
                let descriptor = FetchDescriptor<PlanItem>(predicate: #Predicate<PlanItem> { item in
                    item.id == taskId
                })
                if let item = try? modelContext.fetch(descriptor).first {
                    let calendar = Calendar.current
                    if let existingLog = item.completionLogs.first(where: { calendar.isDateInToday($0.date) }) {
                        existingLog.durationSeconds = (existingLog.durationSeconds ?? 0) + duration
                        existingLog.completed = item.isGoalMet()
                    } else {
                        let log = CompletionLog(date: Date(), completed: false)
                        log.durationSeconds = duration
                        item.completionLogs.append(log)
                        log.completed = item.isGoalMet()
                    }
                    try? modelContext.save()
                    print("✅ Updated progress for \(item.title): +\(duration)s")
                }
            }
        }
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
