import Foundation
import SwiftUI
import Combine

class TypingGameplayViewModel: ObservableObject {
    @Published var targetPhrase: String = ""
    @Published var typedInput: String = "" {
        didSet {
            computeMatch()
        }
    }
    @Published var matchLen: Int = 0
    @Published var hasMismatch: Bool = false
    @Published var isDoneEnabled: Bool = false
    @Published var showSuccessOverlay: Bool = false
    @Published var roundIndex: Int = 1
    @Published var soundEnabled: Bool = true
    @Published var timeRemaining: Int = 0
    @Published var timerActive: Bool = false
    private var playbackTimer: AnyCancellable?
    
    let totalRounds: Int
    let isPreviewMode: Bool
    private let phrases: [Phrase]
    private let onComplete: (() -> Void)?
    private let hapticGenerator = UINotificationFeedbackGenerator()
    
    var greenSegment: String {
        guard matchLen > 0 else { return "" }
        let endIndex = targetPhrase.index(targetPhrase.startIndex, offsetBy: min(matchLen, targetPhrase.count))
        return String(targetPhrase[..<endIndex])
    }
    
    var redSegment: String {
        guard hasMismatch else { return "" }
        let targetCount = targetPhrase.count
        let typedCount = typedInput.count
        
        let startIdxOffset = min(matchLen, targetCount)
        let endIdxOffset = min(typedCount, targetCount)
        
        guard startIdxOffset < endIdxOffset else { return "" }
        
        let startIdx = targetPhrase.index(targetPhrase.startIndex, offsetBy: startIdxOffset)
        let endIdx = targetPhrase.index(targetPhrase.startIndex, offsetBy: endIdxOffset)
        return String(targetPhrase[startIdx..<endIdx])
    }
    
    var extraSegment: String {
        guard typedInput.count > targetPhrase.count else { return "" }
        _ = typedInput.count - targetPhrase.count
        // We can't show specific chars from targetPhrase since they don't exist,
        // so we return characters from the typed input that exceed the target
        let startIdx = typedInput.index(typedInput.startIndex, offsetBy: targetPhrase.count)
        return String(typedInput[startIdx...])
    }
    
    var remainderSegment: String {
        let currentProgress = min(typedInput.count, targetPhrase.count)
        guard currentProgress < targetPhrase.count else { return "" }
        let startIdx = targetPhrase.index(targetPhrase.startIndex, offsetBy: currentProgress)
        return String(targetPhrase[startIdx...])
    }
    
    init(settings: TypingSettings, phrases: [Phrase], isPreviewMode: Bool = false, onComplete: (() -> Void)? = nil) {
        self.totalRounds = settings.repeatCount
        self.isPreviewMode = isPreviewMode
        self.phrases = phrases
        self.onComplete = onComplete
        self.soundEnabled = settings.soundEnabled
        self.timeRemaining = SettingsStore.shared.missionTimeLimitSeconds
        
        if !isPreviewMode {
            PenaltyManager.shared.startMissionMonitoring(alarmId: UUID())
        }
        
        generateRound()
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
        // Reset current round
        timerActive = false
        hapticGenerator.notificationOccurred(.error)
        typedInput = ""
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.timeRemaining = SettingsStore.shared.missionTimeLimitSeconds
            self.timerActive = true
        }
    }
    
    private func generateRound() {
        if let randomPhrase = phrases.randomElement() {
            self.targetPhrase = randomPhrase.text
        } else {
            self.targetPhrase = "Choose joy"
        }
        self.typedInput = ""
        self.matchLen = 0
        self.hasMismatch = false
        self.isDoneEnabled = false
    }
    
    private func computeMatch() {
        var i = 0
        let normalizedTarget = normalize(targetPhrase).lowercased()
        let normalizedTyped = normalize(typedInput).lowercased()
        
        while i < min(normalizedTyped.count, normalizedTarget.count) {
            let typedIdx = normalizedTyped.index(normalizedTyped.startIndex, offsetBy: i)
            let targetIdx = normalizedTarget.index(normalizedTarget.startIndex, offsetBy: i)
            
            if normalizedTyped[typedIdx] != normalizedTarget[targetIdx] {
                break
            }
            i += 1
        }
        
        self.matchLen = i
        self.hasMismatch = normalizedTyped.count > matchLen
        self.isDoneEnabled = normalizedTyped == normalizedTarget
        
        // Auto-advance if correctly typed
        if isDoneEnabled && !showSuccessOverlay {
            handleDone()
        }
    }
    
    private func normalize(_ text: String) -> String {
        return text.trimmingCharacters(in: .whitespaces)
    }
    
    func handleDone() {
        guard isDoneEnabled else { return }
        
        hapticGenerator.notificationOccurred(.success)
        showSuccessOverlay = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self.showSuccessOverlay = false
            
            if self.roundIndex < self.totalRounds {
                self.roundIndex += 1
                self.timeRemaining = SettingsStore.shared.missionTimeLimitSeconds
                self.generateRound()
            } else {
                self.timerActive = false
                if !self.isPreviewMode {
                    PenaltyManager.shared.stopMissionMonitoring()
                }
                self.onComplete?()
            }
        }
    }
}
