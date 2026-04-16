import Foundation
import ActivityKit

public struct PomoAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public struct ParallelSession: Codable, Hashable, Identifiable {
            public var id: UUID
            public var focusName: String
            public var remainingSeconds: Int
            public var startTime: Date
            public var endTime: Date
            public var isRunning: Bool

            public init(
                id: UUID,
                focusName: String,
                remainingSeconds: Int,
                startTime: Date,
                endTime: Date,
                isRunning: Bool
            ) {
                self.id = id
                self.focusName = focusName
                self.remainingSeconds = remainingSeconds
                self.startTime = startTime
                self.endTime = endTime
                self.isRunning = isRunning
            }
        }

        public var startTime: Date
        public var endTime: Date
        public var remainingSeconds: Int
        public var isRunning: Bool
        public var stateString: String
        public var isAmbientPlaying: Bool
        public var ambientSoundName: String?
        public var isExpanded: Bool
        public var activeSessionId: UUID?
        public var parallelSessions: [ParallelSession]
        
        public init(
            startTime: Date,
            endTime: Date,
            remainingSeconds: Int,
            isRunning: Bool,
            stateString: String,
            isAmbientPlaying: Bool = false,
            ambientSoundName: String? = nil,
            isExpanded: Bool = false,
            activeSessionId: UUID? = nil,
            parallelSessions: [ParallelSession] = []
        ) {
            self.startTime = startTime
            self.endTime = endTime
            self.remainingSeconds = remainingSeconds
            self.isRunning = isRunning
            self.stateString = stateString
            self.isAmbientPlaying = isAmbientPlaying
            self.ambientSoundName = ambientSoundName
            self.isExpanded = isExpanded
            self.activeSessionId = activeSessionId
            self.parallelSessions = parallelSessions
        }
    }
    public var focusName: String
    
    public init(focusName: String) {
        self.focusName = focusName
    }
}
