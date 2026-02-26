import SwiftUI

struct PomoSettingsView: View {
    @ObservedObject var preferences: AppPreferences
    @ObservedObject private var settingsStore = SettingsStore.shared
    @Environment(\.dismiss) var dismiss
    
    @StateObject private var subManager = SubscriptionManager.shared
    @State private var showUpsell = false
    
    @State private var showingPomoDuration = false
    @State private var showingShortBreak = false
    @State private var showingLongBreak = false
    @State private var showingPomosPerLongBreak = false
    @State private var showingCycle = false
    @State private var showingVibration = false
    @State private var showingPomoSound = false
    @State private var showingBreakSound = false
    @State private var showAccountabilityInfo = false
    
    private func proBinding<T>(_ binding: Binding<T>) -> Binding<T> {
        Binding(
            get: { binding.wrappedValue },
            set: { newValue in
                if subManager.isPro {
                    binding.wrappedValue = newValue
                } else {
                    showUpsell = true
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            }
        )
    }
    
    // Helper to request view or upsell
    private func reqPro(action: @escaping () -> Void) {
        if subManager.isPro {
            action()
        } else {
            showUpsell = true
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }
    
    var body: some View {
        ZStack {
            TimerGlassBackground()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Colors.textPrimary)
                    }
                    Spacer()
                    Text("Pomodoro Settings")
                        .font(.system(size: 28, weight: .black))
                        .foregroundColor(Colors.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.left")
                        .opacity(0)
                        .frame(width: 44)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 18)

                Text("Configure focus cycle, sounds and accountability")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Colors.textSecondary)
                    .padding(.bottom, 16)
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Section 1: Timer Option (PRO)
                        FocusSettingsSection(title: "Timer Option (PRO)") {
                            FocusSettingsRow(title: "Pomodoro Duration", value: "\(preferences.pomoDurationMinutes) minutes") {
                                reqPro { showingPomoDuration = true }
                            }
                            Divider().background(Colors.cardStroke)
                            FocusSettingsRow(title: "Short Break Duration", value: "\(preferences.shortBreakMinutes) minutes") {
                                reqPro { showingShortBreak = true }
                            }
                            Divider().background(Colors.cardStroke)
                            FocusSettingsRow(title: "Long Break Duration", value: "\(preferences.longBreakMinutes) minutes") {
                                reqPro { showingLongBreak = true }
                            }
                            Divider().background(Colors.cardStroke)
                            FocusSettingsRow(title: "Pomodoros per long break", value: "\(preferences.pomosPerLongBreak) Pomos") {
                                reqPro { showingPomosPerLongBreak = true }
                            }
                        }
                        
                        // Section 2: Auto Mode
                        FocusSettingsSection(title: "Auto Mode") {
                            FocusSettingsToggleRow(title: "Auto Start of Next Pomodoro", isOn: $preferences.autoStartNextPomo)
                            Divider().background(Colors.cardStroke)
                            FocusSettingsToggleRow(title: "Auto Start of Break", isOn: $preferences.autoStartBreak)
                            Divider().background(Colors.cardStroke)
                            FocusSettingsRow(title: "Auto-Pomodoro Cycle", value: "\(preferences.autoPomoCycle)") {
                                showingCycle = true
                            }
                        }
                        
                        // Section 3: Ringtone
                        FocusSettingsSection(title: "Ringtone") {
                            FocusSettingsRow(title: "Pomodoro ending", value: preferences.pomoEndingSoundName) {
                                showingPomoSound = true
                            }
                            Divider().background(Colors.cardStroke)
                            FocusSettingsRow(title: "Break-ending", value: preferences.breakEndingSoundName) {
                                showingBreakSound = true
                            }
                            Divider().background(Colors.cardStroke)
                            FocusSettingsRow(title: "Vibration Duration", value: "\(preferences.vibrationDurationSeconds)s") {
                                reqPro { showingVibration = true }
                            }
                        }

                        // Section 4: Accountability Shield (PRO)
                        FocusSettingsSection(title: "Accountability Shield (PRO)") {
                            FocusSettingsToggleRow(
                                title: "Enable for Pomodoro focus",
                                isOn: proBinding($settingsStore.accountabilityEnabled)
                            )
                            Divider().background(Colors.cardStroke)
                            FocusSettingsToggleRow(
                                title: "Lock phone while focus runs",
                                isOn: proBinding($settingsStore.blockAppsEnabled)
                            )
                            if settingsStore.blockAppsEnabled {
                                Divider().background(Colors.cardStroke)
                                BlockedAppsSelectionView()
                                    .padding(12)
                            }
                            Divider().background(Colors.cardStroke)
                            FocusSettingsToggleRow(
                                title: "Use penalty credits",
                                isOn: proBinding($settingsStore.penaltyEnabled)
                            )
                            if settingsStore.penaltyEnabled {
                                Divider().background(Colors.cardStroke)
                                HStack {
                                    Text("Penalty Amount")
                                        .font(.system(size: 16))
                                        .foregroundColor(Colors.textPrimary)
                                    Spacer()
                                    Stepper(
                                        "€\(settingsStore.penaltyAmountEuro)",
                                        value: $settingsStore.penaltyAmountEuro,
                                        in: 1...10
                                    )
                                    .labelsHidden()
                                    Text("€\(settingsStore.penaltyAmountEuro)")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(TimerPalette.accent)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            }
                            Divider().background(Colors.cardStroke)
                            Button {
                                showAccountabilityInfo = true
                            } label: {
                                HStack {
                                    Text("How this works")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(TimerPalette.accent)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(Colors.textSecondary)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingPomoDuration) {
            FocusWheelPickerView(title: "Pomodoro Duration", selection: $preferences.pomoDurationMinutes, range: 1...60, suffix: "minutes") {
                showingPomoDuration = false
            }
        }
        .sheet(isPresented: $showingShortBreak) {
            FocusWheelPickerView(title: "Short Break Duration", selection: $preferences.shortBreakMinutes, range: 1...60, suffix: "minutes") {
                showingShortBreak = false
            }
        }
        .sheet(isPresented: $showingLongBreak) {
            FocusWheelPickerView(title: "Long Break Duration", selection: $preferences.longBreakMinutes, range: 1...60, suffix: "minutes") {
                showingLongBreak = false
            }
        }
        .sheet(isPresented: $showingPomosPerLongBreak) {
            FocusWheelPickerView(title: "Pomodoros per long break", selection: $preferences.pomosPerLongBreak, range: 1...10, suffix: "Pomodoros") {
                showingPomosPerLongBreak = false
            }
        }
        .sheet(isPresented: $showingCycle) {
            FocusWheelPickerView(title: "Auto-Pomodoro Cycle", selection: $preferences.autoPomoCycle, range: 1...12, suffix: "") {
                showingCycle = false
            }
        }
        .sheet(isPresented: $showingVibration) {
            VibrationPickerView(selection: $preferences.vibrationDurationSeconds) {
                showingVibration = false
            }
        }
        .sheet(isPresented: $showingPomoSound) {
            SoundPickerView(selectedSound: $preferences.pomoEndingSoundName)
        }
        .sheet(isPresented: $showingBreakSound) {
            SoundPickerView(selectedSound: $preferences.breakEndingSoundName)
        }
        .sheet(isPresented: $showAccountabilityInfo) {
            AccountabilityInfoView()
        }
        .fullScreenCover(isPresented: $showUpsell) {
            ProUpsellFlowView()
        }
    }
}


struct VibrationPickerView: View {
    @Binding var selection: Int
    let onClose: () -> Void
    private let options = [0, 5, 10, 15, 20, 30, 60]
    
    var body: some View {
        ZStack {
            TimerGlassBackground()
            
            VStack(spacing: 0) {
                HStack {
                    Button(action: onClose) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Colors.textPrimary)
                    }
                    Spacer()
                    Text("Vibration Duration")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Colors.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.left")
                        .opacity(0)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                Spacer()
                
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.white.opacity(0.12))
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color.white.opacity(0.18), lineWidth: 1)
                        )
                        .frame(height: 250)
                        .padding(.horizontal, 20)
                    
                    Picker("", selection: $selection) {
                        ForEach(options, id: \.self) { value in
                            Text("\(value)s").tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                }
                
                Spacer()
                Spacer()
            }
        }
    }
}
