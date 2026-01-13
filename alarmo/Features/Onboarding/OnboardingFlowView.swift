import SwiftUI

struct OnboardingFlowView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @ObservedObject var appPreferences: AppPreferences
    @ObservedObject var alarmStore: AlarmStore
    @State private var path: [OnboardingStep] = []

    var body: some View {
        NavigationStack(path: $path) {
            OnboardingIntroView {
                withAnimation(.easeInOut) {
                    viewModel.nextStep()
                    path.append(.setTime)
                }
            }
            .navigationDestination(for: OnboardingStep.self) { step in
                switch step {
                case .setTime:
                    OnboardingSetTimeView(viewModel: viewModel) {
                        withAnimation(.easeInOut) {
                            appPreferences.onboardingAlarmHour = viewModel.selectedHour
                            appPreferences.onboardingAlarmMinute = viewModel.selectedMinute
                            viewModel.nextStep()
                            path.append(.permissions)
                        }
                    }
                case .permissions:
                    OnboardingPermissionsView(viewModel: viewModel) {
                        withAnimation(.easeInOut) {
                            path.append(.wallpaper)
                        }
                    }
                case .wallpaper:
                    OnboardingWallpaperSelectionView(viewModel: viewModel) {
                        withAnimation(.easeInOut) {
                            viewModel.nextStep()
                            path.append(.wallpaperPreview)
                        }
                    }
                case .wallpaperPreview:
                    OnboardingWallpaperPreviewView(viewModel: viewModel) {
                        withAnimation(.easeInOut) {
                            if !path.isEmpty {
                                path.removeLast()
                            }
                            viewModel.setStep(.wallpaper)
                        }
                    } onSelect: {
                        withAnimation(.easeInOut) {
                            viewModel.nextStep()
                            path.append(.soundSelection)
                        }
                    }
                case .soundSelection:
                    OnboardingSoundSelectionView(onboardingViewModel: viewModel) {
                        withAnimation(.easeInOut) {
                            viewModel.nextStep()
                            path.append(.soundVolume)
                        }
                    }
                case .soundVolume:
                    OnboardingVolumeSettingsView(onboardingViewModel: viewModel) {
                        withAnimation(.easeInOut) {
                            viewModel.nextStep()
                            path.append(.missionStub)
                        }
                    }
                case .missionStub:
                    OnboardingMissionView(onboardingViewModel: viewModel) {
                        withAnimation(.easeInOut) {
                            if !path.isEmpty {
                                path.removeLast()
                            }
                            viewModel.setStep(.soundVolume)
                        }
                    } onDone: {
                        withAnimation(.easeInOut) {
                            path.append(.trackingExplainer)
                        }
                    }
                case .trackingExplainer:
                    TrackingExplainerView {
                        withAnimation(.easeInOut) {
                            path.append(.paywall)
                        }
                    }
                case .paywall:
                    PaywallView(onClose: {
                        withAnimation(.easeInOut) {
                            appPreferences.onboardingCompleted = true
                            appPreferences.onboardingAlarmHour = viewModel.selectedHour
                            appPreferences.onboardingAlarmMinute = viewModel.selectedMinute
                            appPreferences.onboardingRepeatMask = RepeatMask.monToSat
                            appPreferences.onboardingAlarmEnabled = true
                            appPreferences.onboardingSoundName = viewModel.state.selectedSoundName ?? "Orkney"
                            appPreferences.onboardingSoundVolume = viewModel.state.selectedVolume
                            appPreferences.onboardingWallpaperId = viewModel.state.selectedWallpaper?.id ?? "default"
                            let newAlarm = Alarm(
                                id: alarmStore.alarms.first?.id ?? UUID(),
                                name: "Alarm",
                                emoji: "🌞",
                                hour: viewModel.selectedHour,
                                minute: viewModel.selectedMinute,
                                isDaily: true,
                                repeatMask: RepeatMask.monToSat,
                                enabled: true,
                                wakeUpCheckEnabled: false,
                                soundName: viewModel.state.selectedSoundName ?? "Orkney",
                                soundVolume: viewModel.state.selectedVolume,
                                vibrateEnabled: true,
                                gentleWakeUpSeconds: 30,
                                timeReminderEnabled: false,
                                weatherReminderEnabled: false,
                                labelReminderEnabled: false,
                                extraLoudEnabled: false,
                                snoozeMinutes: 5,
                                snoozeCount: 3,
                                wallpaperId: viewModel.state.selectedWallpaper?.id ?? "default",
                                createdAt: Date()
                            )
                            if alarmStore.alarms.isEmpty {
                                alarmStore.add(newAlarm)
                            } else {
                                alarmStore.update(newAlarm)
                            }
                            appPreferences.hasAnyAlarm = !alarmStore.alarms.isEmpty
                            viewModel.completeOnboarding()
                            path.removeAll()
                            path.append(.home)
                        }
                    }, onSuccess: {
                        withAnimation(.easeInOut) {
                            appPreferences.onboardingCompleted = true
                            appPreferences.onboardingAlarmHour = viewModel.selectedHour
                            appPreferences.onboardingAlarmMinute = viewModel.selectedMinute
                            appPreferences.onboardingRepeatMask = RepeatMask.monToSat
                            appPreferences.onboardingAlarmEnabled = true
                            appPreferences.onboardingSoundName = viewModel.state.selectedSoundName ?? "Orkney"
                            appPreferences.onboardingSoundVolume = viewModel.state.selectedVolume
                            appPreferences.onboardingWallpaperId = viewModel.state.selectedWallpaper?.id ?? "default"
                            let newAlarm = Alarm(
                                id: alarmStore.alarms.first?.id ?? UUID(),
                                name: "Alarm",
                                emoji: "🌞",
                                hour: viewModel.selectedHour,
                                minute: viewModel.selectedMinute,
                                isDaily: true,
                                repeatMask: RepeatMask.monToSat,
                                enabled: true,
                                wakeUpCheckEnabled: false,
                                soundName: viewModel.state.selectedSoundName ?? "Orkney",
                                soundVolume: viewModel.state.selectedVolume,
                                vibrateEnabled: true,
                                gentleWakeUpSeconds: 30,
                                timeReminderEnabled: false,
                                weatherReminderEnabled: false,
                                labelReminderEnabled: false,
                                extraLoudEnabled: false,
                                snoozeMinutes: 5,
                                snoozeCount: 3,
                                wallpaperId: viewModel.state.selectedWallpaper?.id ?? "default",
                                createdAt: Date()
                            )
                            if alarmStore.alarms.isEmpty {
                                alarmStore.add(newAlarm)
                            } else {
                                alarmStore.update(newAlarm)
                            }
                            appPreferences.hasAnyAlarm = !alarmStore.alarms.isEmpty
                            viewModel.completeOnboarding()
                            path.removeAll()
                            path.append(.home)
                        }
                    })
                case .intro:
                    EmptyView()
                case .home:
                    MainTabContainerView(preferences: appPreferences, alarmStore: alarmStore)
                }
            }
        }
        .tint(Colors.accentRed)
    }
}
