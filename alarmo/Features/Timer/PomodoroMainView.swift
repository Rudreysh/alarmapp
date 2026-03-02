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
                        .font(.system(size: min(width * 0.28, 120), weight: .regular, design: .monospaced))
                        .kerning(2)
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
                    HStack(spacing: 44) {
                        // Skip / Break
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            if viewModel.currentStage == .focus {
                                viewModel.pomoRemainingSeconds = 0 // Simulates ending focus
                            } else {
                                viewModel.stopTimer()
                            }
                        } label: {
                            Image(systemName: "forward.end.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(viewModel.timerState == .idle ? Colors.textSecondary : TimerPalette.accentSoft)
                                .frame(width: 56, height: 56)
                                .background(Circle().fill(Color(red: 0.13, green: 0.15, blue: 0.20)))
                                .overlay(Circle().stroke(Color.white.opacity(0.10), lineWidth: 1))
                        }
                        .disabled(viewModel.timerState == .idle)
                        .opacity(viewModel.timerState == .idle ? 0.35 : 1)
                        
                        // Play / Pause
                        Button {
                            viewModel.toggleTimer()
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(TimerPalette.accent) // Matches stopwatch exactly
                                    .frame(width: 72, height: 72)
                                Image(systemName: viewModel.timerState == .running ? "pause.fill" : "play.fill")
                                    .font(.system(size: 26, weight: .bold))
                                    .foregroundColor(.black)
                            }
                            .shadow(color: TimerPalette.accent.opacity(0.5), radius: 16, y: 6)
                        }
                        
                        // Stop
                        Button {
                            showCompletion = true
                            viewModel.stopTimer()
                            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                        } label: {
                            Image(systemName: "square.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(viewModel.timerState == .idle ? Colors.textSecondary : Color(red: 0.9, green: 0.25, blue: 0.25))
                                .frame(width: 56, height: 56)
                                .background(Circle().fill(Color(red: 0.13, green: 0.15, blue: 0.20)))
                                .overlay(Circle().stroke(Color.white.opacity(0.10), lineWidth: 1))
                        }
                        .disabled(viewModel.timerState == .idle)
                        .opacity(viewModel.timerState == .idle ? 0.35 : 1)
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
