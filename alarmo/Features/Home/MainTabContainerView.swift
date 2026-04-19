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
                    SettingsRootView(preferences: preferences)
                }
            }

            CustomTabBar(
                tabs: [
                    TabBarItem(id: MainTab.alarm, title: "Alarm", systemImage: "alarm"),
                    TabBarItem(id: MainTab.timer, title: "Timer", systemImage: "timer"),
                    TabBarItem(id: MainTab.plan, title: "Habit", systemImage: "calendar"),
                    TabBarItem(id: MainTab.overlap, title: "Overlap", systemImage: "globe.americas"),
                    TabBarItem(id: MainTab.report, title: "Report", systemImage: "doc.text"),
                    TabBarItem(id: MainTab.setting, title: "Setting", systemImage: "gearshape")
                ],
                selected: $navStore.selectedTab
            )
        }
        .ignoresSafeArea(edges: .bottom)
        .onAppear {
            PointsService.shared.checkDailyLogin()
            bindPomodoroLifecycle()
        }
    }

    private func bindPomodoroLifecycle() {
        pomodoroEngine.onSegmentStarted = { taskId, segment, durationSeconds in
            guard segment == .focus else { return }
            let event = ActivityEvent(
                domain: .pomodoro,
                entityId: taskId ?? UUID(),
                status: .started,
                value: Double(durationSeconds)
            )
            modelContext.insert(event)
            try? modelContext.save()
        }

        pomodoroEngine.onSegmentInterrupted = { taskId, segment, elapsedSeconds in
            guard segment == .focus else { return }

            let itemName = taskId.flatMap { fetchPlanItem(id: $0)?.title }
            PointsService.shared.pomodoroSessionEnded(
                taskId: taskId,
                taskName: itemName,
                durationSeconds: elapsedSeconds,
                interrupted: true
            )

            let event = ActivityEvent(
                domain: .pomodoro,
                entityId: taskId ?? UUID(),
                status: .interrupted,
                value: Double(elapsedSeconds)
            )
            modelContext.insert(event)
            try? modelContext.save()
        }

        pomodoroEngine.onSessionComplete = { taskId, segment, durationSeconds, wasSkipped in
            guard segment == .focus else { return }

            let linkedItem = taskId.flatMap { fetchPlanItem(id: $0) }
            let itemName = linkedItem?.title

            PointsService.shared.pomodoroSessionEnded(
                taskId: taskId,
                taskName: itemName,
                durationSeconds: durationSeconds,
                interrupted: wasSkipped
            )

            let eventStatus: ActivityStatus = wasSkipped ? .interrupted : .completed
            let event = ActivityEvent(
                domain: .pomodoro,
                entityId: taskId ?? UUID(),
                status: eventStatus,
                value: Double(durationSeconds),
                metadata: taskId == nil ? ["session": "unlinked"] : nil
            )
            modelContext.insert(event)

            guard let linkedItem, !wasSkipped else {
                try? modelContext.save()
                return
            }

            let calendar = Calendar.current
            if let existingLog = linkedItem.completionLogs.first(where: { calendar.isDateInToday($0.date) }) {
                existingLog.durationSeconds = (existingLog.durationSeconds ?? 0) + durationSeconds
                existingLog.completed = linkedItem.isGoalMet()
            } else {
                let log = CompletionLog(date: Date(), completed: false)
                log.durationSeconds = durationSeconds
                linkedItem.completionLogs.append(log)
                log.completed = linkedItem.isGoalMet()
            }

            try? modelContext.save()
        }
    }

    private func fetchPlanItem(id: UUID) -> PlanItem? {
        let descriptor = FetchDescriptor<PlanItem>(predicate: #Predicate<PlanItem> { item in
            item.id == id
        })
        return try? modelContext.fetch(descriptor).first
    }
}
