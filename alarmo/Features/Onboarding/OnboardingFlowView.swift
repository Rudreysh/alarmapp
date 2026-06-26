import SwiftUI

struct OnboardingFlowView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @ObservedObject var appPreferences: AppPreferences
    @ObservedObject var alarmStore: AlarmStore
    @EnvironmentObject private var navStore: NavigationStore

    var body: some View {
        NavigationStack(path: $viewModel.navigationPath) {
            Group {
                if AlarmThemeStyle.persisted.usesTiimoLayoutBranch {
                    OnboardingIntroView(onNext: startSetupFlow, onSkip: skipOnboarding)
                } else {
                    WelcomeView(onContinue: startSetupFlow, onSkip: skipOnboarding)
                }
            }
            .navigationDestination(for: OnboardingStep.self) { step in
                destination(for: step)
            }
        }
        .environment(\.usesOnboardingDefaultWhiteButton, true)
        .tint(Colors.accentTeal)
    }

    @ViewBuilder
    private func destination(for step: OnboardingStep) -> some View {
        switch step {
        case .intro:
            EmptyView()

        case .namePrompt:
            OnboardingNameView(viewModel: viewModel) { go(.morningProblem) }

        // MARK: Alarm diagnosis
        case .morningProblem:
            OnboardingMorningProblemView(viewModel: viewModel) { go(.snoozeFrequency) }
        case .snoozeFrequency:
            OnboardingSnoozeCountQuestionView(viewModel: viewModel) { go(.alarmDifficulty) }
        case .alarmDifficulty:
            OnboardingAlarmDifficultyView(viewModel: viewModel) { go(.blockingTransition) }

        // MARK: App-blocking transition + diagnosis
        case .blockingTransition:
            OnboardingBlockingTransitionView(viewModel: viewModel) { go(.appsWhen) }
        case .appsWhen:
            OnboardingAppsWhenView(viewModel: viewModel) { go(.screenTime) }
        case .screenTime:
            OnboardingScreenTimeView(viewModel: viewModel) { go(.appsToBlock) }
        case .appsToBlock:
            OnboardingAppsToBlockView(viewModel: viewModel) { go(.dailyLoopInsight) }

        // MARK: Insight + hope
        case .dailyLoopInsight:
            OnboardingDailyLoopInsightView(viewModel: viewModel) { go(.hopePillars) }
        case .hopePillars:
            OnboardingHopePillarsView(viewModel: viewModel) { go(.setTime) }

        // MARK: Setup
        case .setTime:
            OnboardingSetTimeView(viewModel: viewModel) {
                appPreferences.onboardingAlarmHour = viewModel.selectedHour
                appPreferences.onboardingAlarmMinute = viewModel.selectedMinute
                appPreferences.onboardingAlarmSecond = viewModel.selectedSecond
                go(.missionType)
            }
        case .missionType:
            OnboardingMissionPickerView(viewModel: viewModel) { go(.blockingSchedule) }
        case .blockingSchedule:
            OnboardingBlockingScheduleView(viewModel: viewModel) { go(.soundSelection) }
        case .soundSelection:
            OnboardingSoundSelectionView(onboardingViewModel: viewModel) { go(.soundVolume) }
        case .soundVolume:
            OnboardingVolumeSettingsView(onboardingViewModel: viewModel) { go(.alarmPermission) }

        // MARK: Permissions
        case .alarmPermission:
            OnboardingAlarmPermissionView(viewModel: viewModel) { go(.screenTimeAccess) }
        case .screenTimeAccess:
            OnboardingScreenTimeAccessView(viewModel: viewModel) {
                // Camera step only when the chosen mission needs the camera.
                go(viewModel.missionRequiresCamera ? .cameraAccess : .planSummary)
            }
        case .cameraAccess:
            OnboardingCameraAccessView(viewModel: viewModel) { go(.planSummary) }

        // MARK: Finish
        case .planSummary:
            OnboardingPlanSummaryView(viewModel: viewModel) { go(.trackingExplainer) }
        case .trackingExplainer:
            TrackingExplainerView { go(.paywall) }
        case .paywall:
            PaywallView(onClose: { completeOnboardingAndCreateAlarm() },
                        onSuccess: { completeOnboardingAndCreateAlarm() })
                .navigationBarBackButtonHidden(true)
        }
    }

    // MARK: - Navigation helpers

    private func go(_ step: OnboardingStep) {
        withAnimation(.easeInOut) {
            viewModel.setStep(step)
            viewModel.navigationPath.append(step)
        }
    }

    private func startSetupFlow() {
        withAnimation(.easeInOut) {
            viewModel.startSetupFlowFromIntroCTA()
        }
    }

    private func skipOnboarding() {
        withAnimation(.easeInOut) {
            appPreferences.devAlwaysShowOnboarding = false
            appPreferences.forceShowOnboardingNextLaunch = false
            appPreferences.onboardingCompleted = true
            viewModel.completeOnboarding()
        }
    }

    // MARK: - Completion

    /// Builds the first alarm from the onboarding answers and applies the safe
    /// feature defaults (snooze cap/interval, stop mission, app blocking). Shared
    /// by the paywall's close and purchase paths.
    private func completeOnboardingAndCreateAlarm() {
        withAnimation(.easeInOut) {
            appPreferences.devAlwaysShowOnboarding = false
            appPreferences.onboardingCompleted = true
            appPreferences.forceShowOnboardingNextLaunch = false
            // Reset so Home shows the 50% + discount sheet once after onboarding completes.
            appPreferences.hasShownFirstHomeDiscountFlow = false
            appPreferences.onboardingAlarmHour = viewModel.selectedHour
            appPreferences.onboardingAlarmMinute = viewModel.selectedMinute
            appPreferences.onboardingAlarmSecond = viewModel.selectedSecond
            appPreferences.onboardingRepeatMask = RepeatMask.monToSat
            appPreferences.onboardingAlarmEnabled = true
            appPreferences.onboardingSoundName = viewModel.state.selectedSoundName ?? "Cockpit Alert"
            appPreferences.onboardingSoundVolume = viewModel.state.selectedVolume
            appPreferences.onboardingWallpaperId = viewModel.state.selectedWallpaper?.id ?? "default"

            // Persist app-blocking choices to the live blocking settings.
            viewModel.applyBlockingSettingsToSystem()

            let newAlarm = Alarm(
                id: alarmStore.alarms.first?.id ?? UUID(),
                name: "Alarm",
                emoji: "🌞",
                hour: viewModel.selectedHour,
                minute: viewModel.selectedMinute,
                second: viewModel.selectedSecond,
                isDaily: true,
                repeatMask: RepeatMask.monToSat,
                enabled: true,
                wakeUpCheckEnabled: false,
                soundName: viewModel.state.selectedSoundName ?? "Cockpit Alert",
                soundVolume: viewModel.state.selectedVolume,
                vibrateEnabled: true,
                gentleWakeUpSeconds: 30,
                timeReminderEnabled: false,
                weatherReminderEnabled: false,
                labelReminderEnabled: false,
                extraLoudEnabled: false,
                snoozeMinutes: viewModel.resolvedSnoozeMinutes,
                snoozeCount: viewModel.resolvedSnoozeCount,
                wallpaperId: viewModel.state.selectedWallpaper?.id ?? "default",
                dailyMotivationEnabled: viewModel.state.dailyMotivationEnabled,
                createdAt: Date(),
                missions: viewModel.resolvedMissions(),
                blockAppsEnabled: viewModel.resolvedBlockAppsEnabled
            )
            if alarmStore.alarms.isEmpty {
                alarmStore.add(newAlarm)
            } else {
                alarmStore.update(newAlarm)
            }
            appPreferences.hasAnyAlarm = !alarmStore.alarms.isEmpty
            viewModel.completeOnboarding()
        }
    }
}
