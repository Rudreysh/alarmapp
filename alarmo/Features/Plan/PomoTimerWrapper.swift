
import SwiftUI

struct PomoTimerWrapper: View {
    let task: PlanItem
    @Environment(\.dismiss) var dismiss
    
    // We create a dedicated engine/VM for this session if global one isn't appropriate, 
    // or we could use this wrapper to set up the global one.
    // Ideally, we passed an EnvironmentObject, but for now let's create a standalone one 
    // initialized with the task's duration.
    
    @StateObject private var engine: PomodoroEngine = PomodoroEngine()
    @StateObject private var viewModel: TimerViewModel = TimerViewModel()
    @StateObject private var taskStore: TaskStore = TaskStore() // Dummy or real
    
    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()
            
            PomoTimerView(viewModel: viewModel, engine: engine)
                .environmentObject(taskStore)
                .environmentObject(engine)
            
            // Back Button
            VStack {
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(Colors.textPrimary)
                            .padding()
                            .background(Colors.cardSurface.opacity(0.8))
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                .padding()
                Spacer()
            }
        }
        .onAppear {
            setupTimer()
        }
    }
    
    private func setupTimer() {
        // Initialize engine with task details
        if let duration = task.defaultDurationSeconds {
            // Check if it's a focus session structure or simple duration
            // We can override the current segment duration
             
            // We need to access internal state properly. 
            // Ideally PomodoroEngine has a 'startTask(duration: ...)' method.
            // For now we will try to set the config or adjust remaining time.
            
            // Example:
            engine.state.overriddenTaskName = task.title
            engine.adjustRemainingTime(to: duration)
            
            // If it's a focus session with intervals
            if task.intervalTimerEnabled, let settings = task.intervalSettings {
                var newConfig = engine.config
                newConfig.isEnabled = true
                newConfig.focusSeconds = settings.focusMinutes * 60
                newConfig.shortBreakSeconds = settings.shortBreakMinutes * 60
                newConfig.longBreakSeconds = settings.longBreakMinutes * 60
                newConfig.sessionsPerCycle = settings.sessionsPerCycle
                engine.updateConfig(newConfig)
                
                // Reset to start of focus
                engine.stop(reset: true)
            } else {
                // Simple timer
                var newConfig = engine.config
                newConfig.isEnabled = false // Disable interval logic for simple timer
                engine.updateConfig(newConfig)
                engine.adjustRemainingTime(to: duration)
            }
            
            // Auto start?
             engine.start(taskId: task.id)
        }
    }
}
