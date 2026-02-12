import SwiftUI

struct TimerRootView: View {
    @StateObject private var viewModel: TimerViewModel
    @EnvironmentObject var taskStore: TaskStore
    @EnvironmentObject var pomodoroEngine: PomodoroEngine
    @EnvironmentObject var navStore: NavigationStore
    let preferences: AppPreferences
    let onClose: () -> Void
    @State private var showQuickActions = false
    
    init(preferences: AppPreferences = AppPreferences(), onClose: @escaping () -> Void) {
        self.preferences = preferences
        self.onClose = onClose
        self._viewModel = StateObject(wrappedValue: TimerViewModel(preferences: preferences))
        // Taskstore and Engine are now environment
    }
    
    var body: some View {
        ZStack {
            TimerGlassBackground()
            
            VStack(spacing: 0) {
                // Toolbar
                HStack {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(Colors.textPrimary)
                    }
                    
                    Spacer()
                    
                    // Segmented Control
                    HStack(spacing: 0) {
                        ForEach(TimerMode.allCases) { mode in
                            Text(mode.rawValue)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(viewModel.selectedMode == mode ? Colors.textPrimary : Colors.textSecondary)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .background(
                                    Group {
                                        if viewModel.selectedMode == mode {
                                            Capsule()
                                                .fill(
                                                    LinearGradient(
                                                        colors: [
                                                            Color(red: 0.18, green: 0.21, blue: 0.28).opacity(0.95),
                                                            Color(red: 0.12, green: 0.15, blue: 0.21).opacity(0.95)
                                                        ],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                        } else {
                                            Color.clear
                                        }
                                    }
                                )
                                .clipShape(Capsule())
                                .onTapGesture {
                                    withAnimation(.spring()) {
                                        viewModel.selectedMode = mode
                                        viewModel.stopTimer()
                                    }
                                }
                        }
                    }
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.12, green: 0.15, blue: 0.20).opacity(0.92),
                                        Color(red: 0.09, green: 0.12, blue: 0.17).opacity(0.92)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
                    .clipShape(Capsule())
                    
                    Spacer()
                    
                    HStack(spacing: 16) {
                        Button(action: { print("History tapped") }) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 20))
                                .foregroundColor(Colors.textPrimary)
                        }
                        
                        Button(action: toggleQuickActionsMenu) {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 20))
                                .foregroundColor(Colors.textPrimary)
                        }
                    }
                }
                .padding(.horizontal, Spacing.l)
                .padding(.top, Spacing.m)
                
                // Content
                if viewModel.selectedMode == .pomo {
                    PomoTimerView(viewModel: viewModel, engine: pomodoroEngine)
                        .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .trailing)))
                } else {
                    StopwatchView(viewModel: viewModel)
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                }
            }
            .padding(.bottom, AppConstants.tabBarHeight)

            if showQuickActions {
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture {
                        closeQuickActionsMenu()
                    }

                VStack {
                    HStack {
                        Spacer()
                        VStack(spacing: 0) {
                            quickActionRow(icon: "slider.horizontal.3", title: "Focus Settings") {
                                viewModel.showFocusSettings = true
                            }
                            Divider().background(Colors.cardStroke)
                            quickActionRow(icon: "list.bullet.rectangle", title: "Add Record") {
                                viewModel.showAddFocusRecord = true
                            }
                            Divider().background(Colors.cardStroke)
                            quickActionRow(icon: "plus", title: "Add Timer") {
                                viewModel.showAddTimer = true
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.white.opacity(0.10))
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.24), Color.white.opacity(0.10)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: Color.black.opacity(0.26), radius: 12, x: 0, y: 8)
                        .frame(width: 220)
                    }
                    .padding(.top, 62)
                    .padding(.trailing, Spacing.l)
                    Spacer()
                }
            }
        }
        .sheet(isPresented: $viewModel.showPomoDurationPicker) {
            PomoDurationPickerSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showFocusSettings) {
            FocusSettingsView(preferences: preferences)
        }
        .sheet(isPresented: $viewModel.showAddFocusRecord) {
            AddFocusRecordView()
        }
        .sheet(isPresented: $viewModel.showAddTimer) {
            DetailedNewTaskView(onTaskCreated: {
                if let selectedTask = taskStore.selectedTask {
                    // Update Engine with new task settings
                    pomodoroEngine.apply(task: selectedTask)
                    
                    // Update UI state
                    viewModel.selectedFocusMode = selectedTask.name
                    if selectedTask.isIntervalTimer {
                        viewModel.selectedMode = .pomo
                        viewModel.pomoDurationSeconds = TimeInterval(selectedTask.focusDurationMinutes * 60)
                        viewModel.pomoRemainingSeconds = TimeInterval(selectedTask.focusDurationMinutes * 60)
                    }
                    // If not interval timer, it could be a simple task or meant for stopwatch?
                    // For now, default to Pomo/Focus behavior but following the config.
                    
                    viewModel.stopTimer()
                    pomodoroEngine.stop(reset: true)
                }
            })
        }
        .sheet(isPresented: $viewModel.showFocusNoteSheet) {
            FocusNoteSheet(viewModel: viewModel)
        }
        .onAppear {
            handleNavigationRequest()
        }
        .onReceive(navStore.$requestedTimerMode) { _ in
            handleNavigationRequest()
        }
    }
    
    private func handleNavigationRequest() {
        if let requested = navStore.requestedTimerMode {
            withAnimation(.spring()) {
                viewModel.selectedMode = requested
            }
            // Clear the request
            navStore.requestedTimerMode = nil
        }
    }

    private func toggleQuickActionsMenu() {
        withTransaction(Transaction(animation: nil)) {
            showQuickActions.toggle()
        }
    }

    private func closeQuickActionsMenu() {
        withTransaction(Transaction(animation: nil)) {
            showQuickActions = false
        }
    }

    private func quickActionRow(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            closeQuickActionsMenu()
            action()
        }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 28, height: 28)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Colors.textPrimary)
                }
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Colors.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 14)
            .frame(height: 50)
        }
        .buttonStyle(.plain)
    }
}
