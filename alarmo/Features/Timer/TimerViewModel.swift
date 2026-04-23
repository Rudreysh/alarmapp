import SwiftUI
import Combine

class TimerViewModel: ObservableObject {
    // Mode & State
    @Published var selectedMode: TimerMode = .pomo
    @Published var timerState: TimerState = .idle
    
    // Pomo
    @Published var pomoDurationSeconds: TimeInterval = 25 * 60
    @Published var pomoRemainingSeconds: TimeInterval = 25 * 60
    
    // Stopwatch
    @Published var stopwatchElapsedSeconds: TimeInterval = 0
    
    // UI States
    @Published var selectedFocusMode: String = "Focus"
    @Published var showFrequentlyUsedPomo = false
    @Published var showPomoDurationPicker = false
    @Published var showFocusSettings = false
    @Published var showAddFocusRecord = false
    @Published var showAddTimer = false
    @Published var showFocusNoteSheet = false
    @Published var showSoundSelection = false
    @Published var focusNote: String = ""
    
    // Persistence
    @Published var savedPresets: [TimerPreset] = TimerPreset.defaults
    
    // Duration Picker Mode
    @Published var isAddingNewDuration = false
    @Published var editingDurationIndex: Int? = nil
    
    enum PomoStage {
        case focus
        case breakTime
    }
    
    @Published var currentStage: PomoStage = .focus
    
    // Ambient Sound
    @Published var isAmbientPlaying: Bool = false
    let ambientSoundPlayer = SoundPlayer()
    
    let preferences: AppPreferences
    private var cancellables = Set<AnyCancellable>()
    private var timerPublisher: AnyCancellable?
    
