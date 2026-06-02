import SwiftUI

struct AlarmSettingsView: View {
    @ObservedObject private var store = SettingsStore.shared
    @State private var showWallpaperQuotes = false
    @State private var showClockStylePicker = false
    @State private var showThemePicker = false
    @State private var showTimeLimitPicker = false
    @State private var permissionMessage: String?

    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                Text("Alarm")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundColor(Colors.textPrimary)
                    .padding(.horizontal, Spacing.l)

                VStack(spacing: 0) {
                    Toggle(isOn: $store.alarmRingInSilentModeEnabled) {
                        HStack(spacing: Spacing.m) {
                            Image(systemName: "bell.badge.fill")
                                .font(.system(size: 18))
                                .foregroundColor(Colors.textSecondary)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 3) {
                                Text("Ring in Silent Mode")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Colors.textPrimary)
                                Text(store.alarmRingInSilentModeEnabled ? "Enabled for new alarms" : "Disabled for new alarms")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Colors.textSecondary)
                            }
                        }
                    }
                    .toggleStyle(.switch)
                    .padding(.vertical, 16)
                    .padding(.horizontal, Spacing.m)
                    .onChange(of: store.alarmRingInSilentModeEnabled) { _, isEnabled in
                        guard isEnabled else { return }
                        requestSilentModePermission()
                    }

                    Divider().padding(.leading, 56).opacity(0.35)

                    Button {
                        showWallpaperQuotes = true
                    } label: {
                        HStack(spacing: Spacing.m) {
                            Image(systemName: "rectangle.stack.fill")
                                .font(.system(size: 18))
                                .foregroundColor(Colors.textSecondary)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 3) {
                                Text("Wallpaper & Quotes")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Colors.textPrimary)
                                Text(store.alarmVisualOutputSettings.summaryText())
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Colors.textSecondary)
                                    .lineLimit(2)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Colors.textTertiary)
                        }
                        .padding(.vertical, 16)
                        .padding(.horizontal, Spacing.m)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Divider().padding(.leading, 56).opacity(0.35)

                    Button {
                        showClockStylePicker = true
                    } label: {
                        row(
                            icon: "dial.medium.fill",
                            title: "Alarm Clock Style",
                            trailing: store.alarmClockStyle.title
                        )
                    }
                    .buttonStyle(.plain)

                    Divider().padding(.leading, 56).opacity(0.35)

                    Button {
                        showThemePicker = true
                    } label: {
                        row(
                            icon: "paintpalette.fill",
                            title: "Themes",
                            trailing: store.alarmThemeStyle.title
                        )
                    }
                    .buttonStyle(.plain)

                    Divider().padding(.leading, 56).opacity(0.35)

                    NavigationLink {
                        SoundOutputView()
                    } label: {
                        row(
                            icon: "hifispeaker.fill",
                            title: "Sound Output Matrix",
                            trailing: store.soundOutputMode.rawValue
                        )
                    }
                    .buttonStyle(.plain)

                    Divider().padding(.leading, 56).opacity(0.35)

                    Button(action: { showTimeLimitPicker = true }) {
                        row(
                            icon: "hourglass",
                            title: "Mission time limit",
                            trailing: store.missionTimeLimitLabel
                        )
                    }
                    .buttonStyle(.plain)
                }
                .background(Colors.cardSurface)
                .cornerRadius(24)
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(Colors.cardStroke, lineWidth: 1))
                .appShadow(Shadows.card)
                .padding(.horizontal, Spacing.l)

                Spacer()
            }
            .padding(.top, Spacing.s)
        }
        .navigationBarTitleDisplayMode(.inline)
        .alert("Alarm Permission", isPresented: Binding(
            get: { permissionMessage != nil },
            set: { isPresented in
                if !isPresented { permissionMessage = nil }
            }
        )) {
            Button("OK", role: .cancel) { permissionMessage = nil }
        } message: {
            Text(permissionMessage ?? "")
        }
        .sheet(isPresented: $showWallpaperQuotes) {
            VisualOutputSettingsView(
                wallpaperId: $store.alarmWallpaperId,
                dailyMotivationEnabled: $store.alarmDailyMotivationEnabled,
                settings: Binding(
                    get: { store.alarmVisualOutputSettings },
                    set: { store.alarmVisualOutputSettings = $0 }
                )
            )
        }
        .confirmationDialog(
            "Alarm Clock Style",
            isPresented: $showClockStylePicker,
            titleVisibility: .visible
        ) {
            ForEach(AlarmClockStyle.allCases) { style in
                Button(style.title) {
                    store.alarmClockStyle = style
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose which dial appears while creating or editing alarms.")
        }
        .confirmationDialog(
            "Themes",
            isPresented: $showThemePicker,
            titleVisibility: .visible
        ) {
            ForEach(AlarmThemeStyle.allCases) { theme in
                Button {
                    store.alarmThemeStyle = theme
                } label: {
                    Label(theme.title, systemImage: theme.iconSystemName)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose the alarm appearance theme.")
        }
        .sheet(isPresented: $showTimeLimitPicker) {
            MissionTimeLimitSheet()
        }
    }

    private func requestSilentModePermission() {
        NotificationManager.shared.requestPermission { _ in
            Task {
                async let deliveryStatusTask = NotificationManager.shared.currentAlarmDeliveryStatus()
                async let diagnosticsTask = AlarmManagerFacade.shared.diagnosticsSnapshot()
                let status = await deliveryStatusTask
                let diagnostics = await diagnosticsTask
                await MainActor.run {
                    if !status.notificationsAuthorized {
                        permissionMessage = "Enable notifications for Awayk in iPhone Settings to ring alarms."
                        return
                    }
                    if !status.alertEnabled || !status.lockScreenEnabled {
                        permissionMessage = "Enable Alerts and Lock Screen notifications for Awayk so alarms appear while your phone is locked."
                        return
                    }
                    if status.scheduledDeliveryEnabled && !status.timeSensitiveEnabled {
                        permissionMessage = "Scheduled Summary is on and Time Sensitive is off. Alarm notifications can be delayed until unlock."
                        return
                    }
                    if !diagnostics.alarmKitSupported {
                        permissionMessage = "AlarmKit is unavailable on this iPhone/iOS (\(diagnostics.iOSVersion)). Awayk uses notification fallback here, and silent-mode override may be limited."
                        return
                    }
                    if EntitlementInspector.hasCriticalAlertsAccess {
                        permissionMessage = status.criticalEnabled
                            ? "Critical Alerts are enabled. Alarms can ring over silent mode."
                            : "Enable Critical Alerts for Awayk in iPhone Settings to ring over silent mode."
                    } else {
                        permissionMessage = "Notifications are enabled. On older iOS without AlarmKit/Critical Alerts, alarms may not play sound in Silent mode."
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func row(icon: String, title: String, trailing: String? = nil) -> some View {
        HStack(spacing: Spacing.m) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(Colors.textSecondary)
                .frame(width: 24)

            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Colors.textPrimary)

            Spacer()

            if let trailing {
                Text(trailing)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Colors.accentTeal)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Colors.textTertiary)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, Spacing.m)
        .contentShape(Rectangle())
    }
}
