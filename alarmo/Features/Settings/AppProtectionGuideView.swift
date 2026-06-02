import SwiftUI
import AVFoundation

struct AppProtectionGuideView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            SettingsGlassBackground()
            
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Header Area
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Colors.accentTeal.opacity(0.15))
                                .frame(width: 80, height: 80)
                            Image(systemName: "bell.badge.trianglebadge.exclamationmark")
                                .font(.system(size: 36))
                                .foregroundColor(Colors.accentTeal)
                        }
                        
                        Text("Alarm Optimization")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Actionable tips and deep-OS integrations to ensure you never sleep through an alarm again.")
                            .font(.system(size: 15))
                            .foregroundColor(Colors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .padding(.top, 24)
                    
                    // Section 1: Quick Fixes
                    VStack(alignment: .leading, spacing: 12) {
                        Text("QUICK FIXES")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Colors.textTertiary)
                            .padding(.leading, 16)
                            
                        SettingsCard {
                            SettingsActionRow(
                                title: "Notification Settings",
                                subtitle: "Alarms rely on notifications. Ensure they are enabled.",
                                trailingText: "Check",
                                icon: "bell.badge.fill",
                                iconColor: Colors.accentBlue,
                                isLast: false
                            ) {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }
                            
                            SettingsActionRow(
                                title: "Test Ring Volume",
                                subtitle: "Make sure your device ringer is loud enough.",
                                trailingText: "Test",
                                icon: "speaker.wave.3.fill",
                                iconColor: Colors.accentGreen,
                                isLast: true
                            ) {
                                // Simple system sound test alert
                                AudioServicesPlaySystemSound(1005)
                            }
                        }
                    }
                    
                    // Section 2: Sleep & Do Not Disturb
                    VStack(alignment: .leading, spacing: 12) {
                        Text("FOCUS & DO NOT DISTURB")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Colors.textTertiary)
                            .padding(.leading, 16)
                            
                        SettingsCard {
                            SettingsNavigationRow(
                                title: "Whitelist Alarmo",
                                subtitle: "Ensure alarms bypass Apple's Sleep Mode Focus",
                                icon: "moon.stars.fill",
                                iconColor: Colors.accentOrange,
                                isLast: true,
                                destination: FocusModeSetupView()
                            )
                        }
                    }
                    
                    // Section 3: Hardcore Accountability
                    VStack(alignment: .leading, spacing: 12) {
                        Text("ADVANCED iOS PROTECTION")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Colors.textTertiary)
                            .padding(.leading, 16)
                            
                        SettingsCard {
                            SettingsNavigationRow(
                                title: "Guided Access Mode",
                                subtitle: "Lock your device to Alarmo overnight",
                                icon: "lock.shield.fill",
                                iconColor: Colors.accentRed,
                                isLast: false,
                                destination: GuidedAccessSetupView()
                            )
                            
                            SettingsNavigationRow(
                                title: "Screen Time Restrictions",
                                subtitle: "Prevent app deletion and bypasses",
                                icon: "hourglass",
                                iconColor: Colors.saleBadgeEnd,
                                isLast: true,
                                destination: ScreenTimeSetupView()
                            )
                        }
                    }
                    
                    // Section 4: Diagnostics
                    VStack(alignment: .leading, spacing: 12) {
                        Text("ABOUT CAPABILITIES")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Colors.textTertiary)
                            .padding(.leading, 16)
                            
                        SettingsCard {
                            SettingsNavigationRow(
                                title: "What Alarmo Can & Cannot Do",
                                subtitle: "Apple's security limits explained",
                                icon: "info.circle.fill",
                                iconColor: Colors.textSecondary,
                                isLast: true,
                                destination: iOSLimitationsView()
                            )
                        }
                    }
                    
                    Spacer(minLength: 40)
                }
            }
        }
        .navigationTitle("Alarm Optimization")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Subviews
struct FocusModeSetupView: View {
    var body: some View {
        OptimizationGuideContainer(
            title: "Focus Mode",
            icon: "moon.fill",
            iconColor: Colors.accentOrange,
            description: "If you use Sleep Mode or Do Not Disturb, you must whitelist Alarmo so notifications and sounds can reach you.",
            steps: [
                "Open the iOS 'Settings' app.",
                "Tap on 'Focus'.",
                "Select 'Sleep' (or whichever mode you use at night).",
                "Under 'Allowed Notifications', tap 'Apps'.",
                "Tap 'Add Apps' and select Alarmo from the list.",
                "Ensure 'Time Sensitive Notifications' is also enabled."
            ],
            actionButtonTitle: "Open iOS Settings"
        ) {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        }
    }
}

