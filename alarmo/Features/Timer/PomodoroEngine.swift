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
    private let accountabilityManager = AccountabilityEnforcementManager.shared
    
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
         entitlementProvider: EntitlementProvider? = nil) {
        let store = configStore ?? IntervalTimerConfigStore()
        self.configStore = store
        self.config = store.config
        self.eventStore = eventStore ?? .shared
        self.entitlementProvider = entitlementProvider ?? MockEntitlementProvider()
        self.state = PomodoroRuntimeState()
        
        // Sync config updates
        // In a real app we might bind this, but for now init load is enough.
        // Or we can observe configStore.$config but we'll modify it directly here or pass updates back.
        
        // Restore state check (backgrounding)
        // checkBackground() // Subscribed via View or SceneDelegate in full app
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    func configure(with preferences: AppPreferences) {
        // Initial Sync
        syncFromPreferences(preferences)
        
        // Subscribe to changes
        preferences.$pomoDurationMinutes
            .combineLatest(preferences.$shortBreakMinutes, preferences.$longBreakMinutes, preferences.$pomosPerLongBreak)
            .sink { [weak self] _ in
                self?.syncFromPreferences(preferences)
            }
            .store(in: &cancellables)
            
        preferences.$autoStartNextPomo
            .combineLatest(preferences.$autoStartBreak)
            .sink { [weak self] _ in
                self?.syncFromPreferences(preferences)
            }
            .store(in: &cancellables)
    }
    
    private func syncFromPreferences(_ preferences: AppPreferences) {
        var newConfig = self.config
        newConfig.focusSeconds = preferences.pomoDurationMinutes * 60
        newConfig.shortBreakSeconds = preferences.shortBreakMinutes * 60
        newConfig.longBreakSeconds = preferences.longBreakMinutes * 60
        newConfig.sessionsPerCycle = preferences.pomosPerLongBreak
        
        // TimerConfig has single autoStart, we'll favor autoStartNextPomo for now or combine?
        // AppPreferences has granular control. Engine currently has one flag.
        // Ideally we update Engine to support granular, but for now let's map 'autoStartNextPomo' to it
        // OR we can make it true if either is true, but that might be annoying.
        // Let's assume 'autoStartNextSession' roughly maps to 'autoStartNextPomo' for general cycles.
        // A better fix would be updating IntervalTimerConfig to have both.
        newConfig.autoStartNextSession = preferences.autoStartNextPomo 
        
        // Update without loop if equality check passes
        if newConfig != self.config {
            self.updateConfig(newConfig)
        }
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
        
        let remaining = state.remainingSeconds
        let total = totalDuration(for: segment)
        let elapsed = total - remaining
        
        LiveActivityManager.shared.update(
            startTime: Date().addingTimeInterval(TimeInterval(-elapsed)),
            endTime: Date().addingTimeInterval(TimeInterval(state.remainingSeconds)),
            isRunning: false,
            stateString: segment == .focus ? "Paused" : "Break Paused"
        )
    }
    
    func resume(segment: SegmentKind? = nil) {
        let seg = segment ?? state.currentSegment ?? .focus
        state.phase = .running(segment: seg)
        state.currentSegment = seg
        
        let endDate = Date().addingTimeInterval(TimeInterval(state.remainingSeconds))
        state.segmentEndDate = endDate
        startTicker()
        
        let remaining = state.remainingSeconds
        let total = totalDuration(for: seg)
        let elapsed = total - remaining
        
        LiveActivityManager.shared.update(
            startTime: Date().addingTimeInterval(TimeInterval(-elapsed)),
            endTime: endDate,
            isRunning: true,
            stateString: seg == .focus ? "Focus Hard" : "Break Time"
        )
    }
    
    func stop(reset: Bool = true, userInitiated: Bool = false) {
        let shouldApplyEarlyPenalty =
            userInitiated &&
            (state.currentSegment == .focus) &&
            (state.remainingSeconds > 0) &&
            (isRunning || (state.phase.isPaused))
        
        if shouldApplyEarlyPenalty {
            _ = accountabilityManager.handleFocusEarlyStopPenalty()
        }
        
        LiveActivityManager.shared.end()
        timer?.cancel()
        accountabilityManager.endFocusSession()
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
        if kind == .focus {
            accountabilityManager.beginFocusSession(taskId: state.selectedTaskId)
        } else {
            accountabilityManager.endFocusSession()
        }
        
        // Set duration
        let duration = totalDuration(for: kind)
        state.remainingSeconds = duration
        let endDate = Date().addingTimeInterval(TimeInterval(duration))
        state.segmentEndDate = endDate
        
        startTicker()
        
        let focusName = state.overriddenTaskName ?? "Focus"
        let stateString = kind == .focus ? "Focus Hard" : "Break Time"
        LiveActivityManager.shared.start(focusName: focusName, startTime: Date(), endTime: endDate, stateString: stateString)
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
        LiveActivityManager.shared.end()
        
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
                // Next is Long Break (uses break auto-start)
                handleNextTransition(to: .longBreak, autoStart: config.autoStartBreak)
            } else {
                // Next is Short Break (uses break auto-start)
                handleNextTransition(to: .shortBreak, autoStart: config.autoStartBreak)
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
        accountabilityManager.endFocusSession()
        
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

private extension PomodoroPhase {
    var isPaused: Bool {
        if case .paused = self { return true }
        return false
    }
}
