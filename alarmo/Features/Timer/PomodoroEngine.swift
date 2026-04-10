import SwiftUI
import Combine
import SwiftData
import UserNotifications

@MainActor
class PomodoroEngine: ObservableObject {
    @Published var config: IntervalTimerConfig
    @Published var state: PomodoroRuntimeState
    
    /// Set to true by PomoTimerView when stop is tapped during a blocked session
    @Published var showingIntervention: Bool = false
    
    private let configStore: IntervalTimerConfigStore
    private var eventStore: PomodoroEventStore
    private var timer: AnyCancellable?
    private var entitlementProvider: EntitlementProvider
    private let accountabilityManager = AccountabilityEnforcementManager.shared
    private let notificationOrchestrator = NotificationOrchestrator.shared
    private var pendingSegmentNotificationId: String?
    private var didBindNotificationActions = false
    
    /// Callback for segment lifecycle events.
    /// Parameters: taskId, segment, durationSeconds
    var onSegmentStarted: ((UUID?, SegmentKind, Int) -> Void)?
    var onSegmentInterrupted: ((UUID?, SegmentKind, Int) -> Void)?
    /// Parameters: taskId, segment, durationSeconds, wasSkipped
    var onSessionComplete: ((UUID?, SegmentKind, Int, Bool) -> Void)?
    
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
        bindNotificationActionsIfNeeded()

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

