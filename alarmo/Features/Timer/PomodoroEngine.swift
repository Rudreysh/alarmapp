import SwiftUI
import Combine
import SwiftData

@MainActor
class PomodoroEngine: ObservableObject {
    @Published var config: IntervalTimerConfig
    @Published var state: PomodoroRuntimeState
    
    private let configStore: IntervalTimerConfigStore
    private var eventStore: PomodoroEventStore
    private var timer: AnyCancellable?
    private var entitlementProvider: EntitlementProvider
    
    /// Callback for when a segment (like Focus) is completed. 
    /// Parameters:TaskId, SegmentKind, DurationSeconds
    var onSessionComplete: ((UUID?, SegmentKind, Int) -> Void)?
    
    // Quick accessors
    var isRunning: Bool {
        if case .running = state.phase { return true }
        return false
    }
    
    var currentProgress: Double {
        guard let kind = state.currentSegment else { return 0 }
        let total = totalDuration(for: kind)
        guard total > 0 else { return 0 }
        return Double(total - state.remainingSeconds) / Double(total)
    }
    
    init(configStore: IntervalTimerConfigStore? = nil,
         eventStore: PomodoroEventStore? = nil,
         entitlementProvider: EntitlementProvider = MockEntitlementProvider()) {
        let store = configStore ?? IntervalTimerConfigStore()
        self.configStore = store
        self.config = store.config
        self.eventStore = eventStore ?? .shared
        self.entitlementProvider = entitlementProvider
        self.state = PomodoroRuntimeState()
        
        // Sync config updates
        // In a real app we might bind this, but for now init load is enough.
        // Or we can observe configStore.$config but we'll modify it directly here or pass updates back.
        
        // Restore state check (backgrounding)
        // checkBackground() // Subscribed via View or SceneDelegate in full app
    }
    
    // MARK: - Core Actions
    
    func start(taskId: UUID? = nil) {
        if let taskId = taskId {
            state.selectedTaskId = taskId
        }
        
        // If config disabled, force simple mode
        if !config.isEnabled {
           // Ensure simple config alignment if needed
        }

        switch state.phase {
        case .idle:
            startSegment(.focus)
        case .paused(let segment):
            resume(segment: segment)
        default:
            break
        }
    }
    
    func pause() {
        guard case .running(let segment) = state.phase else { return }
        timer?.cancel()
        state.phase = .paused(segment: segment)
        state.segmentEndDate = nil // Invalidate end date on pause
    }
    
    func resume(segment: SegmentKind? = nil) {
        let seg = segment ?? state.currentSegment ?? .focus
        state.phase = .running(segment: seg)
        state.currentSegment = seg
        
        // Recalculate end date based on remaining
        state.segmentEndDate = Date().addingTimeInterval(TimeInterval(state.remainingSeconds))
        startTicker()
    }
    
    func stop(reset: Bool = true) {
        timer?.cancel()
        if reset {
            state = PomodoroRuntimeState() // Full reset
            // If simple mode, reset duration
            state.remainingSeconds = config.focusSeconds
        } else {
            state.phase = .idle
        }
    }
    
    func skipSegment() {
        guard state.currentSegment != nil else { return }
        // Treat as completed but marked skipped? Or just force completion logic?
        // User requested: "ends current segment immediately"
        completeSegment(wasSkipped: true)
    }
    
    // MARK: - State Machine Logic
    
    private func startSegment(_ kind: SegmentKind) {
        state.currentSegment = kind
        state.phase = .running(segment: kind)
        
        // Set duration
        let duration = totalDuration(for: kind)
        state.remainingSeconds = duration
        state.segmentEndDate = Date().addingTimeInterval(TimeInterval(duration))
        
        startTicker()
    }
    
    private func startTicker() {
        timer?.cancel()
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }
    
    private func tick() {
        guard case .running = state.phase, let endDate = state.segmentEndDate else { return }
        
        let remaining = Int(endDate.timeIntervalSinceNow)
        if remaining <= 0 {
            state.remainingSeconds = 0
            completeSegment()
        } else {
            state.remainingSeconds = remaining
        }
    }
    
    private func completeSegment(wasSkipped: Bool = false) {
        timer?.cancel()
        state.segmentEndDate = nil
        
        guard let completedKind = state.currentSegment else { return }
        
        // Record Event
        let event = PomodoroEvent(
            taskId: state.selectedTaskId,
            segment: completedKind,
            plannedSeconds: totalDuration(for: completedKind),
            actualSeconds: totalDuration(for: completedKind) - state.remainingSeconds, // Rough calc
            startedAt: Date(), // Persist start time in state for accuracy?
            endedAt: Date(),
            wasSkipped: wasSkipped,
            cycleIndex: state.cycleIndex,
            focusIndexInCycle: state.completedFocusInCycle + (completedKind == .focus ? 1 : 0)
        )
        eventStore.record(event: event)
        
        // Notify listeners (e.g. to update habit progress)
        onSessionComplete?(state.selectedTaskId, completedKind, event.actualSeconds)
        
        // Update Cycle Counts
        if completedKind == .focus {
            // Only increment if not skipped? User said "Preferred: skipped focus should NOT increment."
            if !wasSkipped {
                state.completedFocusInCycle += 1
            }
        }
        
        // Determine Next State
        if !config.isEnabled {
            // Simple Mode: Always finish to idle/done screen
             state.phase = .finishedSegment(segment: .focus)
             // Simple mode usually just alerts completion.
             return
        }
        
        // Interval Logic
        if completedKind == .longBreak {
            finishCycle()
        } else if completedKind == .shortBreak {
            // After short break -> Focus
            handleNextTransition(to: .focus, autoStart: config.autoStartNextSession)
        } else if completedKind == .focus {
            // After focus -> check cycle progress
            if state.completedFocusInCycle >= config.sessionsPerCycle {
                // Next is Long Break
                handleNextTransition(to: .longBreak, autoStart: config.autoStartNextSession)
            } else {
                // Next is Short Break
                handleNextTransition(to: .shortBreak, autoStart: config.autoStartNextSession)
            }
        }
    }
    
