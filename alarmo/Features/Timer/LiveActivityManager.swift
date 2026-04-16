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

    private func cleanupExtraActivities(keeping keepId: String?) {
        for activity in Activity<PomoAttributes>.activities {
            guard activity.id != keepId else { continue }
            let finalState = activity.content.state
            Task { await activity.end(using: finalState, dismissalPolicy: .immediate) }
        }
    }

    private func hasSameSessionIDs(
        _ lhs: [PomoAttributes.ContentState.ParallelSession],
        _ rhs: [PomoAttributes.ContentState.ParallelSession]
    ) -> Bool {
        guard lhs.count == rhs.count else { return false }
        return Set(lhs.map(\.id)) == Set(rhs.map(\.id))
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

        let normalizedSessions: [PomoAttributes.ContentState.ParallelSession]
        if parallelSessions.isEmpty {
            normalizedSessions = [
                .init(
                    id: activeSessionId ?? UUID(),
                    focusName: focusName,
                    remainingSeconds: max(0, remainingSeconds),
                    startTime: startTime,
                    endTime: endTime,
                    isRunning: remainingSeconds > 0
                )
            ]
        } else {
            normalizedSessions = parallelSessions.filter { $0.isRunning || $0.remainingSeconds > 0 }
        }

        guard !normalizedSessions.isEmpty else {
            end()
            return
        }

        let active = normalizedSessions.first(where: { $0.id == activeSessionId }) ?? normalizedSessions.first!
        let existingState = resolvedActivity()?.content.state
        let keepExpanded = (existingState?.isExpanded ?? false) &&
            hasSameSessionIDs(existingState?.parallelSessions ?? [], normalizedSessions)

        let contentState = PomoAttributes.ContentState(
            startTime: active.startTime,
            endTime: active.endTime,
            remainingSeconds: max(0, active.remainingSeconds),
            isRunning: active.isRunning,
            stateString: stateString,
            isAmbientPlaying: isAmbientPlaying,
            ambientSoundName: ambientSoundName,
            isExpanded: keepExpanded,
            activeSessionId: active.id,
            parallelSessions: normalizedSessions
        )

        if let existing = resolvedActivity() {
            Task { await existing.update(using: contentState) }
            cleanupExtraActivities(keeping: existing.id)
            return
        }

        do {
            let activity = try Activity<PomoAttributes>.request(
                attributes: PomoAttributes(focusName: focusName),
                contentState: contentState,
                pushType: nil
            )
            currentActivity = activity
            cleanupExtraActivities(keeping: activity.id)
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

        let current = activity.content.state
        var newSessions = parallelSessions ?? current.parallelSessions
        newSessions = newSessions.filter { $0.isRunning || $0.remainingSeconds > 0 }

        if newSessions.isEmpty {
            end()
            return
        }

        let active = newSessions.first(where: { $0.id == (activeSessionId ?? current.activeSessionId) }) ?? newSessions.first!

        let keepExpanded = current.isExpanded && hasSameSessionIDs(current.parallelSessions, newSessions)

        let contentState = PomoAttributes.ContentState(
            startTime: active.startTime,
            endTime: active.endTime,
            remainingSeconds: max(0, active.remainingSeconds),
            isRunning: active.isRunning,
            stateString: stateString,
            isAmbientPlaying: isAmbientPlaying ?? current.isAmbientPlaying,
            ambientSoundName: ambientSoundName ?? current.ambientSoundName,
            isExpanded: keepExpanded,
            activeSessionId: active.id,
            parallelSessions: newSessions
        )

        Task { await activity.update(using: contentState) }
        cleanupExtraActivities(keeping: activity.id)
    }

    func updateAmbientState(isAmbientPlaying: Bool, ambientSoundName: String?) {
        guard let activity = resolvedActivity() else { return }

        var contentState = activity.content.state
        contentState.isAmbientPlaying = isAmbientPlaying
        contentState.ambientSoundName = ambientSoundName

        Task { await activity.update(using: contentState) }
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

        let visibleSessions = sessions
            .filter { $0.isRunning || $0.remainingSeconds > 0 }
            .map {
                PomoAttributes.ContentState.ParallelSession(
                    id: $0.id,
                    focusName: $0.focusName,
                    remainingSeconds: max(0, $0.remainingSeconds),
                    startTime: $0.startTime,
                    endTime: $0.endTime ?? Date().addingTimeInterval(TimeInterval(max(0, $0.remainingSeconds))),
                    isRunning: $0.isRunning
                )
            }

        guard !visibleSessions.isEmpty else {
            end()
            return
        }

        let active = visibleSessions.first(where: { $0.id == activeSessionId }) ?? visibleSessions.first!

        let existing = resolvedActivity()
        let currentState = existing?.content.state
        let isExpanded = (currentState?.isExpanded ?? false) &&
            hasSameSessionIDs(currentState?.parallelSessions ?? [], visibleSessions)
        let ambientPlaying = currentState?.isAmbientPlaying ?? false
        let ambientName = currentState?.ambientSoundName

        let stateLabel: String
        if let source = sessions.first(where: { $0.id == active.id }) {
            stateLabel = source.segment == .focus
                ? (source.isRunning ? "Focus Hard" : "Paused")
                : (source.isRunning ? "Break Time" : "Break Paused")
        } else {
            stateLabel = fallbackStateString
        }

        let contentState = PomoAttributes.ContentState(
            startTime: active.startTime,
            endTime: active.endTime,
            remainingSeconds: active.remainingSeconds,
            isRunning: active.isRunning,
            stateString: stateLabel,
            isAmbientPlaying: ambientPlaying,
            ambientSoundName: ambientName,
            isExpanded: isExpanded,
            activeSessionId: active.id,
            parallelSessions: visibleSessions
        )

        if let existing {
            Task { await existing.update(using: contentState) }
            cleanupExtraActivities(keeping: existing.id)
            return
        }

        do {
            let activity = try Activity<PomoAttributes>.request(
                attributes: PomoAttributes(focusName: active.focusName.isEmpty ? fallbackFocusName : active.focusName),
                contentState: contentState,
                pushType: nil
            )
            currentActivity = activity
            cleanupExtraActivities(keeping: activity.id)
        } catch {
            print("Failed to sync Live Activity sessions: \(error)")
        }
    }

    func end(sessionId: UUID?) {
        guard let sessionId, let activity = resolvedActivity() else { return }

        var contentState = activity.content.state
        contentState.parallelSessions.removeAll { $0.id == sessionId }

        if contentState.parallelSessions.isEmpty {
            let finalState = activity.content.state
            Task { await activity.end(using: finalState, dismissalPolicy: .immediate) }
            currentActivity = nil
            return
        }

        let next = contentState.parallelSessions.first!
        contentState.activeSessionId = next.id
        contentState.startTime = next.startTime
        contentState.endTime = next.endTime
        contentState.remainingSeconds = next.remainingSeconds
        contentState.isRunning = next.isRunning
        contentState.stateString = next.isRunning ? "Focus Hard" : "Paused"

        Task { await activity.update(using: contentState) }
    }

    func end() {
        Task {
            for activity in Activity<PomoAttributes>.activities {
                let finalState = activity.content.state
                await activity.end(using: finalState, dismissalPolicy: .immediate)
            }
        }
        currentActivity = nil
    }
}
