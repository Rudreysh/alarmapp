import SwiftUI

struct PomodoroMainView: View {
    @ObservedObject var viewModel: TimerViewModel
    
    // UI State for Completion Modal
    @State private var showCompletion = false
    
    var body: some View {
        let theme = PomodoroTheme(kind: viewModel.currentStage == .focus ? .focus : .break)
        
        ZStack {
            // Full Background
            theme.background
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.5), value: viewModel.currentStage)
            
            GeometryReader { geo in
                let width = geo.size.width
                let height = geo.size.height
                
                VStack(spacing: 0) {
                    // 1. Task Selector Pill (Top Center)
                    TaskPillView(
                        taskName: viewModel.selectedFocusMode,
                        theme: theme
                    ) {
                        viewModel.showFrequentlyUsedPomo = true
                    }
                    .padding(.top, 20)
                    
                    Spacer()
                    
                    // 2. Timer Digits (Large & Thin)
                    Text(viewModel.timeDisplay)
                        .font(.system(size: min(width * 0.28, 120), weight: .thin, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(theme.primaryText)
                        .transition(.scale.combined(with: .opacity))
                        .id("timer-\(viewModel.currentStage)") // Reset anim on stage change
                    
                    // 3. Mode Label (FOCUS / BREAK)
                    Text(viewModel.currentStage == .focus ? "FOCUS" : "BREAK")
                        .font(.system(size: 16, weight: .semibold))
                        .kerning(4)
                        .foregroundColor(theme.secondaryText)
                        .padding(.top, 4)
                    
                    // 4. Dial / Scale Visualization
                    DialScaleView(theme: theme, centerValue: Int(viewModel.pomoDurationSeconds / 60))
                        .padding(.top, 40)
                    
                    Spacer()
                    
                    // 5. Main Controls
                    VStack(spacing: 30) {
                        PrimaryPlayPauseButton(
                            isRunning: viewModel.timerState == .running,
                            theme: theme
                        ) {
                            viewModel.toggleTimer()
                        }
                        
                        // 6. Secondary Buttons (Break/Done)
                        if viewModel.timerState != .idle {
                            SecondaryActionButtonsRow(
                                theme: theme,
                                showBreak: viewModel.currentStage == .focus,
                                onBreak: {
                                    // Logic to jump to break
                                    // Using internal currentStage toggle if supported by VM
                                    // For now, mapping to existing VM logic if possible
                                    // VM has startBreak(), but it's private. handlePomoEnd calls it.
                                    // We can simulate end of focus.
                                    viewModel.pomoRemainingSeconds = 0
                                },
                                onDone: {
                                    showCompletion = true
                                    viewModel.stopTimer()
                                }
                            )
                        } else {
                            // Empty space to maintain layout when idle
                            Spacer().frame(height: 80)
                        }
                    }
                    .padding(.bottom, geo.safeAreaInsets.bottom > 0 ? 40 : 60)
                }
                .frame(width: width, height: height)
            }
        }
        .overlay {
            if showCompletion {
                ZStack {
                    Color.black.opacity(0.6)
                        .ignoresSafeArea()
                        .onTapGesture { showCompletion = false }
                    
                    CompletionCardView(
                        taskName: viewModel.selectedFocusMode,
                        sessions: 1, // Placeholder: VM could track session count
                        totalTime: formatTotalTime(viewModel.pomoDurationSeconds - viewModel.pomoRemainingSeconds),
                        onDone: { showCompletion = false }
                    )
                    .transition(.asymmetric(insertion: .scale(scale: 0.8).combined(with: .opacity), removal: .opacity))
                }
                .animation(.spring(), value: showCompletion)
            }
        }
    }
    
    private func formatTotalTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}
