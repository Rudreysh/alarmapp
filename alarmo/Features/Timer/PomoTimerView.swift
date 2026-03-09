import SwiftUI
import SwiftData

struct PomoTimerView: View {
    @ObservedObject var viewModel: TimerViewModel
    @ObservedObject var engine: PomodoroEngine
    @EnvironmentObject var taskStore: TaskStore
    @Environment(\.modelContext) var modelContext
    
    @Query(filter: #Predicate<PlanItem> { !$0.isArchived })
    var planItems: [PlanItem]
    
    @State private var showTaskSelection = false
    @State private var showIntervalSettings = false
    @State private var showTimerEditSheet = false
    @State private var editingSeconds: Int = 0
    @State private var showAppLists = false
    @State private var showDeepFocusConfirm = false
    
    // Timer Onboarding Sequence
    @State private var showTimerTimeIntegerCoachMark = false
    @State private var showTimerCircleCoachMark = false
    @State private var showTimerIntervalCoachMark = false
    @State private var showTimerMusicCoachMark = false
    @State private var showTimerBlockListCoachMark = false
    @State private var showTimerStartCoachMark = false
    
    @Query(sort: \AppList.updatedAt, order: .reverse)
    private var allAppLists: [AppList]
    
    var habitProgressText: String? {
        guard let taskId = engine.state.selectedTaskId else { return nil }
        guard let item = planItems.first(where: { $0.id == taskId }) else { return nil }
        
        let current = item.currentValue(on: Date())
        let target = item.goalValue
        let unit = item.goalUnit
        
        // For habits or anything with a goal
        if item.type == .habit || target > 0 {
             return "Today: \(Int(current))/\(Int(target)) \(unit)"
        }
        return nil
    }
    
    var body: some View {
        GeometryReader { geo in
            let availableWidth = geo.size.width
            let availableHeight = geo.size.height
            let diameter = min(availableWidth * 0.75, availableHeight * 0.45)
            
            ZStack {
                // Main Timer UI
                VStack(spacing: 0) {
                    // Task Selection Header
                    Button(action: { showTaskSelection = true }) {
                        VStack(spacing: 4) {
                            HStack(spacing: 8) {
                                Text(engine.state.overriddenTaskName ?? taskStore.selectedTask?.name ?? "Select a Task")
                                    .font(.system(size: 18, weight: .semibold))
                                
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(TimerPalette.accent)
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Colors.textSecondary)
                            }
                            
                            if let progress = habitProgressText {
                                Text(progress)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(TimerPalette.accent)
                            }
                        }
                        .foregroundColor(Colors.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.10))
                                .background(.ultraThinMaterial, in: Capsule())
                        )
                        .overlay(
                            Capsule()
                                .stroke(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.34), Color.white.opacity(0.10)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: Color.black.opacity(0.28), radius: 10, x: 0, y: 5)
                    }
                    .padding(.top, Spacing.m)
                    .frame(maxHeight: availableHeight * 0.2) // Increased slightly for progress text
                    
                    HStack(spacing: 16) {
                        // Interval Settings Shortcut
                        Button(action: { 
                            showIntervalSettings = true 
                            if showTimerIntervalCoachMark {
                                showTimerIntervalCoachMark = false
                                viewModel.preferences.hasSeenTimerIntervalTooltip = true
                                triggerNextTimerStep()
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "timer")
                                    .font(.system(size: 13, weight: .bold))
                                Text(engine.config.isEnabled ? "Interval: On" : "Interval: Off")
                                    .font(.system(size: 13, weight: .bold))
                            }
                            .foregroundColor(TimerPalette.accent)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 16)
                            .background(TimerPalette.accent.opacity(0.22))
                            .clipShape(Capsule())
                            .coachMark(
                                title: "Interval",
                                subtitle: "Control focus breaks.",
                                isVisible: $showTimerIntervalCoachMark,
                                alignment: .bottom,
                                pointDirection: .top,
                                arrowAlignment: .center,
                                arrowOffsetX: 0,
                                bubbleOffsetX: 0,
                                bubbleOffsetY: 76,
                                color: .red
                            )
                        }
                        
                        // Ambient Sound Selection Shortcut
                        Button(action: { 
                            viewModel.showSoundSelection = true 
                            if showTimerMusicCoachMark {
                                showTimerMusicCoachMark = false
                                viewModel.preferences.hasSeenTimerMusicTooltip = true
                                triggerNextTimerStep()
                            }
                        }) {
                            HStack(spacing: 6) {
                                if viewModel.ambientSoundName.isEmpty {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 13, weight: .bold))
                                    Text("Add Music")
                                        .font(.system(size: 13, weight: .bold))
                                } else {
                                    Image(systemName: "music.note")
                                        .font(.system(size: 13, weight: .bold))
                                    Text(viewModel.ambientSoundName)
                                        .font(.system(size: 13, weight: .bold))
                                }
                            }
                            .foregroundColor(TimerPalette.accent)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 16)
                            .background(TimerPalette.accent.opacity(0.22))
                            .clipShape(Capsule())
                            .coachMark(
                                title: "Music",
                                subtitle: "Pick ambient sounds.",
                                isVisible: $showTimerMusicCoachMark,
                                alignment: .bottom,
                                pointDirection: .top,
                                arrowAlignment: .center,
                                arrowOffsetX: 0,
                                bubbleOffsetX: 0,
                                bubbleOffsetY: 76,
                                color: .red
                            )
                        }
                    }
                    .padding(.top, 4)
                    
                    // ---- Blocking Status Row ----
                    if engine.isBlockingActive || !engine.config.selectedBlockListId.isEmpty {
                        blockingStatusPill
                            .padding(.top, 4)
                            .coachMark(
                                title: "Deep Focus",
                                subtitle: "Block distractions by blocking apps.",
                                isVisible: $showTimerBlockListCoachMark,
                                alignment: .top,
                                pointDirection: .bottom,
                                arrowAlignment: .center,
                                arrowOffsetX: 0,
                                bubbleOffsetX: 0,
                                bubbleOffsetY: -80,
                                color: .red
                            )
                            .onTapGesture {
                                if showTimerBlockListCoachMark {
                                    showTimerBlockListCoachMark = false
                                    viewModel.preferences.hasSeenTimerBlockListTooltip = true
                                    triggerNextTimerStep()
                                }
                            }
                    }

                    Spacer()
                    
                    // Timer Circle
                    VStack(spacing: 24) {
                        DraggableDialTimer(
                            totalSeconds: Binding(
                                get: { engine.state.remainingSeconds },
                                set: { 
                                    applySelectedSeconds($0) 
                                    if showTimerCircleCoachMark {
                                        showTimerCircleCoachMark = false
                                        viewModel.preferences.hasSeenTimerCircleTooltip = true
                                        triggerNextTimerStep()
                                    }
                                }
                            ),
                            isRunning: engine.isRunning,
                            progress: engine.currentProgress,
                            color: currentSegmentColor
                        )
                        .frame(width: diameter, height: diameter)
                        .coachMark(
                            title: "Dial",
                            subtitle: "Rotate to set time.",
                            isVisible: $showTimerCircleCoachMark,
                            alignment: .top,
                            pointDirection: .bottom,
                            arrowAlignment: .center,
                            arrowOffsetX: 0,
                            bubbleOffsetX: 0,
                            bubbleOffsetY: -120,
                            color: .red
                        )
                        
                        VStack(spacing: 8) {
                            Text(timeString(from: engine.state.remainingSeconds))
                                .font(.system(size: diameter * 0.22, weight: .heavy, design: .monospaced))
                                .kerning(2)
                                .foregroundColor(Colors.textPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .onTapGesture {
                                    if showTimerTimeIntegerCoachMark {
                                        showTimerTimeIntegerCoachMark = false
                                        viewModel.preferences.hasSeenTimerTimeIntegerTooltip = true
                                        triggerNextTimerStep()
                                    }
                                    // only allow edit if running or paused
                                    editingSeconds = engine.state.remainingSeconds
                                    showTimerEditSheet = true
                                }
                                .coachMark(
                                    title: "Keypad",
                                    subtitle: "Tap to set precisely.",
                                    isVisible: $showTimerTimeIntegerCoachMark,
                                    alignment: .top,
                                    pointDirection: .bottom,
                                    arrowAlignment: .center,
                                    arrowOffsetX: 0,
                                    bubbleOffsetX: 0,
                                    bubbleOffsetY: -120,
                                    color: .red
                                )
                            
                            // Expected End Time / Schedule
                            let endTime = Date().addingTimeInterval(TimeInterval(engine.state.remainingSeconds))
                            Text("\(formattedTime(Date())) - \(formattedTime(endTime))")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(TimerPalette.accent)
                            
                            if engine.config.isEnabled {
                                Text(currentSegmentLabel)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(currentSegmentColor)
                                
                                if case .running(.focus) = engine.state.phase {
                                    Text("Cycle \(engine.state.cycleIndex + 1) • Session \(engine.state.completedFocusInCycle + 1)/\(engine.config.sessionsPerCycle)")
                                        .font(.caption)
                                        .foregroundColor(Colors.textTertiary)
                                }
                            }
                        }
                    }
                    .onTapGesture {
                        if !engine.isRunning {
                            viewModel.showFrequentlyUsedPomo = true
                        }
                    }
                    
                    Spacer()
                    
                    // Controls
                    VStack(spacing: Spacing.m) {
                        if case .idle = engine.state.phase {
                            idleControlRow
                                .padding(.horizontal, Spacing.l)
                            
                            PrimaryButton(title: "Start Timer", style: .blueGlass) {
                                engine.start(taskId: taskStore.selectedTaskId)
                                if showTimerStartCoachMark {
                                    showTimerStartCoachMark = false
                                    viewModel.preferences.hasSeenTimerStartTooltip = true
                                }
                            }
                            .padding(.horizontal, Spacing.l)
                            .coachMark(
                                title: "Start",
                                subtitle: "Begin session.",
                                isVisible: $showTimerStartCoachMark,
                                alignment: .top,
                                pointDirection: .bottom,
                                arrowAlignment: .center,
                                arrowOffsetX: 0,
                                bubbleOffsetX: 0,
                                bubbleOffsetY: -80,
                                color: .red
                            )
                        } else {
                            // Running / Paused Controls
                            // We use a ZStack/Overlay approach to keep the main buttons (Music, Play, Stop)
                            // perfectly stable and centered. The Break button appears to the left without
                            // shifting the others.
                            HStack(spacing: 44) {
                                // Ambient Sound Toggle/Select
                                Button(action: {
                                    if viewModel.ambientSoundName.isEmpty {
                                        viewModel.showSoundSelection = true
                                    } else {
                                        viewModel.toggleAmbientSound()
                                    }
                                }) {
                                    ZStack(alignment: .bottomTrailing) {
                                        Image(systemName: "music.note")
                                            .font(.system(size: 20, weight: .semibold))
                                        
                                        if !viewModel.ambientSoundName.isEmpty {
                                            Image(systemName: viewModel.isAmbientPlaying ? "pause.fill" : "play.fill")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(.white)
                                                .background(Circle().fill(Color.red).frame(width: 14, height: 14))
                                                .offset(x: 2, y: 2)
                                        }
                                    }
                                    .foregroundColor(Colors.textSecondary)
                                    .frame(width: 56, height: 56)
                                    .background(Circle().fill(Color(red: 0.13, green: 0.15, blue: 0.20)))
                                    .overlay(Circle().stroke(Color.white.opacity(0.10), lineWidth: 1))
                                }
                                .onLongPressGesture {
                                    viewModel.showSoundSelection = true
                                }
                                
                                // Play/Pause
                                Button(action: {
                                    if engine.isRunning {
                                        engine.pause()
                                    } else {
                                        engine.resume()
                                    }
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                }) {
                                    ZStack {
                                        Circle()
                                            .fill(currentSegmentColor)
                                            .frame(width: 72, height: 72)
                                        Image(systemName: engine.isRunning ? "pause.fill" : "play.fill")
                                            .font(.system(size: 26, weight: .bold))
                                            .foregroundColor(.black)
                                    }
                                    .shadow(color: currentSegmentColor.opacity(0.5), radius: 16, y: 6)
                                }
                                
                                // Stop — hidden in Deep Focus during active focus run
                                if engine.canStopSession {
                                    Button(action: {
                                        engine.requestStop()
                                        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                                    }) {
                                        Image(systemName: "stop.fill")
                                            .font(.system(size: 20, weight: .semibold))
                                            .foregroundColor(Color(red: 0.9, green: 0.25, blue: 0.25))
                                            .frame(width: 56, height: 56)
                                            .background(Circle().fill(Color(red: 0.13, green: 0.15, blue: 0.20)))
                                            .overlay(Circle().stroke(Color.white.opacity(0.10), lineWidth: 1))
                                    }
                                } else {
                                    // Placeholder to keep layout stable
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(Color.red.opacity(0.7))
                                        .frame(width: 56, height: 56)
                                        .background(Circle().fill(Color(red: 0.13, green: 0.15, blue: 0.20)))
                                        .overlay(Circle().stroke(Color.white.opacity(0.10), lineWidth: 1))
                                }
                            }
                            .overlay(alignment: .leading) {
                                // Manual Break (Coffee) - Appears to the left
                                Button(action: { engine.requestBreak() }) {
                                    Image(systemName: "cup.and.saucer.fill")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(Colors.textSecondary)
                                        .frame(width: 56, height: 56)
                                        .background(Circle().fill(Color(red: 0.13, green: 0.15, blue: 0.20)))
                                        .overlay(Circle().stroke(Color.white.opacity(0.10), lineWidth: 1))
                                }
                                .padding(.leading, -100) // 56 (width) + 44 (spacing)
                                .opacity(engine.isRunning ? 0 : 1)
                                .disabled(engine.isRunning)
                                .animation(.easeInOut(duration: 0.2), value: engine.isRunning)
                            }
                            
                            // ---- Deep Focus Lock Banner ----
                            if engine.isDeepFocusActive, case .running(.focus) = engine.state.phase {
                                HStack(spacing: 6) {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 12))
                                    Text("Deep Focus — session locked until complete")
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.red.opacity(0.15))
                                .clipShape(Capsule())
                                .padding(.top, 4)
                            }
                            
                            // Skip Button
                            if engine.isRunning {
                                Button(action: { engine.skipSegment() }) {
                                    Text("Take a short break")
                                        .font(.caption)
                                        .foregroundColor(Colors.textSecondary)
                                }
                                .padding(.top, 8)
                            }
                        }
                    }
                    .padding(.bottom, Spacing.xl)
                }
                .opacity(isOverlayVisible ? 0.3 : 1.0) // Dim if overlay
                .blur(radius: isOverlayVisible ? 5 : 0)
                
                // Finished Segment Overlay
                if case .finishedSegment(let segment) = engine.state.phase {
                    finishedSegmentOverlay(segment: segment)
                }
                
                // Finished Cycle Overlay
                if case .finishedCycle = engine.state.phase {
                    finishedCycleOverlay
                }
            }
            .frame(width: availableWidth, height: availableHeight)
        }
        .sheet(isPresented: $showTaskSelection) {
            TaskSelectionSheet()
                .environmentObject(taskStore)
                .environmentObject(engine)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $viewModel.showFrequentlyUsedPomo) {
            FrequentlyUsedPomoSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showIntervalSettings) {
            IntervalTimerSettingsView(engine: engine)
        }
        .sheet(isPresented: $viewModel.showSoundSelection) {
            SoundPickerView(selectedSound: Binding(
                get: { viewModel.ambientSoundName },
                set: { val in 
                    viewModel.setAmbientSound(val)
                }
            ))
        }
        .sheet(isPresented: $showTimerEditSheet) {
            TimerDurationPickerView(
                initialTotalSeconds: editingSeconds,
                segmentTitle: engine.state.currentSegment?.title ?? "Timer",
                onSave: { seconds in
                    applySelectedSeconds(seconds)
                    showTimerEditSheet = false
                }
            )
            .presentationDetents([.fraction(0.4)])
        }
        .sheet(isPresented: $showAppLists) {
            AppListsView(engine: engine)
                .onDisappear {
                    // Sync selected block list back into the engine
                    if let selected = allAppLists.first(where: {
                        $0.id.uuidString == engine.config.selectedBlockListId
                    }) ?? allAppLists.first(where: { $0.type == .block }) {
                        if engine.config.blockAppsEnabled {
                            engine.setActiveBlockList(selected)
                        }
                    }
                }
        }
        // MARK: - Intervention Sheet
        .fullScreenCover(isPresented: $engine.showingIntervention) {
            SessionInterventionView(
                breakMode: engine.config.breakMode,
                enabledChallenges: engine.config.enabledChallenges,
                onStopConfirmed: {
                    engine.forceStop()
                },
                onTakeBreak: {
                    engine.takeBreakAfterChallenge()
                },
                onDismiss: {
                    engine.showingIntervention = false
                }
            )
            .ignoresSafeArea()
        }
        .onAppear {
            // Check background foreground refresh
            engine.refreshTimer()
            // Restore the saved block list reference into the engine on first launch
            syncBlockListToEngine()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            engine.refreshTimer()
            // Restore the saved block list reference into the engine on launch
            if engine.activeBlockList == nil && !engine.config.selectedBlockListId.isEmpty {
                if let saved = allAppLists.first(where: {
                    $0.id.uuidString == engine.config.selectedBlockListId
                }) {
                    engine.activeBlockList = saved
                    print("🔗 [PomoTimerView] Restored activeBlockList → '\(saved.name)'")
                }
            }
        }
        .onChange(of: engine.isRunning) { _, running in
            if !running && viewModel.isAmbientPlaying {
                // Stop ambient music if the timer is paused or stopped
                viewModel.toggleAmbientSound()
            } else if running && !viewModel.isAmbientPlaying && !viewModel.ambientSoundName.isEmpty {
                // Only auto-start music if the segment is Focus
                if engine.state.currentSegment == .focus {
                    viewModel.toggleAmbientSound()
                }
            }
        }
        .onChange(of: engine.state.currentSegment) { _, newSegment in
            // Stop music immediately if transitioning to a break
            if newSegment == .shortBreak || newSegment == .longBreak {
                if viewModel.isAmbientPlaying {
                    viewModel.toggleAmbientSound()
                }
            } else if newSegment == .focus && engine.isRunning && !viewModel.isAmbientPlaying && !viewModel.ambientSoundName.isEmpty {
                 viewModel.toggleAmbientSound()
            }
        }
        .onAppear {
            onTimerAppear()
        }
        .onChange(of: showTimerTimeIntegerCoachMark) { _, isVisible in
            if !isVisible && !viewModel.preferences.hasSeenTimerTimeIntegerTooltip {
                viewModel.preferences.hasSeenTimerTimeIntegerTooltip = true
                triggerNextTimerStep()
            }
        }
        .onChange(of: showTimerCircleCoachMark) { _, isVisible in
            if !isVisible && !viewModel.preferences.hasSeenTimerCircleTooltip {
                viewModel.preferences.hasSeenTimerCircleTooltip = true
                triggerNextTimerStep()
            }
        }
        .onChange(of: showTimerIntervalCoachMark) { _, isVisible in
            if !isVisible && !viewModel.preferences.hasSeenTimerIntervalTooltip {
                viewModel.preferences.hasSeenTimerIntervalTooltip = true
                triggerNextTimerStep()
            }
        }
        .onChange(of: showTimerMusicCoachMark) { _, isVisible in
            if !isVisible && !viewModel.preferences.hasSeenTimerMusicTooltip {
                viewModel.preferences.hasSeenTimerMusicTooltip = true
                triggerNextTimerStep()
            }
        }
        .onChange(of: showTimerBlockListCoachMark) { _, isVisible in
            if !isVisible && !viewModel.preferences.hasSeenTimerBlockListTooltip {
                viewModel.preferences.hasSeenTimerBlockListTooltip = true
                triggerNextTimerStep()
            }
        }
        .onChange(of: showTimerStartCoachMark) { _, isVisible in
            if !isVisible && !viewModel.preferences.hasSeenTimerStartTooltip {
                viewModel.preferences.hasSeenTimerStartTooltip = true
            }
        }
    }
    
    // MARK: - Helpers
    
    /// Restore the persisted block list reference back into the engine (e.g. after cold start).
    /// Does NOT change blockAppsEnabled — just makes sure activeBlockList is set.
    private func syncBlockListToEngine() {
        guard engine.activeBlockList == nil,
              !engine.config.selectedBlockListId.isEmpty,
              let saved = allAppLists.first(where: {
                  $0.id.uuidString == engine.config.selectedBlockListId
              }) else { return }
        // Use the internal setter; preserve existing blockAppsEnabled flag
        engine.activeBlockList = saved
        print("🔗 [PomoTimerView] syncBlockListToEngine → '\(saved.name)'")
    }
    
    private var idleControlRow: some View {
        HStack(spacing: 10) {
            Spacer()
            
            Button {
                showAppLists = true
            } label: {
                let listName = allAppLists.first(where: {
                    $0.id.uuidString == engine.config.selectedBlockListId
                })?.name
                let blockEnabled = engine.config.blockAppsEnabled && listName != nil
                
                HStack(spacing: 6) {
                    Image(systemName: blockEnabled ? "lock.fill" : "lock.open.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(blockEnabled ? .red : Colors.textSecondary)
                    Text(listName ?? "Block Apps")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(blockEnabled ? Colors.textPrimary : Colors.textSecondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(blockEnabled ? Color.red.opacity(0.12) : Color.white.opacity(0.12))
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(blockEnabled ? Color.red.opacity(0.3) : Color.white.opacity(0.22), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.25), radius: 10, x: 0, y: 5)
            }
            .buttonStyle(.plain)
            .coachMark(
                title: "Deep Focus",
                subtitle: "Block distractions by blocking apps.",
                isVisible: $showTimerBlockListCoachMark,
                alignment: .top,
                pointDirection: .bottom,
                arrowAlignment: .center,
                arrowOffsetX: 0,
                bubbleOffsetX: 0,
                bubbleOffsetY: -80,
                color: .red
            )
            .onTapGesture {
                if showTimerBlockListCoachMark {
                    showTimerBlockListCoachMark = false
                    viewModel.preferences.hasSeenTimerBlockListTooltip = true
                    triggerNextTimerStep()
                }
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
    }

    private func applySelectedSeconds(_ seconds: Int) {
        let clampedSeconds = max(1, seconds)

        if case .idle = engine.state.phase {
            // Idle selection is a base duration change
            var updated = engine.config
            updated.focusSeconds = clampedSeconds
            engine.updateConfig(updated)
        } else {
            // During active/paused sessions, user is editing only the current segment remaining time.
            engine.adjustRemainingTime(to: clampedSeconds)
        }
    }

    var isOverlayVisible: Bool {
        if case .finishedSegment = engine.state.phase { return true }
        if case .finishedCycle = engine.state.phase { return true }
        return false
    }
    
    var currentSegmentColor: Color {
        guard let segment = engine.state.currentSegment else { return TimerPalette.accent }
        switch segment {
        case .focus: return TimerPalette.accent
        case .shortBreak: return TimerPalette.accent
        case .longBreak: return TimerPalette.accent
        }
    }
    
    // MARK: - Blocking Status Pill
    
    private var blockingStatusPill: some View {
        let listName = allAppLists.first(where: {
            $0.id.uuidString == engine.config.selectedBlockListId
        })?.name ?? "Blocklist"
        
        let appCount: Int = {
            #if canImport(FamilyControls)
            return allAppLists.first(where: {
                $0.id.uuidString == engine.config.selectedBlockListId
            })?.selectedApplicationsCount ?? 0
            #else
            return allAppLists.first(where: {
                $0.id.uuidString == engine.config.selectedBlockListId
            })?.mockAppIDs.count ?? 0
            #endif
        }()
        
        let isRunningFocus = engine.isBlockingActive
        
        return Button(action: { showAppLists = true }) {
            HStack(spacing: 8) {
                Image(systemName: isRunningFocus ? "lock.fill" : "lock.open.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(isRunningFocus ? .red : Colors.textSecondary)
                
                Text(listName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isRunningFocus ? Colors.textPrimary : Colors.textSecondary)
                
                if appCount > 0 {
                    Text("\(appCount) apps")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Colors.textTertiary)
                }
                
                if engine.config.difficultyMode == .deepFocus {
                    Text("DEEP")
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(.black)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isRunningFocus ? Color.red.opacity(0.15) : Color.white.opacity(0.08))
            )
            .buttonStyle(.plain)
    }
    
    // MARK: - Onboarding Logic
    
    private func onTimerAppear() {
        if !viewModel.preferences.hasSeenTimerTimeIntegerTooltip {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                showTimerTimeIntegerCoachMark = true
            }
        } else if !viewModel.preferences.hasSeenTimerCircleTooltip {
            showTimerCircleCoachMark = true
        }
    }
    
    private func triggerNextTimerStep() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation {
                if !viewModel.preferences.hasSeenTimerCircleTooltip {
                    showTimerCircleCoachMark = true
                } else if !viewModel.preferences.hasSeenTimerIntervalTooltip {
                    showTimerIntervalCoachMark = true
                } else if !viewModel.preferences.hasSeenTimerMusicTooltip {
                    showTimerMusicCoachMark = true
                } else if !viewModel.preferences.hasSeenTimerBlockListTooltip {
                    showTimerBlockListCoachMark = true
                } else if !viewModel.preferences.hasSeenTimerStartTooltip {
                    showTimerStartCoachMark = true
                }
            }
        }
    }
    
    
    var currentSegmentLabel: String {
        engine.state.currentSegment?.title.uppercased() ?? "FOCUS"
    }
    
    func timeString(from totalSeconds: Int) -> String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    // MARK: - Overlays
    
    func finishedSegmentOverlay(segment: SegmentKind) -> some View {
        let nextKind = engine.getNextSegmentKind()
        let nextTitle = nextKind.title
        
        return VStack(spacing: Spacing.l) {
            Text("\(segment.title) Complete")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(Colors.textPrimary)
            
            PrimaryButton(title: "Start \(nextTitle)", style: .blueGlass) {
                engine.continueAfterFinishedScreen()
            }
            
            Button(action: {
                engine.stop(userInitiated: true)
            }) {
                Text("Done")
                    .font(.subheadline)
                    .foregroundColor(Colors.textSecondary)
            }
        }
        .padding(Spacing.xl)
        .background(Colors.cardSurface)
        .cornerRadius(20)
        .shadow(color: Colors.shadow, radius: 20)
        .padding(.horizontal, 40)
    }
    
    var finishedCycleOverlay: some View {
        VStack(spacing: Spacing.l) {
            Image(systemName: "flag.checkered")
                .font(.system(size: 40))
                .foregroundColor(TimerPalette.accent)
            
            Text("Cycle Complete!")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(Colors.textPrimary)
            
            Text("You've completed a full interval cycle.")
                .font(.body)
                .foregroundColor(Colors.textSecondary)
                .multilineTextAlignment(.center)
            
            PrimaryButton(title: "Start Next Cycle", style: .blueGlass) {
                engine.startNextCycle()
            }
            
            Button(action: {
                engine.stop(userInitiated: true)
            }) {
                Text("Finish")
                    .font(.subheadline)
                    .foregroundColor(Colors.textSecondary)
            }
        }
        .padding(Spacing.xl)
        .background(Colors.cardSurface)
        .cornerRadius(20)
        .shadow(color: Colors.shadow, radius: 20)
        .padding(.horizontal, 40)
    }
}
