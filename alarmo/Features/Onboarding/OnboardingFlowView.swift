import SwiftUI

struct OnboardingFlowView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @ObservedObject var appPreferences: AppPreferences
    @ObservedObject var alarmStore: AlarmStore
    @EnvironmentObject private var navStore: NavigationStore

    var body: some View {
                NavigationStack(path: $viewModel.navigationPath) {
            OnboardingIntroView(onNext: {
                withAnimation(.easeInOut) {
                    viewModel.startSetupFlowFromIntroCTA()
                }
            }, onSkip: {
                // Skip the tutorial slides and go straight to the setup steps
                withAnimation(.easeInOut) {
                    viewModel.startSetupFlowFromIntroCTA()
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
                            viewModel.navigationPath.append(.wallpaper)
                        }
                    }

                case .wallpaper:
                    OnboardingWallpaperSelectionView(viewModel: viewModel) {
                        withAnimation(.easeInOut) {
                            viewModel.nextStep()
                            viewModel.navigationPath.append(.wallpaperPreview)
                        }
                    }
                case .wallpaperPreview:
                    OnboardingWallpaperPreviewView(viewModel: viewModel) {
                        withAnimation(.easeInOut) {
                            if !viewModel.navigationPath.isEmpty {
                                viewModel.navigationPath.removeLast()
                            }
                            viewModel.setStep(.wallpaper)
                        }
                    } onSelect: {
                        withAnimation(.easeInOut) {
                            viewModel.setStep(.notifications)
                            viewModel.navigationPath.append(.notifications)
                        }
                    }
                case .notifications:
                    OnboardingReportsInsightsView(viewModel: viewModel) {
                        withAnimation(.easeInOut) {
                            viewModel.setStep(.alarmPermission)
                            viewModel.navigationPath.append(.alarmPermission)
                        }
                    }
                case .alarmPermission:
                    OnboardingAlarmPermissionView(viewModel: viewModel) {
                        withAnimation(.easeInOut) {
                            viewModel.setStep(.screenTimeAccess)
                            viewModel.navigationPath.append(.screenTimeAccess)
                        }
                    }
                case .screenTimeAccess:
                    OnboardingScreenTimeAccessView(viewModel: viewModel) {
                        withAnimation(.easeInOut) {
                            viewModel.setStep(.motionAccess)
                            viewModel.navigationPath.append(.motionAccess)
                        }
                    }
                case .motionAccess:
                    OnboardingMotionAccessView(viewModel: viewModel) {
                        withAnimation(.easeInOut) {
                            viewModel.setStep(.liveActivities)
                            viewModel.navigationPath.append(.liveActivities)
                        }
                    }
                case .liveActivities:
                    OnboardingLiveActivitiesView(viewModel: viewModel) {
                        withAnimation(.easeInOut) {
                            viewModel.setStep(.healthAccess)
                            viewModel.navigationPath.append(.healthAccess)
                        }
                    }
                case .healthAccess:
                    OnboardingHealthAccessView(viewModel: viewModel) {
                        withAnimation(.easeInOut) {
                            viewModel.setStep(.soundSelection)
                            viewModel.navigationPath.append(.soundSelection)
                        }
                    }
                case .soundSelection:
                    OnboardingSoundSelectionView(onboardingViewModel: viewModel) {
                        withAnimation(.easeInOut) {
                            viewModel.nextStep()
                            viewModel.navigationPath.append(.soundVolume)
                        }
                    }
                case .soundVolume:
                    OnboardingVolumeSettingsView(onboardingViewModel: viewModel) {
                        withAnimation(.easeInOut) {
                            viewModel.nextStep()
                            viewModel.navigationPath.append(.missionStub)
                        }
                    }
                case .missionStub:
                    OnboardingMissionView(onboardingViewModel: viewModel) {
                        withAnimation(.easeInOut) {
                            if !viewModel.navigationPath.isEmpty {
                                viewModel.navigationPath.removeLast()
                            }
                            viewModel.setStep(.soundVolume)
                        }
                    } onDone: {
                        withAnimation(.easeInOut) {
                            viewModel.navigationPath.append(.trackingExplainer)
                        }
                    }
                case .trackingExplainer:
                    TrackingExplainerView {
                        withAnimation(.easeInOut) {
                            viewModel.navigationPath.append(.paywall)
                        }
                    }
                case .paywall:
                    PaywallView(onClose: {
                        let _ = print("[OnboardingFlowView] Paywall onClose triggered")
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
