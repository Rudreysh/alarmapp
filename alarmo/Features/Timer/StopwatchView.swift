import SwiftUI

struct StopwatchView: View {
    @ObservedObject var viewModel: TimerViewModel
    
    var body: some View {
        GeometryReader { geo in
            let availableWidth = geo.size.width
            let availableHeight = geo.size.height
            
            // Dynamic diameter calculation
            let diameter = min(availableWidth * 0.75, availableHeight * 0.45)
            let buttonSize: CGFloat = 50
            let playSize: CGFloat = 70
            
            VStack(spacing: 0) {
                FocusRow(title: viewModel.selectedFocusMode) {
                    viewModel.selectedFocusMode = "Focus" 
                }
                .padding(.top, Spacing.m)
                .frame(maxHeight: availableHeight * 0.15)
                
                Spacer()
                
                ZStack {
                    ProgressRing(progress: viewModel.progress, color: Colors.accentRed, showTicks: true)
                        .frame(width: diameter, height: diameter)
                    
                    Text(viewModel.timeDisplay)
                        .font(.system(size: diameter * 0.22, weight: .bold))
                        .monospacedDigit()
                        .foregroundColor(Colors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                
                Spacer()
                
                if viewModel.timerState == .idle {
                    PrimaryButton(title: "Start") {
                        viewModel.startTimer()
                    }
                    .padding(.horizontal, Spacing.l)
                    .padding(.bottom, Spacing.xl)
                } else {
                    // Running Controls
                    HStack(spacing: 40) {
                        // Placeholder (Equalizing layout with Pomo)
                        Spacer().frame(width: buttonSize)
                        
                        // Pause/Resume
                        Button(action: { viewModel.toggleTimer() }) {
                            Image(systemName: viewModel.timerState == .running ? "pause.fill" : "play.fill")
                                .font(.system(size: 24))
                                .foregroundColor(Colors.textPrimary)
                                .frame(width: playSize, height: playSize)
                                .background(Colors.accentRed)
                                .clipShape(Circle())
                                .appShadow(Shadows.button)
                        }
                        
                        // Stop
                        Button(action: { viewModel.stopTimer() }) {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 20))
                                .foregroundColor(Colors.textPrimary)
                                .frame(width: buttonSize, height: buttonSize)
                                .background(Circle().stroke(Colors.cardStroke, lineWidth: 1))
                        }
                    }
                    .padding(.bottom, Spacing.xl)
                }
            }
            .frame(width: availableWidth, height: availableHeight)
        }
    }
}
