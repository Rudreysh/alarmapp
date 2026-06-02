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
                VStack(spacing: 4) {
                    Text("App Audio Settings")
                        .font(.system(size: 23, weight: .bold))
                        .foregroundColor(Colors.textPrimary)
                    Text(viewModel.volumePercentText)
                        .font(.system(size: 17, weight: .bold, design: .monospaced))
                        .foregroundColor(Colors.accentTeal)
                }
                .padding(.horizontal, Spacing.l)
                .padding(.top, Spacing.s)
                .padding(.bottom, 2)

                ProgressHeader(step: 10, total: AppConstants.onboardingTotalSteps)
                    .padding(.horizontal, Spacing.l)
                    .padding(.top, 4)
                    .padding(.bottom, Spacing.s)

                ScrollView(showsIndicators: false) {
                    VolumeInteractiveDashboard(
                        volume: $viewModel.volume,
                        volumeText: viewModel.volumePercentText,
                        gentleWakeUpEnabled: $viewModel.gentleWakeUpEnabled,
                        isPlaying: viewModel.isPlaying,
                        isBuffering: viewModel.isBuffering,
                        onPreview: { viewModel.preview() }
                    )
                    .padding(.bottom, 120) // keep bottom cards fully visible above Next button
                }
            }
            .onboardingContentFrame()
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: "Next", style: .blueGlass) {
                    onboardingViewModel.setVolume(viewModel.volume)
                    onboardingViewModel.setGentleWakeUp(viewModel.gentleWakeUpEnabled)
                    onNext()
                }
                .padding(.horizontal, Spacing.l)
                .padding(.bottom, Spacing.m)
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
    
    // Requested tuning:
    // - Overall App Audio Settings UI +10%
    // - Volume slider height -20%
    private let volumeSliderHeight: CGFloat = 192

    var body: some View {
        VStack(spacing: Spacing.s) {
            HStack(spacing: Spacing.s) {
                CustomVolumeSlider(volume: $volume)
                    .frame(width: 57, height: volumeSliderHeight)
                    
                VStack(spacing: Spacing.xs) {
                    FeatureToggleRow(icon: "iphone.radiowaves.left.and.right", title: "Vibrate on Alarm", subtitle: "Haptics on ring", isOn: $vibrateEnabled)
                    FeatureToggleRow(icon: "bell.badge.fill", title: "Override Silent", subtitle: "Force maximum alarm volume", isOn: $overrideSilent)
                    FeatureToggleRow(icon: "timer", title: "Auto-dismiss", subtitle: "Alarm stops after 10m", isOn: $autoDismiss)
                    FeatureToggleRow(icon: "clock.badge.checkmark", title: "Pomodoro Ticks", subtitle: "Play sound during focus", isOn: $pomoTicks)
                    FeatureToggleRow(icon: "flame.fill", title: "Strict Habits", subtitle: "Must complete on schedule", isOn: $strictHabits)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Spacing.l)

            HStack(spacing: Spacing.m) {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        gentleWakeUpEnabled.toggle()
                    }
                }) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "sunrise.fill")
                            .font(.system(size: 15, weight: .bold))
                                .foregroundColor(gentleWakeUpEnabled ? .white : Colors.accentTeal)
                            Spacer()
                            if gentleWakeUpEnabled {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white)
                            } else {
                                Circle()
                                    .stroke(Colors.cardStroke, lineWidth: 2)
                                    .frame(width: 13, height: 13)
                            }
                        }
                        Text("Gentle Wake")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(gentleWakeUpEnabled ? .white : Colors.textPrimary)
                        Text("30s Fade in")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(gentleWakeUpEnabled ? .white.opacity(0.8) : Colors.textSecondary)
                    }
                    .padding(11)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 82)
                    .background(gentleWakeUpEnabled ? Colors.accentTeal : Colors.cardSurface)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(gentleWakeUpEnabled ? Colors.accentTeal : Colors.cardStroke, lineWidth: 1)
                    )
                    .appShadow(Shadows.card)
                }
                .buttonStyle(PressedScaleButtonStyle())

                Button(action: onPreview) {
                    VStack(spacing: 8) {
                        if isBuffering {
                            ProgressView().tint(Colors.accentTeal)
                                .scaleEffect(1.0)
                        } else if isPlaying {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(Colors.accentRed)
                            Text("Stop")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Colors.accentRed)
                        } else {
                            Image(systemName: "play.fill")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(Colors.accentTeal)
                            Text("Preview")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Colors.accentTeal)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 82)
                    .background(Colors.cardSurface)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Colors.cardStroke, lineWidth: 1)
                    )
                    .appShadow(Shadows.card)
                }
                .buttonStyle(PressedScaleButtonStyle())
            }
            .padding(.horizontal, Spacing.l)
            .padding(.top, 2)
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
                    .frame(width: 24, height: 24)
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(isOn ? Colors.accentTeal : Colors.textSecondary)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
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
                // Width reduced by ~10% while preserving vertical legibility.
                .scaleEffect(x: 0.63, y: 0.70, anchor: .center)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(Colors.cardSurface)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
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
                RoundedRectangle(cornerRadius: 28)
                    .fill(Colors.cardSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(Colors.cardStroke, lineWidth: 1)
                    )
                    .appShadow(Shadows.card)
                
                // Active Fill
                RoundedRectangle(cornerRadius: 28)
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
                            .padding(.horizontal, 12)
                        Spacer()
                    }
                }
                .padding(.vertical, 24)
                
                // Volume Icon sitting inside the slider
                VStack {
                    Spacer()
                    Image(systemName: volume == 0 ? "speaker.slash.fill" : "speaker.wave.3.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(volume > 0.15 ? .white : Colors.textSecondary)
                        .padding(.bottom, 18)
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
