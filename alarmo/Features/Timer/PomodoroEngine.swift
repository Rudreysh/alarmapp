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
    private let runtimeStateStore: PomodoroRuntimeStateStore
    private var eventStore: PomodoroEventStore
    private var timer: AnyCancellable?
    private var entitlementProvider: EntitlementProvider
    private let accountabilityManager = AccountabilityEnforcementManager.shared
    private let notificationOrchestrator = NotificationOrchestrator.shared
    private var pendingSegmentNotificationId: String?
    private var didBindNotificationActions = false
    private var didBindDarwinRunStateAction = false
    
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

    var parallelSessions: [ParallelFocusSession] {
        // Keep insertion order stable for UI so session emoji chips do not jump/swap every tick.
        state.parallelSessions
    }
    
    var currentProgress: Double {
        guard let kind = state.currentSegment else { return 0 }
        let total = totalDuration(for: kind)
        guard total > 0 else { return 0 }
        return Double(total - state.remainingSeconds) / Double(total)
    }

    private var currentSessionId: UUID? {
        state.activeParallelSessionId
    }

    func switchToParallelSession(_ id: UUID, persistCurrent: Bool = true) {
        if persistCurrent {
            persistCurrentSessionSnapshot()
        }
        guard let selected = state.parallelSessions.first(where: { $0.id == id }) else { return }

        state.activeParallelSessionId = selected.id
        state.selectedTaskId = selected.taskId
        state.overriddenTaskName = selected.focusName
        state.currentSegment = selected.segment
        state.remainingSeconds = selected.remainingSeconds

        if selected.isRunning, let end = selected.endTime {
            state.phase = .running(segment: selected.segment)
            state.segmentEndDate = end 
            startTicker()
        } else {
            timer?.cancel()
            state.phase = .paused(segment: selected.segment)
            state.segmentEndDate = nil
        }

        syncLiveActivityFromSessions()
        persistRuntimeState()
    }
    
    init(configStore: IntervalTimerConfigStore? = nil,
         eventStore: PomodoroEventStore? = nil,
         entitlementProvider: EntitlementProvider? = nil,
         runtimeStateStore: PomodoroRuntimeStateStore? = nil) {
        let store = configStore ?? IntervalTimerConfigStore()
        self.configStore = store
        self.config = store.config
        self.runtimeStateStore = runtimeStateStore ?? PomodoroRuntimeStateStore()
        self.eventStore = eventStore ?? .shared
        self.entitlementProvider = entitlementProvider ?? MockEntitlementProvider()
        self.state = self.runtimeStateStore.load() ?? PomodoroRuntimeState()
        reconcileLoadedRuntimeState()
        bindDarwinRunStateActionIfNeeded()
        
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

    private func bindDarwinRunStateActionIfNeeded() {
        guard !didBindDarwinRunStateAction else { return }
        didBindDarwinRunStateAction = true

        let name = CFNotificationName("ht.alarmo.toggleRunState" as CFString)
        let observer = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            observer,
            { (_, observer, _, _, _) in
                guard let observer else { return }
                let engine = Unmanaged<PomodoroEngine>.fromOpaque(observer).takeUnretainedValue()
                Task { @MainActor in
                    engine.handleLiveActivityRunStateToggle()
                }
            },
            name.rawValue,
            nil,
            .deliverImmediately
        )
    }

    private func handleLiveActivityRunStateToggle() {
        if let targetSessionId = consumeLiveActivityTargetSessionId(),
           targetSessionId != state.activeParallelSessionId,
           state.parallelSessions.contains(where: { $0.id == targetSessionId }) {
            switchToParallelSession(targetSessionId)
        }

        switch state.phase {
        case .running:
            pause()
        case .paused:
            resume()
        default:
            break
        }
    }

    private func consumeLiveActivityTargetSessionId() -> UUID? {
        let key = "alarmo.liveActivity.targetSessionId"
        let defaults = UserDefaults.standard
        defer { defaults.removeObject(forKey: key) }
        guard let raw = defaults.string(forKey: key),
              let id = UUID(uuidString: raw) else {
            return nil
        }
        return id
    }
    

    // MARK: - Core Actions
    
    func start(taskId: UUID? = nil) {
        var shouldStartFreshSession = false
        if let taskId = taskId {
            if let existing = state.parallelSessions.first(where: { $0.taskId == taskId }) {
                if state.activeParallelSessionId != existing.id {
                    switchToParallelSession(existing.id)
                }
            } else {
                persistCurrentSessionSnapshot()
                state.selectedTaskId = taskId
                state.activeParallelSessionId = taskId
                if state.overriddenTaskName == nil || state.overriddenTaskName?.isEmpty == true {
                    state.overriddenTaskName = "Focus"
                }
                state.phase = .idle
                state.currentSegment = .focus
                state.remainingSeconds = config.focusSeconds
                state.segmentEndDate = nil
                shouldStartFreshSession = true
            }
        }

        hydrateBlockListSelectionFromSettingsIfNeeded()

        if shouldStartFreshSession {
            startSegment(.focus)
            return
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
            remainingSeconds: state.remainingSeconds,
            isRunning: false,
            stateString: segment == .focus ? "Paused" : "Break Paused"
        )
        persistCurrentSessionSnapshot()
        syncLiveActivityFromSessions()
        refreshBlockingForCurrentPhase()
        persistRuntimeState()
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
            remainingSeconds: state.remainingSeconds,
            isRunning: true,
            stateString: seg == .focus ? "Focus Hard" : "Break Time"
        )
        persistCurrentSessionSnapshot()
        syncLiveActivityFromSessions()
        persistRuntimeState()
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
        LiveActivityManager.shared.end(sessionId: currentSessionId)
        timer?.cancel()
        cancelPendingSegmentNotification()
        accountabilityManager.endFocusSession()
        removeCurrentParallelSessionAndSelectNext()
        if state.parallelSessions.isEmpty {
            state = PomodoroRuntimeState()
            state.remainingSeconds = config.focusSeconds
            clearRuntimeState()
        } else {
            persistRuntimeState()
        }
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
        
        LiveActivityManager.shared.end(sessionId: currentSessionId)
        timer?.cancel()
        cancelPendingSegmentNotification()
        accountabilityManager.endFocusSession()
        removeCurrentParallelSessionAndSelectNext()
        if reset {
            if state.parallelSessions.isEmpty {
                state = PomodoroRuntimeState()
                state.remainingSeconds = config.focusSeconds
                clearRuntimeState()
            } else {
                persistRuntimeState()
            }
        } else {
            state.phase = .idle
            persistRuntimeState()
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
        if state.activeParallelSessionId == nil {
            state.activeParallelSessionId = state.selectedTaskId ?? UUID()
        }
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
        LiveActivityManager.shared.start(
            focusName: focusName,
            startTime: Date(),
            endTime: endDate,
            remainingSeconds: state.remainingSeconds,
            stateString: stateString,
            activeSessionId: state.activeParallelSessionId
        )
        persistCurrentSessionSnapshot()
        syncLiveActivityFromSessions()
        persistRuntimeState()
    }
    
    // MARK: - App Blocking Bridge
    
    /// Whether the current focus session has app blocking enabled
    var isBlockingActive: Bool {
        config.blockAppsEnabled && !effectiveSelectedBlockListId().isEmpty
    }
    
    /// Whether Deep Focus mode is active (can't stop early during focus)
    var isDeepFocusActive: Bool {
        config.difficultyMode == .deepFocus
    }

    /// True while a focus segment is active/paused and blocking is already engaged.
    /// During this window, block settings must stay immutable to prevent bypass.
    var isFocusBlockingControlsLocked: Bool {
        switch state.phase {
        case .running(let segment), .paused(let segment):
            return segment == .focus &&
                config.blockAppsEnabled &&
                !effectiveSelectedBlockListId().isEmpty
        default:
            return false
        }
    }
    
    /// Returns true if stop is currently allowed (blocked in deep focus during running focus)
    var canStopSession: Bool {
        guard case .running(let segment) = state.phase, segment == .focus else { return true }
        return config.difficultyMode != .deepFocus
    }
    
    /// Fetch the currently selected AppList from SwiftData (called by engine when needed)
    var activeBlockList: AppList? = nil
    
    func setActiveBlockList(_ list: AppList?) {
        // Prevent changing/clearing the active block list mid focus lock session.
        if isFocusBlockingControlsLocked,
           list?.id != activeBlockList?.id {
            return
        }

        activeBlockList = list
        var c = config
        c.selectedBlockListId = list?.id.uuidString ?? ""
        if list == nil {
            c.blockAppsEnabled = false
        }
        updateConfig(c)
    }
    
    private func applyBlockingForSegment(_ kind: SegmentKind) {
        guard config.blockAppsEnabled else {
            BlockingManager.shared.clearBlocking()
            return
        }
        guard let list = activeBlockList else {
            // If list model is not hydrated yet, fallback to stored selection snapshot.
            if applyBlockingFromStoredSelectionIfPossible() {
                return
            }
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
        let endedBackgroundSession = updateParallelSessionsClock()
        guard case .running = state.phase, let endDate = state.segmentEndDate else { return }
        
        let remaining = Int(endDate.timeIntervalSinceNow)
        if remaining <= 0 {
            state.remainingSeconds = 0
            completeSegment()
        } else {
            state.remainingSeconds = remaining
        }
        persistCurrentSessionSnapshot()
        if endedBackgroundSession {
            syncLiveActivityFromSessions()
            persistRuntimeState()
        }
    }
    
    private func completeSegment(wasSkipped: Bool = false) {
        timer?.cancel()
        cancelPendingSegmentNotification()
        state.segmentEndDate = nil
        LiveActivityManager.shared.end(sessionId: currentSessionId)
        
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
        persistRuntimeState()
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
            persistRuntimeState()
        }
    }
    
    // MARK: - Config
    
    func updateConfig(_ newConfig: IntervalTimerConfig) {
        let oldConfig = config
        var effectiveConfig = newConfig

        // If focus blocking is already active for the current session, do not allow
        // disabling/changing block source until session completes or mission flow ends.
        if isFocusBlockingControlsLocked {
            effectiveConfig.blockAppsEnabled = oldConfig.blockAppsEnabled
            effectiveConfig.selectedBlockListId = oldConfig.selectedBlockListId
        }

        config = effectiveConfig
        configStore.update(effectiveConfig)
        
        // If idle, reset time to match new focus duration
        if case .idle = state.phase {
            state.remainingSeconds = effectiveConfig.focusSeconds
        }

        if oldConfig.blockAppsEnabled != effectiveConfig.blockAppsEnabled ||
            oldConfig.blockDuringBreaks != effectiveConfig.blockDuringBreaks ||
            oldConfig.selectedBlockListId != effectiveConfig.selectedBlockListId {
            refreshBlockingForCurrentPhase()
        }
    }
    
    func apply(task: TaskItem) {
        if state.selectedTaskId != task.id {
            persistCurrentSessionSnapshot()
        }
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
        
        state.selectedTaskId = task.id
        state.overriddenTaskName = task.name
        state.activeParallelSessionId = task.id
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
        persistRuntimeState()
    }

    func handleSceneDidEnterBackground() {
        if case .running = state.phase, let end = state.segmentEndDate {
            state.remainingSeconds = max(0, Int(end.timeIntervalSinceNow))
        }
        refreshBlockingForCurrentPhase()
        persistRuntimeState()
    }

    func handleSceneDidBecomeActive() {
        handlePendingLiveActivityOpenRequest()
        refreshTimer()
        refreshBlockingForCurrentPhase()
        persistRuntimeState()
    }

    private func handlePendingLiveActivityOpenRequest() {
        let key = "alarmo.liveActivity.openSessionId"
        let defaults = UserDefaults.standard
        defer { defaults.removeObject(forKey: key) }

        guard let raw = defaults.string(forKey: key),
              let id = UUID(uuidString: raw),
              state.parallelSessions.contains(where: { $0.id == id }) else {
            return
        }

        if state.activeParallelSessionId != id {
            switchToParallelSession(id)
        }
    }
    
    func apply(planItem: PlanItem) {
        if state.selectedTaskId != planItem.id {
            persistCurrentSessionSnapshot()
        }
        var newConfig = config
        newConfig.isEnabled = planItem.intervalTimerEnabled
        
        if let duration = planItem.defaultDurationSeconds {
            newConfig.focusSeconds = duration
        } else if let settings = planItem.intervalSettings {
             newConfig.focusSeconds = settings.focusMinutes * 60
        }
        
        state.overriddenTaskName = planItem.title
        state.selectedTaskId = planItem.id
        state.activeParallelSessionId = planItem.id
        
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
            guard config.blockAppsEnabled else {
                BlockingManager.shared.clearBlocking()
                return
            }
            guard let list = activeBlockList else {
                // Re-apply from stored snapshot if list model isn't rehydrated yet.
                if applyBlockingFromStoredSelectionIfPossible() {
                    return
                }
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

    private func applyBlockingFromStoredSelectionIfPossible() -> Bool {
        let selectedId = effectiveSelectedBlockListId()
        guard !selectedId.isEmpty else { return false }

        let settings = SettingsStore.shared

        let hasAnyTargets =
            !settings.blockedAppsSelectionData.isEmpty ||
            !settings.blockedMockApps.isEmpty ||
            !settings.blockedMockCategories.isEmpty ||
            settings.blockedAdultContentEnabled
        guard hasAnyTargets else { return false }

        BlockingManager.shared.applyBlocking(
            selectionData: settings.blockedAppsSelectionData,
            mockAppIDs: settings.blockedMockApps,
            mockCategoryIDs: settings.blockedMockCategories,
            adultBlockingEnabled: settings.blockedAdultContentEnabled,
            label: "App Block List Snapshot"
        )
        return true
    }

    private func effectiveSelectedBlockListId() -> String {
        let configId = config.selectedBlockListId.trimmingCharacters(in: .whitespacesAndNewlines)
        if !configId.isEmpty { return configId }
        return SettingsStore.shared.selectedBlockListId.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func hydrateBlockListSelectionFromSettingsIfNeeded() {
        guard config.blockAppsEnabled else { return }
        let configId = config.selectedBlockListId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard configId.isEmpty else { return }

        let settingsId = SettingsStore.shared.selectedBlockListId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !settingsId.isEmpty else { return }

        var updated = config
        updated.selectedBlockListId = settingsId
        config = updated
        configStore.update(updated)
    }

    private func reconcileLoadedRuntimeState() {
        switch state.phase {
        case .running(let segment):
            guard let end = state.segmentEndDate else {
                state.phase = .paused(segment: segment)
                persistRuntimeState()
                return
            }
            let remaining = Int(end.timeIntervalSinceNow)
            if remaining <= 0 {
                state.remainingSeconds = 0
                state.phase = .finishedSegment(segment: segment)
                state.segmentEndDate = nil
            } else {
                state.remainingSeconds = remaining
            }
        case .paused:
            state.segmentEndDate = nil
        case .idle:
            if state.remainingSeconds <= 0 {
                state.remainingSeconds = config.focusSeconds
            }
        default:
            break
        }
        persistRuntimeState()
    }

    private func persistCurrentSessionSnapshot() {
        guard let segment = state.currentSegment else { return }

        let phaseIsActive: Bool = {
            switch state.phase {
            case .running, .paused:
                return true
            default:
                return false
            }
        }()

        guard phaseIsActive else { return }

        let sessionId: UUID = {
            if let existing = state.activeParallelSessionId {
                return existing
            }
            if let taskId = state.selectedTaskId {
                state.activeParallelSessionId = taskId
                return taskId
            }
            let created = UUID()
            state.activeParallelSessionId = created
            return created
        }()

        let isRunningNow: Bool = {
            if case .running = state.phase { return true }
            return false
        }()

        let total = max(1, totalDuration(for: segment))
        let fallbackEnd = Date().addingTimeInterval(TimeInterval(max(0, state.remainingSeconds)))
        let end = state.segmentEndDate ?? fallbackEnd
        let elapsed = max(0, total - state.remainingSeconds)
        let start = end.addingTimeInterval(TimeInterval(-max(0, state.remainingSeconds + elapsed)))

        let snapshot = ParallelFocusSession(
            id: sessionId,
            taskId: state.selectedTaskId,
            focusName: state.overriddenTaskName ?? "Focus",
            segment: segment,
            remainingSeconds: max(0, state.remainingSeconds),
            totalSeconds: total,
            startTime: start,
            endTime: end,
            isRunning: isRunningNow,
            updatedAt: Date()
        )

        if let idx = state.parallelSessions.firstIndex(where: { $0.id == sessionId }) {
            state.parallelSessions[idx] = snapshot
        } else {
            state.parallelSessions.append(snapshot)
        }
    }

    private func syncLiveActivityFromSessions() {
        state.parallelSessions.removeAll { !$0.isRunning && $0.remainingSeconds <= 0 }
        let sessions = state.parallelSessions
        guard !sessions.isEmpty else {
            LiveActivityManager.shared.end()
            return
        }

        if let activeId = state.activeParallelSessionId,
           !sessions.contains(where: { $0.id == activeId }) {
            state.activeParallelSessionId = sessions.first?.id
        }

        let active = sessions.first(where: { $0.id == state.activeParallelSessionId }) ?? sessions[0]
        let end = active.endTime ?? Date().addingTimeInterval(TimeInterval(max(0, active.remainingSeconds)))
        let stateLabel = active.segment == .focus
            ? (active.isRunning ? "Focus Hard" : "Paused")
            : (active.isRunning ? "Break Time" : "Break Paused")

        LiveActivityManager.shared.syncSessions(
            activeSessionId: state.activeParallelSessionId,
            sessions: sessions,
            fallbackFocusName: active.focusName,
            fallbackStart: active.startTime,
            fallbackEnd: end,
            fallbackRemainingSeconds: active.remainingSeconds,
            fallbackIsRunning: active.isRunning,
            fallbackStateString: stateLabel
        )
    }

    private func removeCurrentParallelSessionAndSelectNext() {
        guard let currentId = state.activeParallelSessionId else { return }
        state.parallelSessions.removeAll(where: { $0.id == currentId })
        if let next = state.parallelSessions.sorted(by: { $0.updatedAt > $1.updatedAt }).first {
            switchToParallelSession(next.id, persistCurrent: false)
        } else {
            state.activeParallelSessionId = nil
            state.selectedTaskId = nil
            state.overriddenTaskName = nil
            state.currentSegment = nil
            state.segmentEndDate = nil
            state.phase = .idle
            state.remainingSeconds = config.focusSeconds
        }
    }

    private func updateParallelSessionsClock(now: Date = Date()) -> Bool {
        guard !state.parallelSessions.isEmpty else { return false }
        var endedSession = false
        for index in state.parallelSessions.indices {
            guard state.parallelSessions[index].isRunning,
                  let end = state.parallelSessions[index].endTime else { continue }
            let remaining = max(0, Int(end.timeIntervalSince(now)))
            state.parallelSessions[index].remainingSeconds = remaining
            state.parallelSessions[index].updatedAt = now
            if remaining == 0 {
                state.parallelSessions[index].isRunning = false
                endedSession = true
            }
        }
        return endedSession
    }

    private func persistRuntimeState() {
        state.dateLastUpdated = Date()
        runtimeStateStore.save(state)
    }

    private func clearRuntimeState() {
        state.dateLastUpdated = Date()
        runtimeStateStore.clear()
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
