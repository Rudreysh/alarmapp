import Foundation
import ActivityKit

public struct PomoAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var startTime: Date
        public var endTime: Date
        public var isRunning: Bool
        public var stateString: String
        public var isAmbientPlaying: Bool
        public var ambientSoundName: String?
        
        public init(startTime: Date, endTime: Date, isRunning: Bool, stateString: String, isAmbientPlaying: Bool = false, ambientSoundName: String? = nil) {
            self.startTime = startTime
            self.endTime = endTime
            self.isRunning = isRunning
            self.stateString = stateString
            self.isAmbientPlaying = isAmbientPlaying
            self.ambientSoundName = ambientSoundName
        }
    }
    public var focusName: String
    
    public init(focusName: String) {
        self.focusName = focusName
    }
}
