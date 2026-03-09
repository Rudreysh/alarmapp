import SwiftUI
import SwiftData

enum MainTab: String, CaseIterable {
    case alarm
    case timer
    case plan
    case overlap
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
                case .plan:
                    PlanView(preferences: preferences)
                case .overlap:
                    OverlapView(preferences: preferences)
                case .report:
                    ReportView(modelContext: modelContext, alarmStore: alarmStore)
                case .setting:
                    SettingsRootView()
                }
            }

            CustomTabBar(
                tabs: [
                    TabBarItem(id: MainTab.alarm, title: "Alarm", systemImage: "alarm"),
                    TabBarItem(id: MainTab.timer, title: "Timer", systemImage: "timer"),
                    TabBarItem(id: MainTab.plan, title: "Plan", systemImage: "calendar"),
                    TabBarItem(id: MainTab.overlap, title: "Overlap", systemImage: "globe.americas"),
                    TabBarItem(id: MainTab.report, title: "Report", systemImage: "doc.text"),
                    TabBarItem(id: MainTab.setting, title: "Setting", systemImage: "gearshape")
                ],
                selected: $navStore.selectedTab
            )
        }
        .ignoresSafeArea(edges: .bottom)
        .onAppear {
            // Daily login points check
            PointsService.shared.checkDailyLogin()
            
            pomodoroEngine.onSessionComplete = { taskId, segment, duration in
                guard segment == .focus, let taskId = taskId else { return }
                
                // Award focus points regardless of task linkage
                PointsService.shared.focusSessionEnded(
                    taskId: taskId,
                    taskName: nil,
                    durationSeconds: duration,
                    wasSkipped: false
                )
                
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
                    
                    let event = ActivityEvent(
                        domain: .task,
                        entityId: item.id,
                        status: .success,
                        value: Double(duration),
                        metadata: ["type": "pomodoro"]
                    )
                    modelContext.insert(event)
                    try? modelContext.save()
                    
                    // Update task name for focus points
                    print("✅ Updated progress for \(item.title): +\(duration)s")
                }
            }
        }
    }
}
