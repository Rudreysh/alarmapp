import ActivityKit
import AppIntents
import Foundation

@available(iOS 16.0, *)
struct TogglePomoRunStateIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Play or Pause Focus"
    static var openAppWhenRun: Bool = false
    @Parameter(title: "Session ID")
    var sessionId: String?

    init() {}

    init(sessionId: String) {
        self.sessionId = sessionId
    }
    
    func perform() async throws -> some IntentResult {
        if let sessionId, !sessionId.isEmpty {
            UserDefaults.standard.set(sessionId, forKey: "alarmo.liveActivity.targetSessionId")
        }
        let notificationName = CFNotificationName("ht.alarmo.toggleRunState" as CFString)
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(center, notificationName, nil, nil, true)
        
        return .result()
    }
}

@available(iOS 16.0, *)
struct ToggleAmbientPlaybackIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Play or Pause Ambient Sound"
    static var openAppWhenRun: Bool = false

    init() {}

    func perform() async throws -> some IntentResult {
        let notificationName = CFNotificationName("ht.alarmo.togglePlayback" as CFString)
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(center, notificationName, nil, nil, true)
        return .result()
    }
}

@available(iOS 16.0, *)
struct TogglePomoExpandedIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Show or Hide Running Timers"
    static var openAppWhenRun: Bool = false

    init() {}

    func perform() async throws -> some IntentResult {
        for activity in Activity<PomoAttributes>.activities {
            guard activity.content.state.parallelSessions.count > 1 else { continue }
            var contentState = activity.content.state
            contentState.isExpanded.toggle()
            await activity.update(using: contentState)
        }
        return .result()
    }
}

@available(iOS 16.0, *)
struct OpenPomodoroSessionIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Open Focus Timer"
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Session ID")
    var sessionId: String?

    init() {}

    init(sessionId: String) {
        self.sessionId = sessionId
    }

    func perform() async throws -> some IntentResult {
        if let sessionId, !sessionId.isEmpty {
            UserDefaults.standard.set(sessionId, forKey: "alarmo.liveActivity.openSessionId")
        }
        return .result()
    }
}
