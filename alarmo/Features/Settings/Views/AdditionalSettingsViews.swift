import SwiftUI

struct AdvancedSettingsView: View {
    @ObservedObject var store = SettingsStore.shared
    @State private var showTimeLimitPicker = false
    
    var body: some View {
        ZStack {
            SettingsGlassBackground()
            
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
            SettingsGlassBackground()
            
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
            SettingsGlassBackground()

            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    themeOptionButton(
                        title: "Light",
                        icon: "sun.max.fill",
                        iconColor: Color(red: 0.98, green: 0.84, blue: 0.30),
                        isSelected: store.alarmThemeStyle == .tiimo
                    ) {
                        store.alarmThemeStyle = .tiimo
                    }

                    themeOptionButton(
                        title: "Dark",
                        icon: "moon.stars.fill",
                        iconColor: Color(red: 0.4, green: 0.4, blue: 0.5),
                        isSelected: store.alarmThemeStyle == .default
                    ) {
                        store.alarmThemeStyle = .default
                    }
                }

                Spacer()
            }
            .padding(.top, 20)
            .padding(.horizontal, 20)
        }
        .navigationTitle("Themes")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func themeOptionButton(title: String, icon: String, iconColor: Color, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(iconColor)
                    .frame(width: 44, height: 44)
                    .background(iconColor.opacity(0.2))
                    .cornerRadius(12)

                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Colors.textPrimary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Colors.accentTeal)
                }
            }
            .padding(16)
            .background(Colors.cardSurface)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Colors.accentTeal.opacity(0.5) : Colors.cardStroke, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct SoundOutputView: View {
    @ObservedObject var store = SettingsStore.shared
    
    var body: some View {
        ZStack {
            SettingsGlassBackground()
            
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
