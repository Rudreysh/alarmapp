import SwiftUI

struct SettingsRootView: View {
    @ObservedObject var preferences: AppPreferences
    @ObservedObject private var store = SettingsStore.shared
    @StateObject private var subManager = SubscriptionManager.shared
    @StateObject private var coordinator = SettingsCoordinator()

    @Environment(\.openURL) private var openURL

    @State private var showSignIn = false
    @State private var showDeleteAccountDialog = false
    @State private var infoAlertMessage: String?

    @AppStorage("settings.localAccountId") private var localAccountId: String = UUID().uuidString

    private let supportEmail = "support@alarmo.app"
    private let privacyURL = URL(string: "https://alarmo.app/privacy")!
    private let termsURL = URL(string: "https://alarmo.app/terms")!
    private let discordURL = URL(string: "https://discord.gg/alarmo")!

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            ZStack {
                Colors.bgPrimary.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: Spacing.l) {
                        Text("Settings")
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundColor(Colors.textPrimary)
                            .padding(.horizontal, Spacing.l)
                            .padding(.top, Spacing.s)

                        profileSection

                        section(title: "Preferences") {
                            // TEMPORARILY DISABLED (Penalty rollout paused):
                            // Keep penalty route and screen code in the project for future implementation.
                            // The settings entry is intentionally hidden for now.

                            SettingsCategoryNavRow(
                                title: settingsStatusTitle(
                                    base: "Prevent app uninstall",
                                    enabled: store.triggerUninstallTamperEnabled
                                ),
                                icon: "shield",
                                iconColor: .cyan,
                                isLast: false
                            ) {
                                coordinator.navigate(to: .preventAppUninstall)
                            }

                            SettingsCategoryNavRow(
                                title: settingsStatusTitle(
                                    base: "Prevent power-off",
                                    enabled: store.triggerShutdownAttemptEnabled
                                ),
                                icon: "bolt.shield",
                                iconColor: .green,
                                isLast: false
                            ) {
                                coordinator.navigate(to: .preventPowerOff)
                            }

                            SettingsCategoryNavRow(title: "Notifications", icon: "bell", iconColor: .gray, isLast: false) {
                                coordinator.navigate(to: .notification)
                            }

                            SettingsCategoryToggleRow(
                                title: "Light Mode",
                                icon: "sun.max",
                                iconColor: .gray,
                                isOn: Binding(
                                    get: { store.themeMode == .light },
                                    set: { isLightOn in
                                        store.themeMode = isLightOn ? .light : .dark
                                    }
                                ),
                                isLast: false
                            )

                            SettingsCategoryNavRow(title: "Alarm", icon: "alarm", iconColor: .orange, isLast: false) {
                                coordinator.navigate(to: .alarm)
                            }

                            SettingsCategoryNavRow(title: "Habit", icon: "repeat", iconColor: .green, isLast: false) {
                                coordinator.navigate(to: .habit)
                            }

                            SettingsCategoryNavRow(title: "Timer", icon: "timer", iconColor: .blue, isLast: false) {
                                coordinator.navigate(to: .timer)
                            }

                            SettingsCategoryNavRow(title: "App Configurations", icon: "gearshape", iconColor: .gray, isLast: true) {
                                coordinator.navigate(to: .system)
                            }
                        }

                        section(title: "Support") {
                            SettingsCategoryActionRow(title: "Request a Feature", icon: "lightbulb", iconColor: .gray, isLast: false) {
                                openMail(subject: "Feature Request")
                            }

                            SettingsCategoryActionRow(title: "Contact Support", icon: "questionmark.circle", iconColor: .gray, isLast: false) {
                                openMail(subject: "Support Request")
                            }

                            SettingsCategoryActionRow(title: "Join our Discord", icon: "bubble.left.and.bubble.right", iconColor: .gray, isLast: true) {
                                openURL(discordURL)
                            }
                        }

                        section(title: "Legal") {
                            SettingsCategoryActionRow(title: "Privacy Policy", icon: "lock.shield", iconColor: .gray, isLast: false) {
                                openURL(privacyURL)
                            }

                            SettingsCategoryActionRow(title: "Terms of Service", icon: "doc.text", iconColor: .gray, isLast: true) {
                                openURL(termsURL)
                            }
                        }

                        section(title: "Account") {
                            SettingsCategoryActionRow(title: "Cancel Subscription", icon: "xmark.circle", iconColor: .gray, isLast: false) {
                                openURL(subManager.manageSubscriptionsURL)
                            }

                            SettingsCategoryActionRow(title: "Manage Subscription", icon: "creditcard", iconColor: .gray, isLast: false) {
                                openURL(subManager.manageSubscriptionsURL)
                            }

                            SettingsCategoryActionRow(title: "Copy Account ID", icon: "doc.on.doc", iconColor: .gray, isLast: false) {
                                UIPasteboard.general.string = accountIdentifier
                                infoAlertMessage = "Account ID copied"
                            }

                            SettingsCategoryActionRow(title: "Delete Account", icon: "trash", iconColor: .red, titleColor: .red, isLast: true) {
                                showDeleteAccountDialog = true
                            }
                        }

                        Text(appVersionFooter)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Colors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                            .padding(.top, Spacing.s)
                    }
                    .padding(.bottom, AppConstants.tabBarHeight + 24)
                }
            }
            .navigationDestination(for: SettingsRoute.self) { route in
                switch route {
                case .points:
                    MyPointsView()
                case .pro:
                    ProView()
                case .penalty:
                    PreventPowerOffView()
                case .preventAppUninstall:
                    PreventAppUninstallView()
                case .preventPowerOff:
                    PreventPowerOffSettingsView()
                case .alarm:
                    AlarmSettingsView()
                case .habit:
                    HabitSettingsView()
                case .timer:
                    TimerSettingsMenuView(preferences: preferences)
                case .advanced:
                    AdvancedSettingsView()
                case .theme:
                    ThemeSettingsView()
                case .soundOutput:
                    SoundOutputView()
                case .notification:
                    NotificationSettingsView()
                case .system:
                    SystemConfigurationView()
                case .faq:
                    FAQView()
                case .optimization:
                    AppProtectionGuideView()
                case .permissions:
                    PermissionsView()
                case .notice:
                    NoticeView()
                }
            }
        }
        .fullScreenCover(isPresented: $showSignIn) {
            SignInView()
        }
        .confirmationDialog("Delete account?", isPresented: $showDeleteAccountDialog, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                store.signOutAppleAccount()
                localAccountId = UUID().uuidString
                infoAlertMessage = "Account removed from this device"
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This signs you out and clears local account identity from this device.")
        }
        .alert(
            "Settings",
            isPresented: Binding(
                get: { infoAlertMessage != nil },
                set: { if !$0 { infoAlertMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {
                infoAlertMessage = nil
            }
        } message: {
            Text(infoAlertMessage ?? "")
        }
        .onAppear {
            store.validateAppleCredentialStateIfNeeded()
        }
    }

    private var accountIdentifier: String {
        let trimmed = store.appleUserId.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? localAccountId : trimmed
    }

    private var appVersionFooter: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "Alarmo v\(version) (\(build))"
    }

    private func openMail(subject: String) {
        let encoded = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Support"
        if let mailURL = URL(string: "mailto:\(supportEmail)?subject=\(encoded)") {
            openURL(mailURL)
        }
    }

    private func settingsStatusTitle(base: String, enabled: Bool) -> String {
        "\(base) • \(enabled ? "on" : "off")"
    }

    private var profileDisplayTitle: String {
        if store.isSignedIn {
            let trimmed = store.profileDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "Apple Account" : trimmed
        }
        return "Sign up or log in"
    }

    private var profileDisplaySubtitle: String {
        if store.isSignedIn {
            let email = store.appleEmail.trimmingCharacters(in: .whitespacesAndNewlines)
            return email.isEmpty ? "Email not available" : email
        }
        return "You are currently on guest mode"
    }

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Profile")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Colors.textSecondary)
                .padding(.horizontal, Spacing.l)

            VStack(spacing: 0) {
                Button {
                    showSignIn = true
                } label: {
                    VStack(spacing: 10) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 58, weight: .regular))
                            .foregroundColor(Colors.textSecondary.opacity(0.35))
                            .padding(.top, 4)

                        HStack(spacing: 10) {
                            Text(profileDisplayTitle)
                                .font(.system(size: 18, weight: .black, design: .rounded))
                                .foregroundColor(Colors.textPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)

                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .black))
                                .foregroundColor(Colors.textSecondary)
                        }

                        Text(profileDisplaySubtitle)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Colors.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                            .padding(.horizontal, 8)

                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                    .padding(.bottom, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressedScaleButtonStyle())

                Divider()
                    .background(Colors.cardStroke)
                    .padding(.horizontal, 14)

                HStack(spacing: 0) {
                    Button {
                        coordinator.navigate(to: .points)
                    } label: {
                        VStack(spacing: 6) {
                            HStack(spacing: 4) {
                                Text("\(store.points)")
                                    .font(.system(size: 28, weight: .black, design: .rounded))
                                    .foregroundColor(Colors.textPrimary)
                                Text("🔥")
                                    .font(.system(size: 14))
                            }
                            Text("my points")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Colors.textPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressedScaleButtonStyle())

                    Divider()
                        .background(Colors.cardStroke)
                        .frame(height: 54)

                    Button {
                        coordinator.navigate(to: .pro)
                    } label: {
                        VStack(spacing: 6) {
                            Text(subManager.isPro ? "PRO" : "FREE")
                                .font(.system(size: 24, weight: .black, design: .rounded))
                                .foregroundColor(Colors.textPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            Text("subscription")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Colors.textPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressedScaleButtonStyle())
                }
            }
            .background(Colors.cardSurface)
            .cornerRadius(22)
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Colors.cardStroke, lineWidth: 1)
            )
            .padding(.horizontal, Spacing.l)
        }
    }

    @ViewBuilder
    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Colors.textSecondary)
                .padding(.horizontal, Spacing.l)

            VStack(spacing: 0) {
                content()
            }
            .background(Colors.cardSurface)
            .cornerRadius(22)
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Colors.cardStroke, lineWidth: 1)
            )
            .padding(.horizontal, Spacing.l)
        }
    }
}

