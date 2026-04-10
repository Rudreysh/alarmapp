import SwiftUI
import UIKit
import AVFoundation
struct OnboardingVolumeSettingsView: View {
    @ObservedObject var onboardingViewModel: OnboardingViewModel
    @StateObject private var viewModel: OnboardingVolumeSettingsViewModel
    let onNext: () -> Void

    init(onboardingViewModel: OnboardingViewModel, onNext: @escaping () -> Void) {
        self.onboardingViewModel = onboardingViewModel
        self._viewModel = StateObject(wrappedValue: OnboardingVolumeSettingsViewModel(
            volume: onboardingViewModel.state.selectedVolume,
            gentleWakeUpEnabled: onboardingViewModel.state.gentleWakeUpEnabled,
            selectedSoundURL: onboardingViewModel.state.selectedSoundURL
        ))
        self.onNext = onNext
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Colors.bgSecondary, Colors.bgPrimary], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ProgressHeader(step: 9, total: AppConstants.onboardingTotalSteps)
                    .padding(.horizontal, Spacing.l)
                    .padding(.top, Spacing.m)
                    .padding(.bottom, Spacing.m)

                ScrollView(showsIndicators: false) {
                    VolumeInteractiveDashboard(
                        volume: $viewModel.volume,
                        volumeText: viewModel.volumePercentText,
                        gentleWakeUpEnabled: $viewModel.gentleWakeUpEnabled,
                        isPlaying: viewModel.isPlaying,
                        isBuffering: viewModel.isBuffering,
                        onPreview: { viewModel.preview() }
                    )
                    .padding(.bottom, 80) // bottom padding for scroll offset above the next button
                }
            }
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: "Next", style: .blueGlass) {
                    onboardingViewModel.setVolume(viewModel.volume)
                    onboardingViewModel.setGentleWakeUp(viewModel.gentleWakeUpEnabled)
                    onNext()
                }
                .padding(.horizontal, Spacing.l)
                .padding(.bottom, 48) // Raised next button higher as requested
            }
            .onDisappear {
                viewModel.stopPlayback()
            }
        }
    }
}

private struct VolumeInteractiveDashboard: View {
    @Binding var volume: Float
    let volumeText: String
    @Binding var gentleWakeUpEnabled: Bool
    let isPlaying: Bool
    let isBuffering: Bool
    let onPreview: () -> Void

    @State private var vibrateEnabled: Bool = true
    @State private var overrideSilent: Bool = true
    @State private var autoDismiss: Bool = true
    @State private var pomoTicks: Bool = false
    @State private var strictHabits: Bool = true

    var body: some View {
        VStack(spacing: Spacing.m) {
            
            VStack(spacing: 4) {
                Text("App Audio Settings")
                    .font(.system(size: 28, weight: .bold)) // Bolder, larger
                    .foregroundColor(Colors.textPrimary)
                Text("\(Int(volume * 100))%")
                    .font(.system(size: 20, weight: .bold, design: .monospaced)) // Slightly larger
                    .foregroundColor(Colors.accentTeal)
            }
            .padding(.top, 0)

            HStack(spacing: Spacing.m) {
                // Custom volume slider, 30% smaller horizontally (70 width)
                // Height will dynamically match the VStack adjacent to it.
                CustomVolumeSlider(volume: $volume)
                    .frame(width: 70)
                    
                // Space utilization: Toggles for all Alarmo Features
                VStack(spacing: Spacing.xs) {
                    FeatureToggleRow(icon: "iphone.radiowaves.left.and.right", title: "Vibrate on Alarm", subtitle: "Haptics on ring", isOn: $vibrateEnabled)
                    FeatureToggleRow(icon: "bell.badge.fill", title: "Override Silent", subtitle: "Force maximum alarm volume", isOn: $overrideSilent)
                    FeatureToggleRow(icon: "timer", title: "Auto-dismiss", subtitle: "Alarm stops after 10m", isOn: $autoDismiss)
                    FeatureToggleRow(icon: "clock.badge.checkmark", title: "Pomodoro Ticks", subtitle: "Play sound during focus", isOn: $pomoTicks)
                    FeatureToggleRow(icon: "flame.fill", title: "Strict Habits", subtitle: "Must complete on schedule", isOn: $strictHabits)
                }
            }
            .fixedSize(horizontal: false, vertical: true) // Forces HStack to match height of the toggles list
            .padding(.horizontal, Spacing.l)

            // Lower Action Controls (Reduced Sizes)
            HStack(spacing: Spacing.m) {
                // Gentle Wake Up
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        gentleWakeUpEnabled.toggle()
                    }
                }) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "sunrise.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(gentleWakeUpEnabled ? .white : Colors.accentTeal)
                            Spacer()
                            if gentleWakeUpEnabled {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                            } else {
                                Circle()
                                    .stroke(Colors.cardStroke, lineWidth: 2)
                                    .frame(width: 16, height: 16)
                            }
                        }
                        Spacer()
                        Text("Gentle Wake")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(gentleWakeUpEnabled ? .white : Colors.textPrimary)
                        Text("30s Fade in")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(gentleWakeUpEnabled ? .white.opacity(0.8) : Colors.textSecondary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 85)
                    .background(gentleWakeUpEnabled ? Colors.accentTeal : Colors.cardSurface)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(gentleWakeUpEnabled ? Colors.accentTeal : Colors.cardStroke, lineWidth: 1)
                    )
                    .appShadow(Shadows.card)
                }
                .buttonStyle(PressedScaleButtonStyle())

                // Play / Stop Preview
                Button(action: onPreview) {
                    VStack(spacing: 8) {
                        if isBuffering {
                            ProgressView().tint(Colors.accentTeal)
                                .scaleEffect(1.2)
                        } else if isPlaying {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(Colors.accentRed)
                            Text("Stop")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Colors.accentRed)
                        } else {
                            Image(systemName: "play.fill")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(Colors.accentTeal)
                            Text("Preview")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Colors.accentTeal)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 85)
                    .background(Colors.cardSurface)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Colors.cardStroke, lineWidth: 1)
                    )
                    .appShadow(Shadows.card)
                }
                .buttonStyle(PressedScaleButtonStyle())
            }
            .padding(.horizontal, Spacing.l)
            
            Spacer()
        }
    }
}

