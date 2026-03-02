import Foundation
import CoreMotion
import Combine
import UIKit

enum ShakeMissionState {
    case idle
    case active
    case success
    case blocked
}

class ShakeMissionViewModel: ObservableObject {
    @Published var targetShakes: Int
    @Published var currentShakes: Int = 0
    @Published var state: ShakeMissionState = .idle
    @Published var progress: CGFloat = 0.0
    
    private let motionManager = CMMotionManager()
    private var onComplete: (() -> Void)?
    
    // Shake detection state
    private var lastMagnitude: Double = 0
    private var isInShake = false
    private let shakeThreshold: Double = 2.5  // g-force threshold for a shake
    private let shakeResetThreshold: Double = 1.2 // Must drop below this to register next shake
    
    init(targetShakes: Int = 30, onComplete: (() -> Void)? = nil) {
        self.targetShakes = targetShakes
        self.onComplete = onComplete
    }
    
    func start() {
        guard motionManager.isAccelerometerAvailable else {
            // Simulator fallback
            state = .active
            startSimulation()
            return
        }
        
        state = .active
        currentShakes = 0
        progress = 0
        
        motionManager.accelerometerUpdateInterval = 0.05 // 20Hz
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, error in
            guard let self = self, let data = data else {
                if let error = error {
                    print("[ShakeMission] Accelerometer error: \(error)")
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
        currentShakes = 0
        progress = 0
        state = .idle
    }
    
    // MARK: - Core Shake Detection
    
    private func processAccelerometerData(_ data: CMAccelerometerData) {
        let accel = data.acceleration
        let magnitude = sqrt(accel.x * accel.x + accel.y * accel.y + accel.z * accel.z)
        
        if !isInShake && magnitude > shakeThreshold {
            // Entered a shake motion
            isInShake = true
            registerShake()
        } else if isInShake && magnitude < shakeResetThreshold {
            // Reset - arm is back to rest, ready for next shake
            isInShake = false
        }
        
        lastMagnitude = magnitude
    }
    
    private func registerShake() {
        guard state == .active else { return }
        
        currentShakes += 1
        progress = CGFloat(currentShakes) / CGFloat(targetShakes)
        
        // Haptic feedback on each shake
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        if currentShakes >= targetShakes {
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
        simulationTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            guard let self = self, self.state == .active else { return }
            self.registerShake()
        }
    }
}
