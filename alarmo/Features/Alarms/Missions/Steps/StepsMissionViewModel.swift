import Foundation
import SwiftUI
import Combine
import CoreMotion

enum StepsMissionState {
    case idle
    case active
    case success
    case blocked
}

class StepsMissionViewModel: ObservableObject {
    @Published var targetSteps: Int
    @Published var remainingSteps: Int
    @Published var state: StepsMissionState = .idle
    @Published var showGetUpWarning: Bool = false
    
    private let motionManager = StepsMotionManager()
    private var onComplete: (() -> Void)?
    private var lastStepDate: Date = Date()
    private var inactivityTimer: AnyCancellable?
    
    init(targetSteps: Int, onComplete: (() -> Void)? = nil) {
        self.targetSteps = targetSteps
        self.remainingSteps = targetSteps
        self.onComplete = onComplete
    }
    
    func start() {
        state = .active
        lastStepDate = Date()
        
        motionManager.startUpdates(onStep: { [weak self] steps in
            DispatchQueue.main.async {
                self?.handleStepUpdate(steps)
            }
        }, onError: { [weak self] error in
            DispatchQueue.main.async {
                self?.handleError(error)
            }
        })
        
        startInactivityTimer()
    }
    
    func stop() {
        motionManager.stopUpdates()
        inactivityTimer?.cancel()
    }

    func reset() {
        stop()
        DispatchQueue.main.async {
            self.state = .idle
        }
    }
    
    private func handleStepUpdate(_ steps: Int) {
        let newRemaining = max(0, targetSteps - steps)
        
        if newRemaining != remainingSteps {
            remainingSteps = newRemaining
            lastStepDate = Date()
            withAnimation {
                showGetUpWarning = false
            }
            
            if remainingSteps == 0 {
                completeMission()
            }
        }
    }
    
    private func handleError(_ error: Error) {
        // Check for permission error
        // CMErrorMotionActivityNotAuthorized = 105
        let nsError = error as NSError
        if nsError.domain == CMErrorDomain && nsError.code == 105 {
            state = .blocked
        } else {
            print("Steps Motion Error: \(error.localizedDescription)")
            // For other errors (device not supported, simulator, etc), allow testing flow via simulation
             state = .blocked 
        }
    }
    
    private func startInactivityTimer() {
        inactivityTimer = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, self.state == .active, self.remainingSteps > 0 else { return }
                
                if Date().timeIntervalSince(self.lastStepDate) > 3.0 {
                    withAnimation {
                        self.showGetUpWarning = true
                    }
                }
            }
    }
    
    private func completeMission() {
        state = .success
        stop()
        
        // Delay slightly for UX before calling completion handler or allow user to dismiss success view
        // The success view usually handles the 'Done' or automatic dismissal
        // We will expose state success and the View will invoke onComplete
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.onComplete?()
        }
    }
}
