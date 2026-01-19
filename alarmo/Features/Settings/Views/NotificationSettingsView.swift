import SwiftUI

struct NotificationSettingsView: View {
    @ObservedObject var store = SettingsStore.shared
    @StateObject var notificationManager = NotificationManager.shared
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Permission Banner
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Notification permission")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                            Spacer()
                            Button(action: {
                                if notificationManager.authorizationStatus == .denied {
                                    if let url = URL(string: UIApplication.openSettingsURLString) {
                                        UIApplication.shared.open(url)
                                    }
                                } else {
                                    notificationManager.requestPermission { _ in }
                                }
                            }) {
                                Text(notificationManager.authorizationStatus == .authorized ? "Allowed" : "Allow")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.cyan)
                            }
                        }
                        
                        Text("Allow permission to ensure alarms work properly")
                            .font(.system(size: 15))
                            .foregroundColor(Colors.textSecondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    // Service Notification Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Service notification")
                            .font(.system(size: 14))
                            .foregroundColor(Colors.textSecondary)
                            .padding(.horizontal, 20)
                        
                        SettingsCard {
                            SettingsCardToggleRow(
                                title: "Weather notification",
                                subtitle: "Highest 2°C, Lowest -4°C. It's freezing today. Stay warm.",
                                isOn: binding(for: \.weatherEnabled),
                                isLast: false
                            )
                            
                            SettingsCardToggleRow(
                                title: "Alarm reminder",
                                subtitle: "No alarm for tomorrow\nCheck if there's any schedule you forgot.",
                                isOn: binding(for: \.alarmReminderEnabled),
                                isLast: true
                            )
                        }
                    }
                    
                    // Promotion & Update Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Promotion & update")
                            .font(.system(size: 14))
                            .foregroundColor(Colors.textSecondary)
                            .padding(.horizontal, 20)
                        
                        SettingsCard {
                            SettingsCardToggleRow(
                                title: "Alarmy news",
                                subtitle: "Video alarm is here 🎉\nPick your favorite video in the alarm editor",
                                isOn: binding(for: \.newsEnabled),
                                isLast: false
                            )
                            
                            SettingsCardToggleRow(
                                title: "Alarmy event",
                                subtitle: "We'll let you know when new events open",
                                isOn: binding(for: \.eventEnabled),
                                isLast: true
                            )
                        }
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Notification setting")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func binding(for keyPath: WritableKeyPath<NotificationPrefs, Bool>) -> Binding<Bool> {
        Binding(
            get: { store.notificationPrefs[keyPath: keyPath] },
            set: { newValue in
                if newValue && notificationManager.authorizationStatus != .authorized {
                    notificationManager.requestPermission { granted in
                        if granted {
                            store.notificationPrefs[keyPath: keyPath] = true
                        }
                    }
                } else {
                    store.notificationPrefs[keyPath: keyPath] = newValue
                }
            }
        )
    }
}
