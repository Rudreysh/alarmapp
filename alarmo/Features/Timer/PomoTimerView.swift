import SwiftUI

struct PomoTimerView: View {
    @ObservedObject var viewModel: TimerViewModel
    
    var body: some View {
        GeometryReader { geo in
            let availableWidth = geo.size.width
            let availableHeight = geo.size.height
            
            // Dynamic diameter calculation
            // Clamp min to ensure it's not too small on tiny devices, max for large ones
            let diameter = min(availableWidth * 0.75, availableHeight * 0.45)
            let buttonSize: CGFloat = 50
            let playSize: CGFloat = 70
            
            VStack(spacing: 0) {
                FocusRow(title: viewModel.selectedFocusMode) {
                    viewModel.showAddFocusRecord = true
                }
                .padding(.top, Spacing.m)
                .frame(maxHeight: availableHeight * 0.15) // Limit top section
                
                Spacer()
                
                // Timer Circle
                Button(action: {
                    if viewModel.timerState == .idle {
                        viewModel.showFrequentlyUsedPomo = true
                    }
                }) {
                    ZStack {
                        ProgressRing(progress: viewModel.progress, color: Colors.accentRed)
                            .frame(width: diameter, height: diameter)
                        
                        Text(viewModel.timeDisplay)
                            .font(.system(size: diameter * 0.22, weight: .bold)) // Dynamic font size
                            .monospacedDigit()
                            .foregroundColor(Colors.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                // Controls
                VStack(spacing: Spacing.m) {
                    if viewModel.timerState == .idle {
                        PrimaryButton(title: "Start") {
                            viewModel.startTimer()
                        }
                        .padding(.horizontal, Spacing.l)
                    } else {
                        // Running Controls
                        HStack(spacing: 40) {
                            // Sound Selection
                            Button(action: { viewModel.showSoundSelection = true }) {
                                Image(systemName: "music.note")
                                    .font(.system(size: 20))
                                    .foregroundColor(Colors.textPrimary)
                                    .frame(width: buttonSize, height: buttonSize)
                                    .background(Circle().stroke(Colors.cardStroke, lineWidth: 1))
                            }
                            .sheet(isPresented: $viewModel.showSoundSelection) {
                                SoundPickerView(selectedSound: Binding(
                                    get: { viewModel.pomoEndingSoundName },
                                    set: { viewModel.setPomoEndingSound($0) }
                                ))
                            }
                            
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
                    }
                    
                    if viewModel.timerState != .idle {
                        Button(action: { viewModel.showFocusNoteSheet = true }) {
                            Text("Add Focus Note")
                                .font(.caption) // Dynamic type
                                .foregroundColor(Colors.textSecondary)
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(.bottom, Spacing.xl)
            }
            .frame(width: availableWidth, height: availableHeight)
        }
        .sheet(isPresented: $viewModel.showFrequentlyUsedPomo) {
            FrequentlyUsedPomoSheet(viewModel: viewModel)
        }
    }
}

