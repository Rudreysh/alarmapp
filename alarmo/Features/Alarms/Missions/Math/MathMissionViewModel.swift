import SwiftUI
import Combine

enum MathFeedbackState {
    case idle
    case correct
    case incorrect
}

class MathMissionViewModel: ObservableObject {
    @Published var problems: [MathProblem] = []
    @Published var currentIndex: Int = 0
    @Published var inputText: String = ""
    @Published var feedbackState: MathFeedbackState = .idle
    @Published var showSuccessOverlay: Bool = false
    @Published var isSoundEnabled: Bool = true
    @Published var timeRemaining: Int = 0
    @Published var timerActive: Bool = false
    
    let isPreviewMode: Bool
    let totalRounds: Int
    let onComplete: () -> Void
    
    private let hapticGenerator = UINotificationFeedbackGenerator()
    private var playbackTimer: AnyCancellable?
    
    init(config: MathMissionConfig, isPreviewMode: Bool = false, onComplete: @escaping () -> Void = {}) {
        self.isPreviewMode = isPreviewMode
        self.totalRounds = config.repeatCount
        self.isSoundEnabled = config.isSoundEnabled
        self.onComplete = onComplete
        self.problems = MathProblemGenerator.generateProblems(count: totalRounds, difficulty: config.difficulty)
        self.timeRemaining = SettingsStore.shared.missionTimeLimitSeconds
        
        if !isPreviewMode {
            PenaltyManager.shared.startMissionMonitoring(alarmId: UUID()) // Use real alarm ID if available
        }
        startTimer()
    }
    
    private func startTimer() {
        timerActive = true
        playbackTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect().sink { [weak self] _ in
            guard let self = self, self.timerActive else { return }
            if self.timeRemaining > 0 {
                self.timeRemaining -= 1
            } else {
                self.handleTimeExpired()
            }
        }
    }
    
    private func handleTimeExpired() {
        timerActive = false
        handleIncorrect()
        // Reset timer after a small delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.timeRemaining = SettingsStore.shared.missionTimeLimitSeconds
            self.timerActive = true
        }
    }
    
    var currentProblem: MathProblem? {
        guard currentIndex < problems.count else { return nil }
        return problems[currentIndex]
    }
    
    var progressText: String {
        "\(currentIndex + 1)/\(problems.count)"
    }
    
    func tapDigit(_ digit: String) {
        guard feedbackState == .idle else { return }
        if inputText.count < 9 { // Safety limit
            inputText += digit
        }
    }
    
    func deleteDigit() {
        guard feedbackState == .idle else { return }
        if !inputText.isEmpty {
            inputText.removeLast()
        }
    }
    
    func submit() {
        guard feedbackState == .idle, !inputText.isEmpty, let problem = currentProblem else { return }
        
        let userAnswer = Int(inputText) ?? -1
        if userAnswer == problem.correctAnswer {
            handleCorrect()
        } else {
            handleIncorrect()
        }
    }
    
    private func handleCorrect() {
        feedbackState = .correct
        if isSoundEnabled {
            // In a real app, play a sound resource
            // SoundPreviewPlayer().play(resourceName: "success", volume: 1.0)
        }
        hapticGenerator.notificationOccurred(.success)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            if self.currentIndex + 1 < self.problems.count {
                self.currentIndex += 1
                self.inputText = ""
                self.feedbackState = .idle
            } else {
                self.showSuccessOverlay = true
                self.timerActive = false
                if !self.isPreviewMode {
                    PenaltyManager.shared.stopMissionMonitoring()
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self.onComplete()
                }
            }
        }
    }
    
    private func handleIncorrect() {
        feedbackState = .incorrect
        if isSoundEnabled {
            // SoundPreviewPlayer().play(resourceName: "error", volume: 1.0)
        }
        hapticGenerator.notificationOccurred(.error)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self.inputText = ""
            self.feedbackState = .idle
        }
    }
}
