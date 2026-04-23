import SwiftUI
import SwiftData

struct TimerRootView: View {
    @StateObject private var viewModel: TimerViewModel
    @StateObject private var stopwatchEngine: StopwatchEngine
    @StateObject private var multiTimerStore: MultiTimerStore
    @StateObject private var countdownStore: CountdownPresetStore
    @StateObject private var countdownEngine: CountdownEngine
    @EnvironmentObject var taskStore: TaskStore
    @EnvironmentObject var pomodoroEngine: PomodoroEngine
    @EnvironmentObject var navStore: NavigationStore
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @State private var hasTriggeredSwipeClose = false
    let preferences: AppPreferences
    let onClose: () -> Void

    private var isLightMode: Bool {
        colorScheme == .light
    }
    
    init(preferences: AppPreferences = AppPreferences(), onClose: @escaping () -> Void) {
        self.preferences = preferences
        self.onClose = onClose
        self._viewModel = StateObject(wrappedValue: TimerViewModel(preferences: preferences))
        self._stopwatchEngine = StateObject(wrappedValue: StopwatchEngine(preferences: preferences))
        self._multiTimerStore = StateObject(wrappedValue: MultiTimerStore())
        let presetStore = CountdownPresetStore()
        self._countdownStore = StateObject(wrappedValue: presetStore)
        self._countdownEngine = StateObject(
            wrappedValue: CountdownEngine(preset: presetStore.presets.first ?? CountdownPreset.defaults[0])
        )
        // Taskstore and Engine are now environment
    }
    
    var body: some View {
        ZStack {
            TimerGlassBackground()
            
            VStack(spacing: 0) {
                // Header row + mode row
                VStack(spacing: 10) {
                    timerHeaderBar
                        .padding(.horizontal, Spacing.l)
                    modeSelector
                        .padding(.horizontal, Spacing.m)
                }
                .padding(.top, Spacing.m)
                
                // Content
                Group {
                    if viewModel.selectedMode == .pomo {
                        PomoTimerView(viewModel: viewModel, engine: pomodoroEngine)
                            .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .trailing)))
                    } else if viewModel.selectedMode == .stopwatch {
                        StopwatchView(
                            viewModel: viewModel,
                            preferences: preferences,
                            swEngine: stopwatchEngine,
                            multiStore: multiTimerStore
                        )
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                    } else {
                        CountdownPresetView(store: countdownStore, engine: countdownEngine)
                            .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .clipped()
            }
            .padding(.bottom, AppConstants.tabBarHeight)
        }
        .onAppear {
            bindStopwatchLifecycle()
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
        .onDisappear {
            viewModel.stopTimer()
        }
        .onReceive(navStore.$requestedTimerMode) { _ in
            handleNavigationRequest()
        }
        .simultaneousGesture(closeSwipeGesture)
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

    private var modeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TimerMode.allCases) { mode in
                    let isSelected = viewModel.selectedMode == mode
                    Text(mode.rawValue)
                        .font(.system(size: 14, weight: .bold))
                        .lineLimit(1)
                        .foregroundColor(isSelected ? .white : Colors.textSecondary)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                        .frame(width: modeTabWidth(for: mode))
                        .background(Capsule().fill(modeFillGradient(isSelected: isSelected)))
                        .overlay(
                            Capsule()
                                .stroke(modeStrokeColor(isSelected: isSelected), lineWidth: 1)
                        )
                        .clipShape(Capsule())
                        .onTapGesture {
                            withAnimation(.spring()) {
                                if viewModel.selectedMode == .countdown && mode != .countdown {
                                    countdownEngine.pause()
                                }
                                viewModel.selectedMode = mode
                                viewModel.stopTimer()
                            }
                        }
                }
            }
            .padding(2)
            .padding(.trailing, 6)
        }
        .scrollClipDisabled()
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 42)
        .background(
            Capsule()
                .fill(modeContainerGradient)
        )
        .overlay(
            Capsule()
                .stroke(isLightMode ? Colors.cardStroke.opacity(0.95) : Color.white.opacity(0.10), lineWidth: 1)
        )
        .clipShape(Capsule())
    }

    private var timerHeaderBar: some View {
        HStack {
            closeButton
            Spacer()
            Text("Timer")
                .font(.headline)
                .foregroundColor(Colors.textPrimary)
            Spacer()
            headerMenuButton
        }
    }

    private func modeTabWidth(for mode: TimerMode) -> CGFloat {
        switch mode {
        case .pomo, .stopwatch:
            return 104
        case .countdown:
            return 124
        }
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Colors.textPrimary)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(isLightMode ? Color.black.opacity(0.10) : Color.white.opacity(0.16))
                )
                .overlay(
                    Circle()
                        .stroke(isLightMode ? Colors.cardStroke.opacity(0.95) : Color.white.opacity(0.20), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Close timer"))
    }

    private var headerMenuButton: some View {
        Button(action: { viewModel.showFocusSettings = true }) {
            Image(systemName: "ellipsis")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Colors.textPrimary)
                .frame(width: 40, height: 40)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Timer settings"))
    }

    private var modeContainerGradient: LinearGradient {
        LinearGradient(
            colors: [
                isLightMode ? Color.white.opacity(0.98) : Color(red: 0.12, green: 0.15, blue: 0.20).opacity(0.92),
                isLightMode ? Color(red: 0.94, green: 0.95, blue: 0.98).opacity(0.98) : Color(red: 0.09, green: 0.12, blue: 0.17).opacity(0.92)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func modeFillGradient(isSelected: Bool) -> LinearGradient {
        if isSelected {
            return LinearGradient(
                colors: [TimerPalette.accent, TimerPalette.accent.opacity(0.78)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        return LinearGradient(
            colors: [
                isLightMode ? Color(red: 0.93, green: 0.94, blue: 0.97) : Color.white.opacity(0.06),
                isLightMode ? Color(red: 0.88, green: 0.90, blue: 0.94) : Color.white.opacity(0.03)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func modeStrokeColor(isSelected: Bool) -> Color {
        if isSelected {
            return TimerPalette.accent.opacity(0.85)
        }

        return isLightMode ? Colors.cardStroke : Color.white.opacity(0.10)
    }

    private var closeSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 18)
            .onChanged { value in
                let startedNearTop = value.startLocation.y <= 140
                let verticalDistance = value.translation.height
                let horizontalDrift = abs(value.translation.width)
                guard startedNearTop,
                      verticalDistance > 120,
                      horizontalDrift < 90,
                      !hasTriggeredSwipeClose else { return }
                hasTriggeredSwipeClose = true
                onClose()
            }
            .onEnded { _ in
                hasTriggeredSwipeClose = false
            }
    }

    private func bindStopwatchLifecycle() {
        stopwatchEngine.onSessionStarted = { startedAt in
            let event = ActivityEvent(
                domain: .stopwatch,
                entityId: UUID(),
                timestampUTC: startedAt,
                status: .started
            )
            modelContext.insert(event)
            try? modelContext.save()
        }

        stopwatchEngine.onSessionCompleted = { elapsed, session in
            PointsService.shared.stopwatchSessionCompleted(
                durationSeconds: Int(elapsed),
                sessionLabel: session.label
            )

            let event = ActivityEvent(
                domain: .stopwatch,
                entityId: session.id,
                timestampUTC: session.endedAt,
                status: .completed,
                value: elapsed,
                metadata: [
                    "lapCount": "\(session.lapCount)"
                ]
            )
            modelContext.insert(event)
            try? modelContext.save()
        }
    }
}
