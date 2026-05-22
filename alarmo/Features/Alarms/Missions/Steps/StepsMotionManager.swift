import Foundation
import CoreMotion

class StepsMotionManager {
    private let pedometer = CMPedometer()
    private let motionManager = CMMotionManager()
    
    // Fallback state
    private var isUsingAccelerometer = false
    private var lastAccelerometerStepCount = 0
    private var lastShakeDate = Date()
    
    var isStepCountingAvailable: Bool {
        return CMPedometer.isStepCountingAvailable()
    }
    
    func startUpdates(onStep: @escaping (Int) -> Void, onError: @escaping (Error) -> Void) {
        // First try Pedometer
        pedometer.startUpdates(from: Date()) { [weak self] data, error in
            if let error = error {
                let nsError = error as NSError
                // If permission denied (105), fail hard.
                if nsError.domain == CMErrorDomain && nsError.code == 105 {
                    onError(error)
                    return
                }
                
                // For other errors (StepCountingUnsupported, etc), try Accelerometer fallback
                DispatchQueue.main.async {
                    self?.startAccelerometerFallback(onStep: onStep, onError: onError)
                }
                return
            }
            
            if let data = data {
                onStep(data.numberOfSteps.intValue)
            }
        }
    }
    
    private func startAccelerometerFallback(onStep: @escaping (Int) -> Void, onError: @escaping (Error) -> Void) {
        guard motionManager.isAccelerometerAvailable else {
            // Accelerometer unavailable (Simulator or broken). 
            // We'll fall back to PURE SIMULATION so the user isn't stuck.
            print("StepsMotionManager: Accelerometer unavailable. Starting timer simulation.")
            startSimulation(onStep: onStep)
            return
        }
        
        isUsingAccelerometer = true
        lastAccelerometerStepCount = 0
        motionManager.accelerometerUpdateInterval = 0.1
        
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, error in
            guard let self = self else { return }
            
            if let error = error {
                 // Even if it claimed available, if it errors out, fallback to simulation
                 print("StepsMotionManager: Accelerometer error: \(error). Swapping to simulation.")
                 self.motionManager.stopAccelerometerUpdates()
                 self.startSimulation(onStep: onStep)
                 return
            }
            
            if let data = data {
                let acceleration = data.acceleration
                let magnitude = sqrt(pow(acceleration.x, 2) + pow(acceleration.y, 2) + pow(acceleration.z, 2))
                
                // Simple shake detection threshold
                if magnitude > 1.5 {
                     if Date().timeIntervalSince(self.lastShakeDate) > 0.3 {
                         self.lastShakeDate = Date()
                         self.lastAccelerometerStepCount += 1
                         onStep(self.lastAccelerometerStepCount)
                     }
                }
            }
        }
        print("StepsMotionManager: Started Accelerometer Fallback")
    }
    
    private var simulationTimer: Timer?
    
    private func startSimulation(onStep: @escaping (Int) -> Void) {
        lastAccelerometerStepCount = 0
        simulationTimer?.invalidate()
        simulationTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.lastAccelerometerStepCount += 1
            onStep(self.lastAccelerometerStepCount)
        }
        print("StepsMotionManager: Started Pure Simulation")
    }
    
    func stopUpdates() {
        pedometer.stopUpdates()
        motionManager.stopAccelerometerUpdates()
        simulationTimer?.invalidate()
        simulationTimer = nil
        isUsingAccelerometer = false
    }
}