    init(preferences: AppPreferences = AppPreferences()) {
        self.preferences = preferences
        let initialDuration = TimeInterval(preferences.pomoDurationMinutes * 60)
        self.pomoDurationSeconds = initialDuration
        self.pomoRemainingSeconds = initialDuration
        
        // Listen for toggles from LiveActivity Widget
        let name = CFNotificationName("ht.alarmo.togglePlayback" as CFString)
        let observer = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            observer,
            { (center, observer, name, object, userInfo) in
                if let observer = observer {
                    let viewModel = Unmanaged<TimerViewModel>.fromOpaque(observer).takeUnretainedValue()
                    Task { @MainActor in
                        viewModel.toggleAmbientSound()
                    }
                }
            },
            name.rawValue,
            nil,
            .deliverImmediately
        )
    }
    
    func toggleTimer() {
        if timerState == .running {
            pauseTimer()
        } else {
            startTimer()
        }
    }
    
    func startTimer() {
        if timerState == .idle {
            logEngineStart()
        }
        timerState = .running
        timerPublisher = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }
    
    private func logEngineStart() {
        if selectedMode == .pomo {
            print("[PomoEngine] start mode=\(currentStage) duration=\(preferences.pomoDurationMinutes) shortBreak=\(preferences.shortBreakMinutes)")
        } else if selectedMode == .stopwatch {
            print("[StopwatchEngine] start settings=active")
        } else {
            print("[CountdownEngine] start with preset configuration")
        }
    }
    
    func pauseTimer() {
        timerState = .paused
        timerPublisher?.cancel()
    }
    
    func stopTimer() {
        timerState = .idle
        timerPublisher?.cancel()
        if selectedMode == .pomo {
            pomoRemainingSeconds = pomoDurationSeconds
            currentStage = .focus
        } else if selectedMode == .stopwatch {
            stopwatchElapsedSeconds = 0
        }
        
        // Ensure ambient sound stops when timer stops
        if isAmbientPlaying {
            toggleAmbientSound()
        }
    }
    
    private func tick() {
        if selectedMode == .pomo {
            if pomoRemainingSeconds > 0 {
                pomoRemainingSeconds -= 1
            } else {
                handlePomoEnd()
            }
        } else if selectedMode == .stopwatch {
            stopwatchElapsedSeconds += 1
        }
    }
    
    private func handlePomoEnd() {
        if currentStage == .focus {
            print("[PomoEngine] Focus session ended, sound=\(preferences.pomoEndingSoundName)")
            
            // Logic to be improved: pass actual taskId if VM had access to it easily. 
            // For now, tracking at higher level or just using taskId parameter.
            completePomodoroSession(taskId: nil, durationSeconds: Int(pomoDurationSeconds), endedAt: Date())
            
            if preferences.autoStartBreak {
                startBreak()
            } else {
                stopTimer()
            }
        } else {
            print("[PomoEngine] Break session ended, sound=\(preferences.breakEndingSoundName)")
            if preferences.autoStartNextPomo {
                startFocus()
            } else {
                stopTimer()
            }
        }
    }
    
    private func startBreak() {
        currentStage = .breakTime
        pomoDurationSeconds = TimeInterval(preferences.shortBreakMinutes * 60)
        pomoRemainingSeconds = pomoDurationSeconds
        print("[PomoEngine] Auto-starting break duration=\(preferences.shortBreakMinutes)")
        // Sound and Haptics would play here
    }
    
    private func startFocus() {
        currentStage = .focus
        pomoDurationSeconds = TimeInterval(preferences.pomoDurationMinutes * 60)
        pomoRemainingSeconds = pomoDurationSeconds
        print("[PomoEngine] Auto-starting next Pomo duration=\(preferences.pomoDurationMinutes)")
    }
    
    var pomoEndingSoundName: String {
        preferences.pomoEndingSoundName
    }
    
    func setPomoEndingSound(_ soundName: String) {
        preferences.pomoEndingSoundName = soundName
    }
    
    var ambientSoundName: String {
        preferences.ambientSoundName
    }
    
    func setAmbientSound(_ soundName: String) {
        preferences.ambientSoundName = soundName
        if isAmbientPlaying {
            ambientSoundPlayer.playLooping(resourceName: soundName, volume: 1.0, fadeDuration: 1.0)
        }
        updateLiveActivityAmbientState()
    }
    
    func toggleAmbientSound() {
        if isAmbientPlaying {
            ambientSoundPlayer.stop()
            isAmbientPlaying = false
        } else {
            let sound = preferences.ambientSoundName
            if !sound.isEmpty {
                ambientSoundPlayer.playLooping(resourceName: sound, volume: 1.0, fadeDuration: 1.0)
                isAmbientPlaying = true
            } else {
                showSoundSelection = true
            }
        }
        updateLiveActivityAmbientState()
    }
    
    private func updateLiveActivityAmbientState() {
        LiveActivityManager.shared.updateAmbientState(
            isAmbientPlaying: isAmbientPlaying,
            ambientSoundName: preferences.ambientSoundName
        )
    }
    
    func setPomoDuration(_ seconds: TimeInterval) {
        pomoDurationSeconds = seconds
        pomoRemainingSeconds = seconds
        stopTimer()
    }
    
    func addPreset(name: String, icon: String, mode: TimerMode, duration: TimeInterval) {
        let newPreset = TimerPreset(name: name, icon: icon, mode: mode, duration: duration)
        savedPresets.append(newPreset)
    }
    
    func applyPreset(_ preset: TimerPreset) {
        if preset.mode == .pomo {
            selectedMode = .pomo
            selectedFocusMode = preset.name
            pomoDurationSeconds = preset.duration
            pomoRemainingSeconds = preset.duration
            currentStage = .focus
            stopTimer()
        } else if preset.mode == .stopwatch {
            selectedMode = .stopwatch
            selectedFocusMode = preset.name
            stopTimer()
        } else {
            selectedMode = .countdown
            selectedFocusMode = preset.name
            stopTimer()
        }
        
        // Also update the overridden name if applicable (for Pomo)
        // Note: For Stopwatch, logic might be different
        if preset.mode == .pomo {
             // In a real app we might want to tell the PomoEngine about the name override too
        }
    }
    
    func completePomodoroSession(taskId: UUID?, durationSeconds: Int, endedAt: Date) {
        print("[TimerHistory] Session completed. task=\(taskId?.uuidString ?? "none") duration=\(durationSeconds) endedAt=\(endedAt)")
    }
    
    var timeDisplay: String {
        let totalSeconds: Int
        if selectedMode == .pomo {
            totalSeconds = Int(pomoRemainingSeconds)
        } else {
            totalSeconds = Int(stopwatchElapsedSeconds)
        }
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    var progress: Double {
        if selectedMode == .pomo {
            return 1.0 - (pomoRemainingSeconds / pomoDurationSeconds)
        } else {
            // No absolute progress for stopwatch, maybe use for a visual effect
            return stopwatchElapsedSeconds.truncatingRemainder(dividingBy: 60) / 60.0
        }
    }
    
    var buttonTitle: String {
        switch timerState {
        case .idle: return "Start"
        case .running: return "Pause"
        case .paused: return "Resume"
        }
    }
}