struct GuidedAccessSetupView: View {
    var body: some View {
        OptimizationGuideContainer(
            title: "Guided Access",
            icon: "lock.shield.fill",
            iconColor: Colors.accentRed,
            description: "Guided Access is the most powerful way to prevent escaping Alarmo. It locks your iPhone to a single app.",
            steps: [
                "Open iOS 'Settings' > 'Accessibility'.",
                "Scroll down and tap 'Guided Access'.",
                "Turn Guided Access ON.",
                "Tap 'Passcode Settings' and set a Guided Access Passcode.",
                "At night, open Alarmo and triple-click your device's side button.",
                "Tap 'Start' to lock your screen to Alarmo."
            ],
            warnText: "⚠️ You will need to triple-click and enter your passcode to exit the app in the morning."
        )
    }
}

struct ScreenTimeSetupView: View {
    var body: some View {
        OptimizationGuideContainer(
            title: "Screen Time",
            icon: "hourglass",
            iconColor: Colors.saleBadgeEnd,
            description: "Prevent yourself from deleting Alarmo in the middle of the night to avoid the alarm.",
            steps: [
                "Open iOS 'Settings' > 'Screen Time'.",
                "Tap 'Content & Privacy Restrictions'.",
                "Turn them ON at the top.",
                "Tap 'iTunes & App Store Purchases'.",
                "Tap 'Deleting Apps' and set it to 'Don't Allow'.",
                "Go back to the main Screen Time menu and 'Lock Screen Time Settings' with a passcode."
            ],
            warnText: "⚠️ It's highly recommended to have a friend or partner set the Screen Time passcode so you don't know it."
        )
    }
}

struct iOSLimitationsView: View {
    var body: some View {
        ZStack {
            SettingsGlassBackground()
            ScrollView {
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("What Alarmo Can Do")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                        VStack(alignment: .leading, spacing: 12) {
                            GuideBullet(icon: "checkmark.circle.fill", color: .green, text: "Play very loud critical alarms even in silent mode (when configured).")
                            GuideBullet(icon: "checkmark.circle.fill", color: .green, text: "Detect if you attempt to force close the app.")
                            GuideBullet(icon: "checkmark.circle.fill", color: .green, text: "Apply penalties via the Accountability Penalty.")
                            GuideBullet(icon: "checkmark.circle.fill", color: .green, text: "Keep the screen awake when the app is active.")
                        }
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 16).fill(Colors.cardSurface))
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("iOS Security Limitations")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                        VStack(alignment: .leading, spacing: 12) {
                            GuideBullet(icon: "xmark.circle.fill", color: .red, text: "We cannot physically prevent you from turning your iPhone off.")
                            GuideBullet(icon: "xmark.circle.fill", color: .red, text: "We cannot block the power button.")
                            GuideBullet(icon: "xmark.circle.fill", color: .red, text: "We cannot turn the phone back on once it is off.")
                            GuideBullet(icon: "xmark.circle.fill", color: .red, text: "We cannot natively stop you from force restarting the device.")
                        }
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 16).fill(Colors.cardSurface))
                    
                }
                .padding(20)
            }
        }
        .navigationTitle("Capabilities")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct GuideBullet: View {
    let icon: String
    let color: Color
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 18))
            Text(text)
                .font(.system(size: 15))
                .foregroundColor(Colors.textSecondary)
        }
    }
}

// Shared layout for guides
struct OptimizationGuideContainer: View {
    let title: String
    let icon: String
    let iconColor: Color
    let description: String
    let steps: [String]
    var warnText: String? = nil
    var actionButtonTitle: String? = nil
    var action: (() -> Void)? = nil
    
    var body: some View {
        ZStack {
            SettingsGlassBackground()
            
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Header
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(iconColor.opacity(0.15))
                                .frame(width: 80, height: 80)
                            Image(systemName: icon)
                                .font(.system(size: 36))
                                .foregroundColor(iconColor)
                        }
                        
                        Text(title)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text(description)
                            .font(.system(size: 16))
                            .foregroundColor(Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 24)
                    
                    // Steps
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top, spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(Colors.accentTeal)
                                        .frame(width: 28, height: 28)
                                    Text("\(index + 1)")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(Colors.bgPrimary)
                                }
                                
                                Text(step)
                                    .font(.system(size: 16))
                                    .foregroundColor(Colors.textPrimary)
                                    .padding(.top, 4)
                            }
                        }
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 16).fill(Colors.cardSurface))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Colors.cardStroke, lineWidth: 1))
                    
                    if let warn = warnText {
                        Text(warn)
                            .font(.footnote)
                            .foregroundColor(Colors.accentOrange)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    if let actionTitle = actionButtonTitle, let actionFunc = action {
                        Button(action: actionFunc) {
                            Text(actionTitle)
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(RoundedRectangle(cornerRadius: 14).fill(Colors.accentTeal))
                        }
                        .padding(.top, 8)
                    }
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    AppProtectionGuideView()
}