    private func handleNextTransition(to nextKind: SegmentKind, autoStart: Bool) {
        if autoStart {
            // Small delay or immediate? Immediate is cleaner for engine.
            startSegment(nextKind)
        } else {
            // Waiting for user
            state.phase = .finishedSegment(segment: state.currentSegment ?? .focus) // Show "Finished X"
            // The UI will look at `state.currentSegment` to know what just finished, 
            // and use `getNextSegment()` to know what button to show ("Start Break" vs "Start Focus")
        }
    }
    
    private func finishCycle() {
        state.phase = .finishedCycle
        state.completedFocusInCycle = 0
        state.cycleIndex += 1
        
        if config.autoStartNextCycle {
            startSegment(.focus)
        }
    }
    
    // MARK: - User Intent Actions
    
    func continueAfterFinishedScreen() {
        // Called when user taps "Start Break" or "Start Focus"
        // Determine next based on current state
        guard let justFinished = state.currentSegment else { return }
        
        if justFinished == .focus {
            if state.completedFocusInCycle >= config.sessionsPerCycle {
                startSegment(.longBreak)
            } else {
                startSegment(.shortBreak)
            }
        } else {
            // Break finished -> Focus
            startSegment(.focus)
        }
    }
    
    func startNextCycle() {
        // From Cycle Complete screen
        startSegment(.focus)
    }
    
    // MARK: - Helpers
    
    
    // Returns what would be next, for UI Logic
    func getNextSegmentKind() -> SegmentKind {
        guard let current = state.currentSegment else { return .focus }
        if current == .shortBreak || current == .longBreak { return .focus }
        
        // Focus finished
        if state.completedFocusInCycle >= config.sessionsPerCycle {
            return .longBreak
        }
        return .shortBreak
    }
    
    // MARK: - Backgrounding
    
    private func checkBackground() {
        // In a real app, subscribe to ScenePhase
        // Here we just rely on View calling `refreshFromBackground`
    }
    
    func refreshTimer() {
        // Call on scene foreground
        guard case .running = state.phase, let end = state.segmentEndDate else { return }
        let remaining = Int(end.timeIntervalSinceNow)
        if remaining <= 0 {
            state.remainingSeconds = 0
            completeSegment()
        } else {
            state.remainingSeconds = remaining
        }
    }
    
    // MARK: - Config
    
    func updateConfig(_ newConfig: IntervalTimerConfig) {
        config = newConfig
        configStore.update(newConfig)
        
        // If idle, reset time to match new focus duration
        if case .idle = state.phase {
            state.remainingSeconds = newConfig.focusSeconds
        }
    }
    
    func apply(task: TaskItem) {
        var newConfig = config
        newConfig.isEnabled = task.isIntervalTimer
        newConfig.focusSeconds = task.focusDurationMinutes * 60
        
        // Always load break settings so manual breaks work
        newConfig.shortBreakSeconds = task.shortBreakMinutes * 60
        newConfig.longBreakSeconds = task.longBreakMinutes * 60
        
        if task.isIntervalTimer {
            newConfig.sessionsPerCycle = task.sessionsPerCycle
            newConfig.autoStartNextSession = task.autoStartNextSession
            newConfig.autoStartNextCycle = task.autoStartNextCycle
        }
        
        updateConfig(newConfig)
    }
    
    // MARK: - Manual Actions
    
    func startBreak() {
        startSegment(.shortBreak)
    }

    func adjustRemainingTime(to seconds: Int) {
        state.remainingSeconds = seconds
        if case .running = state.phase {
            state.segmentEndDate = Date().addingTimeInterval(TimeInterval(seconds))
        }
    }
    
    func apply(planItem: PlanItem) {
        var newConfig = config
        newConfig.isEnabled = planItem.intervalTimerEnabled
        
        if let duration = planItem.defaultDurationSeconds {
            newConfig.focusSeconds = duration
        } else if let settings = planItem.intervalSettings {
             newConfig.focusSeconds = settings.focusMinutes * 60
        }
        
        state.overriddenTaskName = planItem.title
        state.selectedTaskId = planItem.id
        
        if let settings = planItem.intervalSettings {
            newConfig.shortBreakSeconds = settings.shortBreakMinutes * 60
            newConfig.longBreakSeconds = settings.longBreakMinutes * 60
            newConfig.sessionsPerCycle = settings.sessionsPerCycle
            newConfig.autoStartNextSession = settings.autoStartNextSession
            newConfig.autoStartNextCycle = settings.autoStartNextCycle
        } else {
             // Defaults if not set but duration is custom
             newConfig.shortBreakSeconds = 5 * 60
             newConfig.longBreakSeconds = 25 * 60
        }
        
        updateConfig(newConfig)
    }
} 

extension PomodoroEngine {
    func totalDuration(for kind: SegmentKind) -> Int {
        switch kind {
        case .focus: return config.focusSeconds
        case .shortBreak: return config.shortBreakSeconds
        case .longBreak: return config.longBreakSeconds
        }
    }
}
