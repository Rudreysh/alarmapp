import SwiftUI

struct OnboardingFlowView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @ObservedObject var appPreferences: AppPreferences
    @ObservedObject var alarmStore: AlarmStore
    @EnvironmentObject private var navStore: NavigationStore
    @State private var welcomeMascotFrame: CGRect = .zero
    @State private var flyingMascotFrame: CGRect = .zero
    @State private var isMascotFlightActive = false
    @State private var isWaitingForQuestionMascotTarget = false

    var body: some View {
        GeometryReader { _ in
            ZStack {
                NavigationStack(path: $viewModel.navigationPath) {
            OnboardingIntroView(onNext: {
                withAnimation(.easeInOut) {
                    viewModel.startSetupFlowFromIntroCTA()
                }
            }, onSkip: {
                // Skip onboarding entirely and go straight to main alarm UI.
                withAnimation(.easeInOut) {
                    appPreferences.devAlwaysShowOnboarding = false
                    appPreferences.forceShowOnboardingNextLaunch = false
                    appPreferences.onboardingCompleted = true
                    viewModel.completeOnboarding()
                }
            })
            .navigationDestination(for: OnboardingStep.self) { step in
                switch step {
                case .namePrompt:
                    OnboardingNameView(viewModel: viewModel) {
                        withAnimation(.easeInOut) {
                            viewModel.setStep(.nameWelcome)
                            viewModel.navigationPath.append(.nameWelcome)
                        }
                    }
                case .nameWelcome:
                    OnboardingNameWelcomeView(
                        viewModel: viewModel,
                        isMascotHidden: isMascotFlightActive
                    ) {
                        beginNameWelcomeMascotFlight()
                    }
                case .chronotypeQuestion:
                    OnboardingChronotypeQuestionView {
                        withAnimation(.easeInOut) {
                            viewModel.setStep(.struggleQuestion)
                            viewModel.navigationPath.append(.struggleQuestion)
                        }
                    }
                case .struggleQuestion:
                    OnboardingStruggleQuestionView {
                        withAnimation(.easeInOut) {
                            viewModel.setStep(.wakeLateImpactQuestion)
                            viewModel.navigationPath.append(.wakeLateImpactQuestion)
                        }
                    }
                case .wakeLateImpactQuestion:
                    OnboardingWakeLateImpactQuestionView {
                        withAnimation(.easeInOut) {
                            viewModel.setStep(.wakeFeelQuestion)
                            viewModel.navigationPath.append(.wakeFeelQuestion)
                        }
                    }
                case .wakeFeelQuestion:
                    OnboardingWakeFeelQuestionView {
                        withAnimation(.easeInOut) {
                            viewModel.setStep(.morningHardestQuestion)
                            viewModel.navigationPath.append(.morningHardestQuestion)
                        }
                    }
                case .morningHardestQuestion:
                    OnboardingMorningHardestQuestionView {
                        withAnimation(.easeInOut) {
                            viewModel.setStep(.halfAsleepQuestion)
                            viewModel.navigationPath.append(.halfAsleepQuestion)
                        }
                    }
                case .halfAsleepQuestion:
                    OnboardingHalfAsleepQuestionView {
                        withAnimation(.easeInOut) {
                            viewModel.setStep(.snoozeCountQuestion)
                            viewModel.navigationPath.append(.snoozeCountQuestion)
                        }
                    }
                case .snoozeCountQuestion:
                    OnboardingSnoozeCountQuestionView(viewModel: viewModel) {
                        withAnimation(.easeInOut) {
                            viewModel.setStep(.snoozeAgeQuestion)
                            viewModel.navigationPath.append(.snoozeAgeQuestion)
                        }
                    }
                case .snoozeAgeQuestion:
                    OnboardingSnoozeAgeQuestionView(viewModel: viewModel) {
                        withAnimation(.easeInOut) {
                            viewModel.setStep(.snoozeDailyDrain)
                            viewModel.navigationPath.append(.snoozeDailyDrain)
                        }
                    }
                case .snoozeDailyDrain:
                    OnboardingSnoozeDailyDrainView(viewModel: viewModel) {
                        withAnimation(.easeInOut) {
                            viewModel.setStep(.snoozeYearGrid)
                            viewModel.navigationPath.append(.snoozeYearGrid)
                        }
                    }
                case .snoozeYearGrid:
                    OnboardingSnoozeYearGridView(viewModel: viewModel) {
                        withAnimation(.easeInOut) {
                            viewModel.setStep(.snoozeLifetimeTotal)
                            viewModel.navigationPath.append(.snoozeLifetimeTotal)
                        }
                    }
                case .snoozeLifetimeTotal:
                    OnboardingSnoozeLifetimeTotalView(viewModel: viewModel) {
                        withAnimation(.easeInOut) {
                            viewModel.setStep(.snoozePayoff)
                            viewModel.navigationPath.append(.snoozePayoff)
                        }
                    }
                case .snoozePayoff:
                    OnboardingSnoozePayoffView(viewModel: viewModel) {
                        withAnimation(.easeInOut) {
                            viewModel.setStep(.setTime)
                            viewModel.navigationPath.append(.setTime)
                        }
                    }
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
                            viewModel.setStep(.quoteCategories)
                            viewModel.navigationPath.append(.quoteCategories)
                        }
                    }
                case .quoteCategories:
                    OnboardingQuoteCategorySelectionView(viewModel: viewModel) {
                        withAnimation(.easeInOut) {
                            viewModel.setStep(.wallpaperPreview)
                            viewModel.navigationPath.append(.wallpaperPreview)
                        }
                    }
                case .wallpaperPreview:
                    OnboardingWallpaperPreviewView(viewModel: viewModel) {
                        withAnimation(.easeInOut) {
                            if !viewModel.navigationPath.isEmpty {
                                viewModel.navigationPath.removeLast()
                            }
                            viewModel.setStep(.quoteCategories)
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
                            viewModel.setStep(.cameraAccess)
                            viewModel.navigationPath.append(.cameraAccess)
                        }
                    }
                case .motionAccess:
                    Color.clear
                        .onAppear {
                            withAnimation(.easeInOut) {
                                if !viewModel.navigationPath.isEmpty {
                                    viewModel.navigationPath.removeLast()
                                }
                                viewModel.setStep(.cameraAccess)
                                viewModel.navigationPath.append(.cameraAccess)
                            }
                        }
                case .cameraAccess:
                    OnboardingCameraAccessView(viewModel: viewModel) {
                        withAnimation(.easeInOut) {
                            viewModel.setStep(.soundSelection)
                            viewModel.navigationPath.append(.soundSelection)
                        }
                    }
                case .liveActivities:
                    Color.clear
                        .onAppear {
                            withAnimation(.easeInOut) {
                                if !viewModel.navigationPath.isEmpty {
                                    viewModel.navigationPath.removeLast()
                                }
                                viewModel.setStep(.healthAccess)
                                viewModel.navigationPath.append(.healthAccess)
                            }
                        }
                case .healthAccess:
                    Color.clear
                        .onAppear {
                            withAnimation(.easeInOut) {
                                if !viewModel.navigationPath.isEmpty {
                                    viewModel.navigationPath.removeLast()
                                }
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
                .environment(\.onboardingQuestionMascotHidden, isMascotFlightActive)
                .onPreferenceChange(OnboardingWelcomeMascotFramePreferenceKey.self) { frame in
                    guard !frame.isEmpty else { return }
                    welcomeMascotFrame = frame
                }
                .onPreferenceChange(OnboardingQuestionMascotFramePreferenceKey.self) { frame in
                    guard !frame.isEmpty else { return }
                    continueNameWelcomeMascotFlight(to: frame)
                }

                if isMascotFlightActive, !flyingMascotFrame.isEmpty {
                    AnimatedGIFView(resourceName: OnboardingMascotAsset.resourceName, resourceExtension: "gif")
                        .frame(width: flyingMascotFrame.width, height: flyingMascotFrame.height)
                        .position(x: flyingMascotFrame.midX, y: flyingMascotFrame.midY)
                        .allowsHitTesting(false)
                        .zIndex(100)
                }
            }
            .coordinateSpace(name: OnboardingMascotFlightCoordinateSpace.name)
        }
        .tint(Colors.accentTeal)
    }

    private func beginNameWelcomeMascotFlight() {
        let startFrame = welcomeMascotFrame.isEmpty
            ? CGRect(x: 80, y: 360, width: 252, height: 252)
            : welcomeMascotFrame

        flyingMascotFrame = startFrame
        isMascotFlightActive = true
        isWaitingForQuestionMascotTarget = true

        withAnimation(.easeInOut(duration: 0.25)) {
            viewModel.setStep(.chronotypeQuestion)
            viewModel.navigationPath.append(.chronotypeQuestion)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            if isWaitingForQuestionMascotTarget {
                isMascotFlightActive = false
                isWaitingForQuestionMascotTarget = false
            }
        }
    }

    private func continueNameWelcomeMascotFlight(to targetFrame: CGRect) {
        guard isMascotFlightActive, isWaitingForQuestionMascotTarget else { return }
        isWaitingForQuestionMascotTarget = false

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.easeInOut(duration: 0.68)) {
                flyingMascotFrame = targetFrame
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.82) {
            isMascotFlightActive = false
        }
    }
}
