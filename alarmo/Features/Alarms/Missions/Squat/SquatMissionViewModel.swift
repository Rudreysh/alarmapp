import Foundation
import CoreMotion
import Combine
import UIKit

enum SquatMissionState {
    case idle
    case active
    case success
    case blocked
}

enum SquatPhase {
    case standing  // User is upright
    case squatting // User has gone down
}

class SquatMissionViewModel: ObservableObject {
    @Published var targetSquats: Int
    @Published var currentSquats: Int = 0
    @Published var state: SquatMissionState = .idle
    @Published var progress: CGFloat = 0.0
    @Published var phase: SquatPhase = .standing
    @Published var showGetUpWarning: Bool = false
    
    private let motionManager = CMMotionManager()
    private var onComplete: (() -> Void)?
    
    // Squat detection using device attitude/acceleration
    // When squatting with phone in hand/pocket:
    // - The vertical acceleration pattern changes significantly
    // - We track the "down-up" cycle using acceleration magnitude
    private var accelerationHistory: [Double] = []
    private let historySize = 10
    private var lastPhaseChangeDate = Date()
    private let phaseChangeCooldown: TimeInterval = 0.4 // Prevent jitter
    
    // Thresholds tuned for real-world squatting motion
    private let squatDownThreshold: Double = 0.7  // Low acceleration = going down
    private let squatUpThreshold: Double = 1.3   // High acceleration = pushing back up
    
    init(targetSquats: Int = 15, onComplete: (() -> Void)? = nil) {
        self.targetSquats = targetSquats
        self.onComplete = onComplete
    }
    
    func start() {
        guard motionManager.isAccelerometerAvailable else {
            state = .active
            startSimulation()
            return
        }
        
        state = .active
        currentSquats = 0
        progress = 0
        phase = .standing
        accelerationHistory = []
        
        motionManager.accelerometerUpdateInterval = 0.05 // 20Hz
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, error in
            guard let self = self, let data = data else {
                if let error = error {
                    print("[SquatMission] Accelerometer error: \(error)")
                    DispatchQueue.main.async {
                        self?.state = .blocked
                    }
                }
                return
            }
            self.processAccelerometerData(data)
        }
    }
    
    func stop() {
        motionManager.stopAccelerometerUpdates()
        simulationTimer?.invalidate()
        simulationTimer = nil
    }
    
    func reset() {
        stop()
        currentSquats = 0
        progress = 0
        phase = .standing
        state = .idle
    }
    
    // MARK: - Core Squat Detection
    
    private func processAccelerometerData(_ data: CMAccelerometerData) {
        let accel = data.acceleration
        let magnitude = sqrt(accel.x * accel.x + accel.y * accel.y + accel.z * accel.z)
        
        // Anti-cheat: If the user is just shaking the phone violently while sitting,
        // the magnitude will spike very high. A real squat is smooth.
        if magnitude > 2.5 {
            // Prevent progress for a moment if violent shaking detected
            lastPhaseChangeDate = Date().addingTimeInterval(1.0) 
            phase = .standing
            return
        }
        
        // Maintain a moving average for stability
        accelerationHistory.append(magnitude)
        if accelerationHistory.count > historySize {
            accelerationHistory.removeFirst()
        }
        
        let avgMagnitude = accelerationHistory.reduce(0, +) / Double(accelerationHistory.count)
        let timeSinceLastChange = Date().timeIntervalSince(lastPhaseChangeDate)
        
        guard timeSinceLastChange > phaseChangeCooldown else { return }
        
        switch phase {
        case .standing:
            // Detect going down: acceleration dips as body decelerates downward
            if avgMagnitude < squatDownThreshold {
                phase = .squatting
                lastPhaseChangeDate = Date()
                
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
            }
            
        case .squatting:
            // Detect pushing back up: acceleration spikes as body pushes upward
            if avgMagnitude > squatUpThreshold {
                // Ensure they actually spent a reasonable amount of time in the squat (e.g. at least 0.4s)
                // This prevents rapid jitter from counting as a full squat.
                if timeSinceLastChange >= 0.4 {
                    phase = .standing
                    lastPhaseChangeDate = Date()
                    registerSquat()
                } else {
                    // Reset if it was too fast (likely a small hand movement)
                    phase = .standing
                    lastPhaseChangeDate = Date()
                }
            }
        }
    }
    
    private func registerSquat() {
        guard state == .active else { return }
        
        currentSquats += 1
        progress = CGFloat(currentSquats) / CGFloat(targetSquats)
        
        let impact = UIImpactFeedbackGenerator(style: .heavy)
        impact.impactOccurred()
        
        if currentSquats >= targetSquats {
            completeMission()
        }
    }
    
    private func completeMission() {
        state = .success
        stop()
        
        let notification = UINotificationFeedbackGenerator()
        notification.notificationOccurred(.success)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.onComplete?()
        }
    }
    
    // MARK: - Simulator Fallback
    
    private var simulationTimer: Timer?
    
    private func startSimulation() {
        simulationTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            guard let self = self, self.state == .active else { return }
            
            // Simulate the down-up cycle
            DispatchQueue.main.async {
                self.phase = .squatting
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                self.phase = .standing
                self.registerSquat()
            }
        }
    }
}
