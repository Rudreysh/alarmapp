import SwiftUI

struct OnboardingFlowView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @ObservedObject var appPreferences: AppPreferences
    @ObservedObject var alarmStore: AlarmStore
    @EnvironmentObject private var navStore: NavigationStore
    @State private var path: [OnboardingStep] = []

    var body: some View {
        NavigationStack(path: $path) {
            OnboardingIntroView(onNext: {
                withAnimation(.easeInOut) {
                    viewModel.nextStep()
                    path.append(.setTime)
                }
            }, onSkip: {
                // Skip directly to main app
                withAnimation(.easeInOut) {
                    appPreferences.devAlwaysShowOnboarding = false
                    appPreferences.onboardingCompleted = true
                    appPreferences.onboardingAlarmEnabled = true
                    
                    // Create a default alarm if none exists, using current defaults
                    if alarmStore.alarms.isEmpty {
                        let newAlarm = Alarm(
                            id: UUID(),
                            name: "Morning Alarm",
                            emoji: "🌞",
                            hour: 8,
                            minute: 0,
                            second: 0,
                            isDaily: true,
                            repeatMask: RepeatMask.monToSat, // Added
                            enabled: true,
                            wakeUpCheckEnabled: false, // Added
                            soundName: "Orkney",
                            soundVolume: 1.0,
                            vibrateEnabled: true, // Added
                            gentleWakeUpSeconds: 30, // Added
                            timeReminderEnabled: false, // Added
                            weatherReminderEnabled: false, // Added
                            labelReminderEnabled: false, // Added
                            extraLoudEnabled: false, // Added
                            snoozeMinutes: 5, // Added
                            snoozeCount: 3, // Added
                            wallpaperId: "default", // Added
                            dailyMotivationEnabled: viewModel.state.dailyMotivationEnabled,
                            createdAt: Date()
                        )
                        alarmStore.add(newAlarm)
                        appPreferences.hasAnyAlarm = true
                    }
                    viewModel.completeOnboarding()
                }
            })
            .navigationDestination(for: OnboardingStep.self) { step in
                switch step {
                case .setTime:
                    OnboardingSetTimeView(viewModel: viewModel) {
                        withAnimation(.easeInOut) {
                            appPreferences.onboardingAlarmHour = viewModel.selectedHour
                            appPreferences.onboardingAlarmMinute = viewModel.selectedMinute
                            appPreferences.onboardingAlarmSecond = viewModel.selectedSecond
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
                        let _ = print("[OnboardingFlowView] Paywall onClose triggered")
                        withAnimation(.easeInOut) {
                            appPreferences.devAlwaysShowOnboarding = false
                            appPreferences.onboardingCompleted = true
                            appPreferences.onboardingAlarmHour = viewModel.selectedHour
                            appPreferences.onboardingAlarmMinute = viewModel.selectedMinute
                            appPreferences.onboardingAlarmSecond = viewModel.selectedSecond
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
                                second: viewModel.selectedSecond,
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
                                dailyMotivationEnabled: viewModel.state.dailyMotivationEnabled,
                                createdAt: Date()
                            )
                            if alarmStore.alarms.isEmpty {
                                alarmStore.add(newAlarm)
                            } else {
                                alarmStore.update(newAlarm)
                            }
                            appPreferences.hasAnyAlarm = !alarmStore.alarms.isEmpty
                            viewModel.completeOnboarding()
                        }
                    }, onSuccess: {
                        let _ = print("[OnboardingFlowView] Paywall onSuccess triggered")
                        withAnimation(.easeInOut) {
                            appPreferences.devAlwaysShowOnboarding = false
                            appPreferences.onboardingCompleted = true
                            appPreferences.onboardingAlarmHour = viewModel.selectedHour
                            appPreferences.onboardingAlarmMinute = viewModel.selectedMinute
                            appPreferences.onboardingAlarmSecond = viewModel.selectedSecond
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
                                second: viewModel.selectedSecond,
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
                                dailyMotivationEnabled: viewModel.state.dailyMotivationEnabled,
                                createdAt: Date()
                            )
                            if alarmStore.alarms.isEmpty {
                                alarmStore.add(newAlarm)
                            } else {
                                alarmStore.update(newAlarm)
                            }
                            appPreferences.hasAnyAlarm = !alarmStore.alarms.isEmpty
                            viewModel.completeOnboarding()
                        }
                    })
                    .navigationBarBackButtonHidden(true)
                case .intro:
                    EmptyView()
                }
            }
        }
        .tint(Colors.accentTeal)
    }
}
