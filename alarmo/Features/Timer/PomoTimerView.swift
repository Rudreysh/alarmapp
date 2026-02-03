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
                                    .foregroundColor(Colors.accentTeal)
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Colors.textSecondary)
                            }
                            
                            if let progress = habitProgressText {
                                Text(progress)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Colors.accentTeal)
                            }
                        }
                        .foregroundColor(Colors.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Colors.cardSurface.opacity(0.4))
                        .cornerRadius(20)
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
                            PrimaryButton(title: "Start") {
                                engine.start(taskId: taskStore.selectedTaskId)
                            }
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
                                Button(action: { engine.stop() }) {
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
                                    Text("Skip Segment")
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
            // Using a temporary binding to convert seconds <-> minutes for the picker
            let minutesBinding = Binding<Int>(
                get: { editingSeconds / 60 },
                set: { 
                    editingSeconds = $0 * 60 
                    engine.adjustRemainingTime(to: editingSeconds)
                }
            )
            
            NumberPickerSheet(
                title: engine.state.currentSegment?.title ?? "Timer",
                unit: "min", 
                value: minutesBinding, 
                range: 1...120
            ) 
            .presentationDetents([.fraction(0.4)])
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
    
    var isOverlayVisible: Bool {
        if case .finishedSegment = engine.state.phase { return true }
        if case .finishedCycle = engine.state.phase { return true }
        return false
    }
    
    var currentSegmentColor: Color {
        guard let segment = engine.state.currentSegment else { return Colors.accentRed }
        switch segment {
        case .focus: return Colors.accentRed
        case .shortBreak: return Colors.accentTeal
        case .longBreak: return Colors.accentGreen
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
                .background(Colors.accentTeal)
                .cornerRadius(12)
            }
            
            Button(action: {
                engine.stop()
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
                .foregroundColor(Colors.accentGreen)
            
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
                    .background(Colors.accentGreen)
                    .cornerRadius(12)
            }
            
            Button(action: {
                engine.stop()
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
