import SwiftUI

struct FocusSettingsView: View {
    @ObservedObject var preferences: AppPreferences
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Colors.bgPrimary.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(Colors.textPrimary)
                        }
                        Spacer()
                        Text("Focus Settings")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Colors.textPrimary)
                        Spacer()
                        Spacer().frame(width: 44)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 20)
                    
                    ScrollView {
                        VStack(spacing: 24) {
                            FocusSettingsSection(title: "Settings") {
                                NavigationLink(destination: PomoSettingsView(preferences: preferences)) {
                                    FocusSettingsNavigationRow(title: "Pomodoro Settings", value: "")
                                }
                                Divider().background(Colors.cardStroke)
                                NavigationLink(destination: StopwatchSettingsView(preferences: preferences)) {
                                    FocusSettingsNavigationRow(title: "Stopwatch Settings", value: "")
                                }
                            }
                            
                            FocusSettingsSection(title: "General") {
                                FocusSettingsToggleRow(title: "Flip Start", isOn: .constant(false))
                                Divider().background(Colors.cardStroke)
                                FocusSettingsToggleRow(title: "Strict Mode", isOn: .constant(false))
                                Divider().background(Colors.cardStroke)
                                FocusSettingsToggleRow(title: "OLED Anti Burn-in", isOn: .constant(true))
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }
}
