import SwiftUI

struct StopwatchSettingsView: View {
    @ObservedObject var preferences: AppPreferences
    @Environment(\.dismiss) var dismiss
    
    @State private var showingSound = false
    @State private var showingVibration = false
    
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
                    Text("Stopwatch Settings")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Colors.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.left")
                        .opacity(0)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 20)
                
                ScrollView {
                    VStack(spacing: 24) {
                        FocusSettingsSection(title: "Alert") {
                            FocusSettingsRow(title: "Stopwatch Alert Sound", value: preferences.stopwatchSoundName) {
                                showingSound = true
                            }
                            Divider().background(Colors.cardStroke)
                            FocusSettingsRow(title: "Vibration Duration", value: "\(preferences.stopwatchVibrationSeconds)s") {
                                showingVibration = true
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingSound) {
            SoundPickerView(selectedSound: $preferences.stopwatchSoundName)
        }
        .sheet(isPresented: $showingVibration) {
            VibrationPickerView(selection: $preferences.stopwatchVibrationSeconds) {
                showingVibration = false
            }
        }
    }
}
