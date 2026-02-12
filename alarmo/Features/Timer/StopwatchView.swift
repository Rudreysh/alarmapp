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
            
            ZStack {
                LinearGradient(
                    colors: [
                        Color.black,
                        Color(red: 0.02, green: 0.03, blue: 0.06),
                        Color(red: 0.03, green: 0.06, blue: 0.10),
                        Color(red: 0.02, green: 0.03, blue: 0.06),
                        Color.black
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .overlay(alignment: .top) {
                    RoundedRectangle(cornerRadius: 80, style: .continuous)
                        .fill(
                            RadialGradient(
                                colors: [
                                    TimerPalette.accentSoft.opacity(0.20),
                                    .clear
                                ],
                                center: .center,
                                startRadius: 20,
                                endRadius: 320
                            )
                        )
                        .frame(width: availableWidth * 0.40, height: 300)
                        .blur(radius: 24)
                        .offset(y: -100)
                }
                .overlay(alignment: .bottom) {
                    Ellipse()
                        .fill(
                            RadialGradient(
                                colors: [
                                    TimerPalette.accent.opacity(0.14),
                                    .clear
                                ],
                                center: .center,
                                startRadius: 10,
                                endRadius: 240
                            )
                        )
                        .frame(width: availableWidth * 0.70, height: 140)
                        .blur(radius: 14)
                        .offset(y: 70)
                }
                .allowsHitTesting(false)

                VStack(spacing: 0) {
                    FocusRow(title: viewModel.selectedFocusMode) {
                        viewModel.selectedFocusMode = "Focus"
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.10))
                            .background(.ultraThinMaterial, in: Capsule())
                    )
                    .overlay(
                        Capsule()
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.34), Color.white.opacity(0.10)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Color.black.opacity(0.26), radius: 10, x: 0, y: 5)
                    .padding(.top, Spacing.m)
                    .frame(maxHeight: availableHeight * 0.15)
                    
                    Spacer()
                    
                    ZStack {
                        ProgressRing(progress: viewModel.progress, color: TimerPalette.accent, showTicks: true)
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
                        Button {
                            viewModel.startTimer()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 18, weight: .bold))
                                Text("Start")
                                    .font(.system(size: 22, weight: .semibold))
                            }
                            .foregroundColor(.white.opacity(0.95))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                TimerPalette.accentSoft.opacity(0.68),
                                                TimerPalette.accentStrong.opacity(0.72),
                                                TimerPalette.accent.opacity(0.70)
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .stroke(
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.42), Color.white.opacity(0.14)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        ),
                                        lineWidth: 1
                                    )
                            )
                            .shadow(color: TimerPalette.accent.opacity(0.20), radius: 14, x: 0, y: 8)
                        }
                        .buttonStyle(PressedScaleButtonStyle())
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
                                    .background(
                                        Circle()
                                            .fill(Color.white.opacity(0.12))
                                            .background(.ultraThinMaterial, in: Circle())
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.24), lineWidth: 1)
                                    )
                                    .shadow(color: TimerPalette.accent.opacity(0.18), radius: 14, x: 0, y: 8)
                            }
                            
                            // Stop
                            Button(action: { viewModel.stopTimer() }) {
                                Image(systemName: "stop.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(Colors.textPrimary)
                                    .frame(width: buttonSize, height: buttonSize)
                                    .background(
                                        Circle()
                                            .fill(Color.white.opacity(0.10))
                                            .background(.ultraThinMaterial, in: Circle())
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.22), lineWidth: 1)
                                    )
                            }
                        }
                        .padding(.bottom, Spacing.xl)
                    }
                }
                .frame(width: availableWidth, height: availableHeight)
            }
        }
    }
}
