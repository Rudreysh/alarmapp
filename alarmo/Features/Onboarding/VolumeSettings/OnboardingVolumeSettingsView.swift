import SwiftUI

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
            Colors.bgPrimary.ignoresSafeArea()

            VStack(spacing: Spacing.l) {
                ProgressHeader(step: 3, total: AppConstants.onboardingTotalSteps)
                    .padding(.horizontal, Spacing.l)
                    .padding(.top, Spacing.l)

                Spacer()

                VolumeSheet(
                    volume: $viewModel.volume,
                    volumeText: viewModel.volumePercentText,
                    gentleWakeUpEnabled: $viewModel.gentleWakeUpEnabled,
                    onPreview: { viewModel.preview() }
                )

                Spacer()
            }
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: "Next", style: .blueGlass) {
                    onboardingViewModel.setVolume(viewModel.volume)
                    onboardingViewModel.setGentleWakeUp(viewModel.gentleWakeUpEnabled)
                    onNext()
                }
                .padding(.horizontal, Spacing.l)
                .padding(.bottom, Spacing.m)
            }
        }
    }
}

private struct VolumeSheet: View {
    @Binding var volume: Float
    let volumeText: String
    @Binding var gentleWakeUpEnabled: Bool
    let onPreview: () -> Void

    var body: some View {
        VStack(spacing: Spacing.l) {
            Text("Set the volume")
                .screenTitle()
                .foregroundColor(Colors.textPrimary)

            VStack(spacing: Spacing.l) {
                HStack {
                    Text("Volume")
                        .bodyText()
                        .foregroundColor(Colors.textPrimary)
                    Spacer()
                    Text(volumeText)
                        .bodyText()
                        .foregroundColor(Colors.textSecondary)
                }

                HStack(spacing: Spacing.m) {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundColor(Colors.textSecondary)

                    Slider(value: Binding(
                        get: { Double(volume) },
                        set: { volume = Float($0) }
                    ), in: 0...1)
                    .tint(Colors.textPrimary)
                }

                Divider().background(Colors.cardStroke)

                HStack {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Gentle wake-up")
                            .bodyText()
                            .foregroundColor(Colors.textPrimary)
                        Text("Gradually increase for 30 seconds")
                            .captionText()
                            .foregroundColor(Colors.textSecondary)
                    }

                    Spacer()

                    Toggle("", isOn: $gentleWakeUpEnabled)
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle(tint: Colors.accentTeal))
                }
            }
            .padding(Spacing.l)
            .background(Colors.cardSurface)
            .cornerRadius(Radii.card)

            Button(action: onPreview) {
                HStack(spacing: Spacing.s) {
                    Image(systemName: "play.fill")
                    Text("Preview")
                        .bodyText()
                }
                .foregroundColor(Colors.accentTeal)
            }
        }
        .padding(.horizontal, Spacing.l)
        .padding(.vertical, Spacing.xl)
        .background(Colors.bgSecondary)
        .cornerRadius(Radii.card)
        .overlay(
            RoundedRectangle(cornerRadius: Radii.card)
                .stroke(Colors.cardStroke, lineWidth: 1)
        )
        .appShadow(Shadows.card)
        .padding(.horizontal, Spacing.l)
    }
}
