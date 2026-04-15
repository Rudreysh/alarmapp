import Foundation
import ActivityKit

@MainActor
class LiveActivityManager {
    static let shared = LiveActivityManager()
    
    private var currentActivity: Activity<PomoAttributes>?
    
    private init() {}

    private func resolvedActivity() -> Activity<PomoAttributes>? {
        if let currentActivity {
            return currentActivity
        }
        if let existing = Activity<PomoAttributes>.activities.first {
            currentActivity = existing
            return existing
        }
        return nil
    }
    
    func start(
        focusName: String,
        startTime: Date,
        endTime: Date,
        remainingSeconds: Int,
        stateString: String,
        isAmbientPlaying: Bool = false,
        ambientSoundName: String? = nil,
        activeSessionId: UUID? = nil,
        parallelSessions: [PomoAttributes.ContentState.ParallelSession] = []
    ) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        
        let attributes = PomoAttributes(focusName: focusName)
        let contentState = PomoAttributes.ContentState(
            startTime: startTime,
            endTime: endTime,
            remainingSeconds: remainingSeconds,
            isRunning: true,
            stateString: stateString,
            isAmbientPlaying: isAmbientPlaying,
            ambientSoundName: ambientSoundName,
            activeSessionId: activeSessionId,
            parallelSessions: parallelSessions
        )

        if let existingActivity = resolvedActivity() {
            Task {
                await existingActivity.update(using: contentState)
            }
            return
        }
        
        do {
            let activity = try Activity<PomoAttributes>.request(
                attributes: attributes,
                contentState: contentState,
                pushType: nil
            )
            self.currentActivity = activity
        } catch {
            print("Failed to start Live Activity: \(error)")
        }
    }
    
    func update(
        startTime: Date,
        endTime: Date,
        remainingSeconds: Int,
        isRunning: Bool,
        stateString: String,
        isAmbientPlaying: Bool? = nil,
        ambientSoundName: String? = nil,
        activeSessionId: UUID? = nil,
        parallelSessions: [PomoAttributes.ContentState.ParallelSession]? = nil
    ) {
        guard let activity = resolvedActivity() else { return }
        
        let currentState = activity.content.state
        let newIsAmbientPlaying = isAmbientPlaying ?? currentState.isAmbientPlaying
        let newAmbientSoundName = ambientSoundName ?? currentState.ambientSoundName
        let newActiveSessionId = activeSessionId ?? currentState.activeSessionId
        let newParallelSessions = parallelSessions ?? currentState.parallelSessions

        let contentState = PomoAttributes.ContentState(
            startTime: startTime,
            endTime: endTime,
            remainingSeconds: remainingSeconds,
            isRunning: isRunning,
            stateString: stateString,
            isAmbientPlaying: newIsAmbientPlaying,
            ambientSoundName: newAmbientSoundName,
            activeSessionId: newActiveSessionId,
            parallelSessions: newParallelSessions
        )
        
        Task {
            await activity.update(using: contentState)
        }
    }
    
    func updateAmbientState(isAmbientPlaying: Bool, ambientSoundName: String?) {
        guard let activity = resolvedActivity() else { return }
        
        var contentState = activity.content.state
        contentState.isAmbientPlaying = isAmbientPlaying
        contentState.ambientSoundName = ambientSoundName
        
        Task {
            await activity.update(using: contentState)
        }
    }

    func syncSessions(
        activeSessionId: UUID?,
        sessions: [ParallelFocusSession],
        fallbackFocusName: String,
        fallbackStart: Date,
        fallbackEnd: Date,
        fallbackRemainingSeconds: Int,
        fallbackIsRunning: Bool,
        fallbackStateString: String
    ) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let parallelPayload = sessions.map {
            PomoAttributes.ContentState.ParallelSession(
                id: $0.id,
                focusName: $0.focusName,
                remainingSeconds: $0.remainingSeconds,
                startTime: $0.startTime,
                endTime: $0.endTime ?? Date().addingTimeInterval(TimeInterval(max(0, $0.remainingSeconds))),
                isRunning: $0.isRunning
            )
        }

        let existing = Activity<PomoAttributes>.activities
        let activeSession = sessions.first(where: { $0.id == activeSessionId }) ?? sessions.first
        guard let activeSession else { return }

        let activeEnd = activeSession.endTime ?? Date().addingTimeInterval(TimeInterval(max(0, activeSession.remainingSeconds)))
        let activeStateString = activeSession.segment == .focus
            ? (activeSession.isRunning ? "Focus Hard" : "Paused")
            : (activeSession.isRunning ? "Break Time" : "Break Paused")
        let focusName = activeSession.focusName.isEmpty ? fallbackFocusName : activeSession.focusName

        let contentState = PomoAttributes.ContentState(
            startTime: activeSession.startTime,
            endTime: activeEnd,
            remainingSeconds: activeSession.remainingSeconds,
            isRunning: activeSession.isRunning,
            stateString: activeStateString,
            isAmbientPlaying: false,
            ambientSoundName: nil,
            activeSessionId: activeSession.id,
            parallelSessions: parallelPayload
        )

        // Keep exactly one Live Activity to avoid lock-screen duplicate cards.
        let primary = currentActivity ?? existing.first
        if let primary {
            Task { await primary.update(using: contentState) }
            currentActivity = primary

            for activity in existing where activity.id != primary.id {
                let finalState = activity.content.state
                Task { await activity.end(using: finalState, dismissalPolicy: .immediate) }
            }
            return
        }

        do {
            let activity = try Activity<PomoAttributes>.request(
                attributes: PomoAttributes(focusName: focusName),
                contentState: contentState,
                pushType: nil
            )
            currentActivity = activity
        } catch {
            print("Failed to sync Live Activity sessions: \(error)")
        }
    }

    func end(sessionId: UUID?) {
        guard let sessionId else { return }
        Task {
            for activity in Activity<PomoAttributes>.activities where activity.content.state.activeSessionId == sessionId {
                let finalState = activity.content.state
                await activity.end(using: finalState, dismissalPolicy: .immediate)
            }
        }
        if currentActivity?.content.state.activeSessionId == sessionId {
            currentActivity = nil
        }
    }
    
    func end() {
        Task {
            for activity in Activity<PomoAttributes>.activities {
                let finalState = activity.content.state
                await activity.end(using: finalState, dismissalPolicy: .immediate)
            }
        }
        self.currentActivity = nil
    }
}