private struct FeatureToggleRow: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: Spacing.s) {
            ZStack {
                Circle()
                    .fill(isOn ? Colors.accentTeal.opacity(0.15) : Colors.bgSecondary)
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(isOn ? Colors.accentTeal : Colors.textSecondary)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isOn ? Colors.textPrimary : Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(2)
                Text(subtitle)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(2)
            }
            Spacer(minLength: 4)
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: Colors.accentTeal))
                .scaleEffect(0.75)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Colors.cardSurface)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Colors.cardStroke, lineWidth: 1)
        )
        .appShadow(Shadows.card)
    }
}

private struct CustomVolumeSlider: View {
    @Binding var volume: Float

    var body: some View {
        GeometryReader { proxy in
            let height = proxy.size.height
            ZStack(alignment: .bottom) {
                // Background Track
                RoundedRectangle(cornerRadius: 36)
                    .fill(Colors.cardSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 36)
                            .stroke(Colors.cardStroke, lineWidth: 1)
                    )
                    .appShadow(Shadows.card)
                
                // Active Fill
                RoundedRectangle(cornerRadius: 36)
                    .fill(
                        LinearGradient(
                            colors: [Colors.accentTeal.opacity(0.7), Colors.accentTeal],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: max(0, min(height, height * CGFloat(volume))))
                    
                // Render tick marks inside
                VStack(spacing: 0) {
                    ForEach(0..<10) { _ in
                        Rectangle()
                            .fill(Colors.textSecondary.opacity(0.2))
                            .frame(height: 2)
                            .padding(.horizontal, 16) // narrowed padding for 70 width
                        Spacer()
                    }
                }
                .padding(.vertical, 32)
                
                // Volume Icon sitting inside the slider
                VStack {
                    Spacer()
                    Image(systemName: volume == 0 ? "speaker.slash.fill" : "speaker.wave.3.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(volume > 0.15 ? .white : Colors.textSecondary)
                        .padding(.bottom, 24)
                }
            }
            .contentShape(Rectangle()) // makes entire view draggable
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let percent = 1 - (value.location.y / height)
                        let newVolume = max(0, min(1, Float(percent)))
                        
                        let oldStep = Int(volume * 20)
                        let newStep = Int(newVolume * 20)
                        
                        if oldStep != newStep {
                            UISelectionFeedbackGenerator().selectionChanged()
                            AudioServicesPlaySystemSound(1157) // Native smooth iOS picker wheel tick sound
                        }
                        
                        volume = newVolume
                    }
            )
            .animation(.interactiveSpring(response: 0.1, dampingFraction: 0.8), value: volume)
        }
    }
}
