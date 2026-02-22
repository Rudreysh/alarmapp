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
                // Opal-like atmospheric background (Pomodoro screen only)
                LinearGradient(
                    colors: [
                        Color.black,
                        Color(red: 0.02, green: 0.03, blue: 0.06),
                        Color(red: 0.03, green: 0.06, blue: 0.10),
                        Color(red: 0.02, green: 0.03, blue: 0.06),
                        Color.black
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .overlay(alignment: .top) {
                    RoundedRectangle(cornerRadius: 80, style: .continuous)
                        .fill(
                            RadialGradient(
                                colors: [
                                    TimerPalette.accentSoft.opacity(0.24),
                                    .clear
                                ],
                                center: .center,
                                startRadius: 20,
                                endRadius: 320
                            )
                        )
                        .frame(width: availableWidth * 0.45, height: 340)
                        .blur(radius: 26)
                        .offset(y: -110)
                }
                .overlay(alignment: .bottom) {
                    Ellipse()
                        .fill(
                            RadialGradient(
                                colors: [
                                    TimerPalette.accent.opacity(0.20),
                                    .clear
                                ],
                                center: .center,
                                startRadius: 10,
                                endRadius: 260
                            )
                        )
                        .frame(width: availableWidth * 0.78, height: 170)
                        .blur(radius: 18)
                        .offset(y: 80)
                }
                .allowsHitTesting(false)

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
                    
                    // Interval Settings Shortcut (Optional, small gear near header or separate)
                    Button(action: { showIntervalSettings = true }) {
                        Text(engine.config.isEnabled ? "Interval Timer: On" : "Interval Timer: Off")
                            .font(.caption)
                            .foregroundColor(Colors.textTertiary)
                    }
                    .padding(.top, 4)


                    
                    Spacer()
                    
                    // Timer Circle
                    ZStack {
                        ProgressRing(
                            progress: engine.currentProgress,
                            color: currentSegmentColor
                        )
                        .frame(width: diameter, height: diameter)
                        
                        VStack(spacing: 8) {
                            Text(timeString(from: engine.state.remainingSeconds))
                                .font(.system(size: diameter * 0.22, weight: .bold))
                                .monospacedDigit()
                                .foregroundColor(Colors.textPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .onTapGesture {
                                    // only allow edit if running or paused
                                    editingSeconds = engine.state.remainingSeconds
                                    showTimerEditSheet = true
                                }
                            
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
                            
                            Button {
                                engine.start(taskId: taskStore.selectedTaskId)
                            }
                            label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 19, weight: .bold))
                                    Text("Start Timer")
                                        .font(.system(size: 22, weight: .semibold))
                                }
                                .foregroundColor(Color.white.opacity(0.95))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(
                                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    TimerPalette.accentSoft.opacity(0.68),
                                                    TimerPalette.accentStrong.opacity(0.72),
                                                    TimerPalette.accent.opacity(0.70)
                                                ],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                                        .stroke(
                                            LinearGradient(
                                                colors: [Color.white.opacity(0.44), Color.white.opacity(0.14)],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            ),
                                            lineWidth: 1
                                        )
                                )
                                .shadow(color: TimerPalette.accent.opacity(0.10), radius: 7, x: 0, y: 4)
                            }
                            .buttonStyle(PressedScaleButtonStyle())
                            .padding(.horizontal, Spacing.l)
                        } else {
                            // Running / Paused Controls
                            // We use a ZStack/Overlay approach to keep the main buttons (Music, Play, Stop)
                            // perfectly stable and centered. The Break button appears to the left without
                            // shifting the others.
                            HStack(spacing: 30) {
                                // Sound (using logic from viewModel for now)
                                Button(action: { viewModel.showSoundSelection = true }) {
                                    Image(systemName: "music.note")
                                        .font(.system(size: 20))
                                        .foregroundColor(Colors.textPrimary)
                                        .frame(width: 50, height: 50)
                                        .background(Circle().stroke(Colors.cardStroke, lineWidth: 1))
                                }
                                
                                // Play/Pause
                                Button(action: {
                                    if engine.isRunning {
                                        engine.pause()
                                    } else {
                                        engine.resume()
                                    }
                                }) {
                                    Image(systemName: engine.isRunning ? "pause.fill" : "play.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(Colors.textPrimary)
                                        .frame(width: 70, height: 70)
                                        .background(currentSegmentColor)
                                        .clipShape(Circle())
                                        .appShadow(Shadows.button)
                                }
                                
                                // Stop
                                Button(action: { engine.stop(userInitiated: true) }) {
                                    Image(systemName: "stop.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(Colors.textPrimary)
                                        .frame(width: 50, height: 50)
                                        .background(Circle().stroke(Colors.cardStroke, lineWidth: 1))
                                }
                            }
                            .overlay(alignment: .leading) {
                                // Manual Break (Coffee) - Appears to the left
                                // We use opacity to keep the layout rigid, preventing any shifts.
                                Button(action: { engine.startBreak() }) {
                                    Image(systemName: "cup.and.saucer.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(Colors.textPrimary)
                                        .frame(width: 50, height: 50)
                                        .background(Circle().stroke(Colors.cardStroke, lineWidth: 1))
                                }
                                .padding(.leading, -80) // 50 (width) + 30 (spacing)
                                .opacity(engine.isRunning ? 0 : 1)
                                .disabled(engine.isRunning)
                                .animation(.easeInOut(duration: 0.2), value: engine.isRunning)
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
                get: { viewModel.pomoEndingSoundName },
                set: { viewModel.setPomoEndingSound($0) }
            ))
        }
        .sheet(isPresented: $showTimerEditSheet) {
            TimerDurationPickerView(
                initialMinutes: editingSeconds / 60,
                segmentTitle: engine.state.currentSegment?.title ?? "Timer",
                onSave: { minutes in
                    applySelectedMinutes(minutes)
                    showTimerEditSheet = false
                }
            )
            .presentationDetents([.fraction(0.4)])
        }
        .sheet(isPresented: $showAppLists) {
            AppListsView()
        }
        .onAppear {
            // Check background foreground refresh
             engine.refreshTimer()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            engine.refreshTimer()
        }
    }
    
    // MARK: - Helpers
    
    private var idleControlRow: some View {
        HStack(spacing: 12) {
            roundStepButton(symbol: "minus") {
                adjustFocusDuration(byMinutes: -5)
            }
            
            Button {
                editingSeconds = max(60, engine.config.focusSeconds)
                showTimerEditSheet = true
            } label: {
                Text("\(max(1, engine.config.focusSeconds / 60))m")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(Color.black.opacity(0.88))
                    .frame(minWidth: 92)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.white.opacity(0.96))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.white.opacity(0.7), lineWidth: 0.6)
                    )
                    .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            
            roundStepButton(symbol: "plus") {
                adjustFocusDuration(byMinutes: 5)
            }
            
            Button {
                showAppLists = true
            } label: {
                HStack(spacing: 10) {
                    Text("Block")
                        .font(.system(size: 17, weight: .semibold))
                    Image(systemName: "lock.fill")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(Colors.textPrimary)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.white.opacity(0.12))
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.22), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.25), radius: 10, x: 0, y: 5)
            }
            .buttonStyle(.plain)
        }
    }
    
    private func roundStepButton(symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Colors.textPrimary)
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.12))
                        .background(.ultraThinMaterial, in: Circle())
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.24), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.26), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(.plain)
    }
    
    private func adjustFocusDuration(byMinutes delta: Int) {
        let currentMinutes = max(1, engine.config.focusSeconds / 60)
        let nextMinutes = min(180, max(1, currentMinutes + delta))
        var updated = engine.config
        updated.focusSeconds = nextMinutes * 60
        engine.updateConfig(updated)
    }

    private func applySelectedMinutes(_ minutes: Int) {
        let clampedMinutes = min(180, max(1, minutes))
        let seconds = clampedMinutes * 60

        if case .idle = engine.state.phase {
            // Idle selection is a base duration change: keep config, picker pill and center timer in sync.
            var updated = engine.config
            updated.focusSeconds = seconds
            engine.updateConfig(updated)
        } else {
            // During active/paused sessions, user is editing only the current segment remaining time.
            engine.adjustRemainingTime(to: seconds)
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
    
    var currentSegmentLabel: String {
        engine.state.currentSegment?.title.uppercased() ?? "FOCUS"
    }
    
    func timeString(from totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
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
            
            Button(action: {
                engine.continueAfterFinishedScreen()
            }) {
                HStack(spacing: 8) {
                    if nextKind == .shortBreak || nextKind == .longBreak {
                        Image(systemName: "cup.and.saucer.fill")
                            .font(.system(size: 18))
                    }
                    Text("Start \(nextTitle)")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(TimerPalette.accent)
                .cornerRadius(12)
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
            
            Button(action: {
                engine.startNextCycle() // Starts configured auto behavior
            }) {
                Text("Start Next Cycle")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(TimerPalette.accent)
                    .cornerRadius(12)
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
