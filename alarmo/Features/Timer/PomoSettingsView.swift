import SwiftUI

struct PomoSettingsView: View {
    @ObservedObject var preferences: AppPreferences
    @Environment(\.dismiss) var dismiss
    
    @State private var showingPomoDuration = false
    @State private var showingShortBreak = false
    @State private var showingLongBreak = false
    @State private var showingPomosPerLongBreak = false
    @State private var showingCycle = false
    @State private var showingVibration = false
    @State private var showingPomoSound = false
    @State private var showingBreakSound = false
    
    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Colors.textPrimary)
                    }
                    Spacer()
                    Text("Pomo Settings")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Colors.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.left")
                        .opacity(0)
                        .frame(width: 44)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 24)
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Section 1: Timer Option
                        FocusSettingsSection(title: "Timer Option") {
                            FocusSettingsRow(title: "Pomo Duration", value: "\(preferences.pomoDurationMinutes) minutes") {
                                showingPomoDuration = true
                            }
                            Divider().background(Colors.cardStroke)
                            FocusSettingsRow(title: "Short Break Duration", value: "\(preferences.shortBreakMinutes) minutes") {
                                showingShortBreak = true
                            }
                            Divider().background(Colors.cardStroke)
                            FocusSettingsRow(title: "Long Break Duration", value: "\(preferences.longBreakMinutes) minutes") {
                                showingLongBreak = true
                            }
                            Divider().background(Colors.cardStroke)
                            FocusSettingsRow(title: "Pomos per long break", value: "\(preferences.pomosPerLongBreak) Pomos") {
                                showingPomosPerLongBreak = true
                            }
                        }
                        
                        // Section 2: Auto Mode
                        FocusSettingsSection(title: "Auto Mode") {
                            FocusSettingsToggleRow(title: "Auto Start of Next Pomo", isOn: $preferences.autoStartNextPomo)
                            Divider().background(Colors.cardStroke)
                            FocusSettingsToggleRow(title: "Auto Start of Break", isOn: $preferences.autoStartBreak)
                            Divider().background(Colors.cardStroke)
                            FocusSettingsRow(title: "Auto-Pomo Cycle", value: "\(preferences.autoPomoCycle)") {
                                showingCycle = true
                            }
                        }
                        
                        // Section 3: Ringtone
                        FocusSettingsSection(title: "Ringtone") {
                            FocusSettingsRow(title: "Pomo-ending", value: preferences.pomoEndingSoundName) {
                                showingPomoSound = true
                            }
                            Divider().background(Colors.cardStroke)
                            FocusSettingsRow(title: "Break-ending", value: preferences.breakEndingSoundName) {
                                showingBreakSound = true
                            }
                            Divider().background(Colors.cardStroke)
                            FocusSettingsRow(title: "Vibration Duration", value: "\(preferences.vibrationDurationSeconds)s") {
                                showingVibration = true
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
            FocusWheelPickerView(title: "Pomo Duration", selection: $preferences.pomoDurationMinutes, range: 1...60, suffix: "minutes") {
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
            FocusWheelPickerView(title: "Pomos per long break", selection: $preferences.pomosPerLongBreak, range: 1...10, suffix: "Pomos") {
                showingPomosPerLongBreak = false
            }
        }
        .sheet(isPresented: $showingCycle) {
            FocusWheelPickerView(title: "Auto-Pomo Cycle", selection: $preferences.autoPomoCycle, range: 1...12, suffix: "") {
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
    }
}


struct VibrationPickerView: View {
    @Binding var selection: Int
    let onClose: () -> Void
    private let options = [0, 5, 10, 15, 20, 30, 60]
    
    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()
            
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
                        .fill(Colors.cardSurface)
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
