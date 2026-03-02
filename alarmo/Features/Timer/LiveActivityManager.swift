import Foundation
import ActivityKit

@MainActor
class LiveActivityManager {
    static let shared = LiveActivityManager()
    
    private var currentActivity: Activity<PomoAttributes>?
    
    private init() {}
    
    func start(focusName: String, startTime: Date, endTime: Date, stateString: String, isAmbientPlaying: Bool = false, ambientSoundName: String? = nil) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        
        let attributes = PomoAttributes(focusName: focusName)
        let contentState = PomoAttributes.ContentState(startTime: startTime, endTime: endTime, isRunning: true, stateString: stateString, isAmbientPlaying: isAmbientPlaying, ambientSoundName: ambientSoundName)
        
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
    
    func update(startTime: Date, endTime: Date, isRunning: Bool, stateString: String, isAmbientPlaying: Bool? = nil, ambientSoundName: String? = nil) {
        guard let activity = currentActivity else { return }
        
        let currentState = activity.content.state
        let newIsAmbientPlaying = isAmbientPlaying ?? currentState.isAmbientPlaying
        let newAmbientSoundName = ambientSoundName ?? currentState.ambientSoundName
        
        let contentState = PomoAttributes.ContentState(startTime: startTime, endTime: endTime, isRunning: isRunning, stateString: stateString, isAmbientPlaying: newIsAmbientPlaying, ambientSoundName: newAmbientSoundName)
        let alertConfiguration = AlertConfiguration(title: "Time's up", body: "Your focus session is finished", sound: .default)
        
        Task {
            await activity.update(using: contentState, alertConfiguration: alertConfiguration)
        }
    }
    
    func updateAmbientState(isAmbientPlaying: Bool, ambientSoundName: String?) {
        guard let activity = currentActivity else { return }
        
        var contentState = activity.content.state
        contentState.isAmbientPlaying = isAmbientPlaying
        contentState.ambientSoundName = ambientSoundName
        
        Task {
            await activity.update(using: contentState)
        }
    }
    
    func end() {
        guard let activity = currentActivity else { return }
        
        let finalState = activity.content.state
        Task {
            // Dismiss immediately
            await activity.end(using: finalState, dismissalPolicy: .immediate)
        }
        self.currentActivity = nil
    }
}
