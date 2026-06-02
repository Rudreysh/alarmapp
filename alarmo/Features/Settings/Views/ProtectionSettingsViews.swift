import SwiftUI

struct PreventAppUninstallView: View {
    @ObservedObject private var settings = SettingsStore.shared
    @StateObject private var authManager = ScreenTimeAuthorizationManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            SettingsGlassBackground()

            VStack(alignment: .leading, spacing: 20) {
                topBar(title: "Prevent uninstall")

                ProtectionToggleCard(
                    title: "Prevent uninstall",
                    subtitle: "You can't uninstall Alarmo while alarm/mission is active.",
                    isOn: Binding(
                        get: { settings.triggerUninstallTamperEnabled },
                        set: { isOn in
                            settings.triggerUninstallTamperEnabled = isOn
                            if isOn {
                                settings.accountabilityEnabled = true
                                settings.penaltyEnabled = true
                            }
                        }
                    )
                )

                if !authManager.isAuthorized {
                    SettingsCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Button {
                                Task { await authManager.requestAuthorization() }
                            } label: {
                                Text("Enable Screen Time Access")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 13)
                                    .background(SettingsPalette.accent)
                                    .clipShape(Capsule())
                            }

                            if let status = authManager.statusMessage, !status.isEmpty {
                                Text(status)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(Colors.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(16)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 30)
        }
        .onAppear {
            authManager.refreshStatus()
        }
    }

    private func topBar(title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 30, weight: .black))
                .foregroundColor(Colors.textPrimary)
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
                    .padding(10)
                    .background(Circle().fill(Colors.bgPrimary.opacity(0.7)))
            }
        }
    }
}

struct PreventPowerOffSettingsView: View {
    @ObservedObject private var settings = SettingsStore.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            SettingsGlassBackground()

            VStack(alignment: .leading, spacing: 14) {
                topBar(title: "Prevent power-off")

                ProtectionToggleCard(
                    title: "Prevent power-off",
                    subtitle: "Blocks shutdown bypass attempts while alarm/mission is active.",
                    isOn: Binding(
                        get: { settings.triggerShutdownAttemptEnabled },
                        set: { isOn in
                            settings.triggerShutdownAttemptEnabled = isOn
                            settings.preventPowerOffEnabled = isOn
                            if isOn {
                                settings.accountabilityEnabled = true
                                settings.penaltyEnabled = true
                            }
                        }
                    )
                )

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 30)
        }
    }

    private func topBar(title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 30, weight: .black))
                .foregroundColor(Colors.textPrimary)
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
                    .padding(10)
                    .background(Circle().fill(Colors.bgPrimary.opacity(0.7)))
            }
        }
    }
}

private struct ProtectionToggleCard: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        SettingsCard {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(Colors.textPrimary)

                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: SettingsPalette.accent))
                    .padding(.top, 2)
            }
            .padding(16)
        }
    }
}