    private func bindNotificationActionsIfNeeded() {
        guard !didBindNotificationActions else { return }
        didBindNotificationActions = true

        NotificationCenter.default.publisher(for: .focusStartRequestedFromNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.start()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .focusSkipBreakRequestedFromNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                guard let current = self.state.currentSegment, current != .focus else { return }
                self.skipSegment()
            }
            .store(in: &cancellables)
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
        cancelPendingSegmentNotification()
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
        scheduleSegmentCompletionNotification(for: seg, seconds: state.remainingSeconds)
        
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
    
    /// Called when the user taps Stop. If blocking is active during a focus session,
    /// this shows the intervention sheet instead of stopping immediately.
    func requestStop() {
        guard isRunning || state.phase.isPaused else { return }
        
        let isBlockedFocusSession = config.blockAppsEnabled &&
            !config.selectedBlockListId.isEmpty &&
            state.currentSegment == .focus
        
        if isBlockedFocusSession && config.breakMode != .hardcore {
            // Show intervention — apps stay blocked until challenge is completed
            showingIntervention = true
        } else if config.breakMode == .hardcore && isBlockedFocusSession {
            // Hardcore: cannot stop at all
            return
        } else {
            // No blocking active — stop normally
            stop(userInitiated: true)
        }
    }
    
    /// Request a break — respects breakMode (harder requires challenge first, handled by UI)
    func requestBreak() {
        let isBlockedFocusSession = config.blockAppsEnabled &&
            !config.selectedBlockListId.isEmpty &&
            state.currentSegment == .focus
        
        if isBlockedFocusSession {
            showingIntervention = true
        } else {
            startBreak()
        }
    }
    
    /// Called ONLY after a challenge is completed. Actually stops and unblocks.
    func forceStop() {
        notifyInterruptionIfNeeded()
        let shouldApplyEarlyPenalty =
            (state.currentSegment == .focus) &&
            (state.remainingSeconds > 0) &&
            (isRunning || state.phase.isPaused)
        
        if shouldApplyEarlyPenalty {
            _ = accountabilityManager.handleFocusEarlyStopPenalty()
        }
        
        // NOW we clear blocking — only after challenge is complete
        BlockingManager.shared.clearBlocking()
        
        showingIntervention = false
        LiveActivityManager.shared.end()
        timer?.cancel()
        cancelPendingSegmentNotification()
        accountabilityManager.endFocusSession()
        state = PomodoroRuntimeState()
        state.remainingSeconds = config.focusSeconds
    }
    
    /// Called after challenge completed for a break (unblocks temporarily if blockDuringBreaks is false)
    func takeBreakAfterChallenge() {
        showingIntervention = false
        startBreak()
    }
    
    func stop(reset: Bool = true, userInitiated: Bool = false) {
        // Deep Focus guard: prevent stopping during an active focus run
        if userInitiated && !canStopSession {
            return
        }

        if userInitiated {
            notifyInterruptionIfNeeded()
        }
        
        let shouldApplyEarlyPenalty =
            userInitiated &&
            (state.currentSegment == .focus) &&
            (state.remainingSeconds > 0) &&
            (isRunning || state.phase.isPaused)
        
        if shouldApplyEarlyPenalty {
            _ = accountabilityManager.handleFocusEarlyStopPenalty()
        }
        
        // Only clear blocking if NOT user-initiated on a blocked session
        // (blocked sessions go through requestStop → intervention → forceStop)
        if !userInitiated || !config.blockAppsEnabled || state.currentSegment != .focus {
            BlockingManager.shared.clearBlocking()
        }
        
        LiveActivityManager.shared.end()
        timer?.cancel()
        cancelPendingSegmentNotification()
        accountabilityManager.endFocusSession()
        if reset {
            state = PomodoroRuntimeState()
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
        
        // App Blocking
        applyBlockingForSegment(kind)
        
        // Set duration
        let duration = totalDuration(for: kind)
        state.remainingSeconds = duration
        let endDate = Date().addingTimeInterval(TimeInterval(duration))
        state.segmentEndDate = endDate
        scheduleSegmentCompletionNotification(for: kind, seconds: duration)
        publishSegmentStartNotification(for: kind)
        onSegmentStarted?(state.selectedTaskId, kind, duration)
        
        startTicker()
        
        let focusName = state.overriddenTaskName ?? "Focus"
        let stateString = kind == .focus ? "Focus Hard" : "Break Time"
        LiveActivityManager.shared.start(focusName: focusName, startTime: Date(), endTime: endDate, stateString: stateString)
    }
    
    // MARK: - App Blocking Bridge
    
    /// Whether the current focus session has app blocking enabled
    var isBlockingActive: Bool {
        config.blockAppsEnabled && !config.selectedBlockListId.isEmpty
    }
    
    /// Whether Deep Focus mode is active (can't stop early during focus)
    var isDeepFocusActive: Bool {
        config.difficultyMode == .deepFocus
    }
    
    /// Returns true if stop is currently allowed (blocked in deep focus during running focus)
    var canStopSession: Bool {
        guard case .running(let segment) = state.phase, segment == .focus else { return true }
        return config.difficultyMode != .deepFocus
    }
    
    /// Fetch the currently selected AppList from SwiftData (called by engine when needed)
    var activeBlockList: AppList? = nil
    
    func setActiveBlockList(_ list: AppList?) {
        activeBlockList = list
        var c = config
        c.selectedBlockListId = list?.id.uuidString ?? ""
        if list == nil {
            c.blockAppsEnabled = false
        }
        updateConfig(c)
    }
    
    private func applyBlockingForSegment(_ kind: SegmentKind) {
        guard config.blockAppsEnabled, let list = activeBlockList else {
            BlockingManager.shared.clearBlocking()
            return
        }
        switch kind {
        case .focus:
            BlockingManager.shared.applyBlocking(blockList: list)
        case .shortBreak, .longBreak:
            if !config.blockDuringBreaks {
                BlockingManager.shared.clearBlocking()
            } else {
                BlockingManager.shared.applyBlocking(blockList: list)
            }
        }
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
        cancelPendingSegmentNotification()
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
        
        // Notify listeners (e.g. progress / discipline score updates)
        onSessionComplete?(state.selectedTaskId, completedKind, event.actualSeconds, wasSkipped)
        
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

    private func notifyInterruptionIfNeeded() {
        guard let segment = state.currentSegment else { return }
        guard state.remainingSeconds > 0 else { return }
        guard isRunning || state.phase.isPaused else { return }

        let total = totalDuration(for: segment)
        let elapsed = max(0, total - state.remainingSeconds)
        onSegmentInterrupted?(state.selectedTaskId, segment, elapsed)
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
        let oldConfig = config
        config = newConfig
        configStore.update(newConfig)
        
        // If idle, reset time to match new focus duration
        if case .idle = state.phase {
            state.remainingSeconds = newConfig.focusSeconds
        }

        if oldConfig.blockAppsEnabled != newConfig.blockAppsEnabled ||
            oldConfig.blockDuringBreaks != newConfig.blockDuringBreaks ||
            oldConfig.selectedBlockListId != newConfig.selectedBlockListId {
            refreshBlockingForCurrentPhase()
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
            if let kind = state.currentSegment {
                scheduleSegmentCompletionNotification(for: kind, seconds: seconds)
            }
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

    private func refreshBlockingForCurrentPhase() {
        switch state.phase {
        case .running(let segment), .paused(let segment):
            guard config.blockAppsEnabled, let list = activeBlockList else {
                BlockingManager.shared.clearBlocking()
                return
            }
            switch segment {
            case .focus:
                BlockingManager.shared.applyBlocking(blockList: list)
            case .shortBreak, .longBreak:
                if config.blockDuringBreaks {
                    BlockingManager.shared.applyBlocking(blockList: list)
                } else {
                    BlockingManager.shared.clearBlocking()
                }
            }
        default:
            break
        }
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

private extension PomodoroEngine {
    func scheduleSegmentCompletionNotification(for kind: SegmentKind, seconds: Int) {
        cancelPendingSegmentNotification()
        guard seconds > 0 else { return }

        let scenario: AppNotificationScenario = (kind == .focus) ? .pomodoroFocusComplete : .pomodoroBreakComplete
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(seconds), repeats: false)
        let id = "\(AppNotificationIdentifier.pomodoroSegmentEnd)-\(UUID().uuidString)"
        pendingSegmentNotificationId = id

        notificationOrchestrator.schedule(
            identifier: id,
            scenario: scenario,
            trigger: trigger,
            context: AppNotificationContext(),
            categoryIdentifier: AppNotificationCategory.focusSession,
            userInfo: ["scenario": scenario.rawValue],
            sound: .default
        )
    }

    func cancelPendingSegmentNotification() {
        guard let id = pendingSegmentNotificationId else { return }
        notificationOrchestrator.cancel(identifiers: [id])
        pendingSegmentNotificationId = nil
    }

    func publishSegmentStartNotification(for kind: SegmentKind) {
        let scenario: AppNotificationScenario = (kind == .focus) ? .pomodoroFocusStart : .pomodoroBreakStart
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        notificationOrchestrator.schedule(
            identifier: "alarmo.pomodoro.segment-start-\(UUID().uuidString)",
            scenario: scenario,
            trigger: trigger,
            context: AppNotificationContext(),
            categoryIdentifier: AppNotificationCategory.focusSession,
            userInfo: ["scenario": scenario.rawValue],
            sound: .default
        )
    }
}

private extension PomodoroPhase {
    var isPaused: Bool {
        if case .paused = self { return true }
        return false
    }
}
