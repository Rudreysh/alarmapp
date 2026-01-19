import SwiftUI

struct AdvancedSettingsView: View {
    @ObservedObject var store = SettingsStore.shared
    @State private var showTimeLimitPicker = false
    
    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()
            
            VStack(spacing: 24) {
                SettingsCard {
                    SettingsActionRow(
                        title: "Mission time limit",
                        subtitle: "Complete mission within time limit",
                        trailingText: store.missionTimeLimitLabel,
                        isLast: true
                    ) {
                        showTimeLimitPicker = true
                    }
                }
                
                Spacer()
            }
            .padding(.top, 20)
        }
        .navigationTitle("Advanced alarm settings")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showTimeLimitPicker) {
            MissionTimeLimitSheet()
        }
    }
}

struct MissionTimeLimitSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var store = SettingsStore.shared
    
    let options = [50, 40, 30, 20, 15, 10]
    
    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()
            
            VStack(spacing: 0) {
                Text("Mission time limit")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.vertical, 20)
                
                VStack(spacing: 0) {
                    ForEach(options, id: \.self) { seconds in
                        SettingsRadioRow(
                            title: seconds == 20 ? "20 sec (Default)" : "\(seconds) sec",
                            isSelected: store.missionTimeLimitSeconds == seconds,
                            isLast: seconds == options.last
                        ) {
                            store.missionTimeLimitSeconds = seconds
                            dismiss()
                        }
                    }
                }
                .background(Colors.cardSurface)
                .cornerRadius(16)
                .padding(.horizontal, 20)
                
                Spacer()
            }
        }
        .presentationDetents([.medium])
    }
}

struct ThemeSettingsView: View {
    @ObservedObject var store = SettingsStore.shared
    
    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()
            
            VStack(spacing: 24) {
                SettingsCard {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Theme")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                            .padding([.top, .leading], 16)
                        
                        VStack(spacing: 0) {
                            ForEach(ThemeMode.allCases, id: \.self) { mode in
                                SettingsRadioRow(
                                    title: mode.rawValue,
                                    isSelected: store.themeMode == mode,
                                    isLast: mode == ThemeMode.allCases.last
                                ) {
                                    store.themeMode = mode
                                }
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .padding(.top, 20)
        }
        .navigationTitle("Theme")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SoundOutputView: View {
    @ObservedObject var store = SettingsStore.shared
    
    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()
            
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    SettingsCard {
                        SettingsRadioRow(
                            title: SoundOutputMode.currentDevice.rawValue,
                            isSelected: store.soundOutputMode == .currentDevice,
                            isLast: true
                        ) {
                            store.soundOutputMode = .currentDevice
                            AudioRouteManager.shared.apply(mode: .currentDevice)
                        }
                    }
                    
                    SettingsCard {
                        VStack(alignment: .leading, spacing: 0) {
                            SettingsRadioRow(
                                title: SoundOutputMode.externalPreferred.rawValue,
                                isSelected: store.soundOutputMode == .externalPreferred,
                                isLast: true
                            ) {
                                store.soundOutputMode = .externalPreferred
                                AudioRouteManager.shared.apply(mode: .externalPreferred)
                            }
                            
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Alarm sounds from a Bluetooth speaker or earphones")
                                    .font(.system(size: 14))
                                    .foregroundColor(Colors.textSecondary)
                                
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "info.circle")
                                        .font(.system(size: 14))
                                    Text("If no device is connected, alarm will sound through the built-in speaker")
                                        .font(.system(size: 14))
                                }
                                .foregroundColor(Colors.textSecondary)
                            }
                            .padding([.horizontal, .bottom], 16)
                        }
                    }
                }
                
                Spacer()
            }
            .padding(.top, 20)
        }
        .navigationTitle("Sound output")
        .navigationBarTitleDisplayMode(.inline)
    }
}