private struct SettingsCategoryNavRow: View {
    let title: String
    let icon: String
    let iconColor: Color
    let isLast: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SettingsCategoryRowBase(title: title, icon: icon, iconColor: iconColor, trailing: AnyView(
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Colors.textTertiary)
            ))
        }
        .buttonStyle(PressedScaleButtonStyle())
        .overlay {
            if !isLast {
                VStack {
                    Spacer()
                    Divider()
                        .background(Colors.cardStroke)
                        .padding(.leading, 58)
                }
            }
        }
    }
}

private struct SettingsCategoryActionRow: View {
    let title: String
    let icon: String
    let iconColor: Color
    var titleColor: Color = Colors.textPrimary
    let isLast: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SettingsCategoryRowBase(title: title, icon: icon, iconColor: iconColor, titleColor: titleColor, trailing: AnyView(
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Colors.textTertiary)
            ))
        }
        .buttonStyle(PressedScaleButtonStyle())
        .overlay {
            if !isLast {
                VStack {
                    Spacer()
                    Divider()
                        .background(Colors.cardStroke)
                        .padding(.leading, 58)
                }
            }
        }
    }
}

private struct SettingsCategoryToggleRow: View {
    let title: String
    let icon: String
    let iconColor: Color
    @Binding var isOn: Bool
    let isLast: Bool

    var body: some View {
        SettingsCategoryRowBase(title: title, icon: icon, iconColor: iconColor, trailing: AnyView(
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(Colors.accentTeal)
        ))
        .overlay {
            if !isLast {
                VStack {
                    Spacer()
                    Divider()
                        .background(Colors.cardStroke)
                        .padding(.leading, 58)
                }
            }
        }
    }
}

private struct SettingsCategoryRowBase: View {
    let title: String
    let icon: String
    let iconColor: Color
    var titleColor: Color = Colors.textPrimary
    let trailing: AnyView

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(iconColor)
                .frame(width: 28)

            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(titleColor)

            Spacer()

            trailing
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}
