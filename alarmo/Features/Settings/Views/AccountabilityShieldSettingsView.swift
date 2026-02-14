import SwiftUI

struct AccountabilityShieldSettingsView: View {
    @ObservedObject var store = SettingsStore.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var showViolationCenter = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                SettingsGlassBackground()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Accountability Shield")
                                .font(.system(size: 34, weight: .bold))
                                .foregroundColor(.white)
                            Text("Global penalty rules")
                                .font(.subheadline)
                                .foregroundColor(Colors.textSecondary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        // Penalty Amount
                        SettingsCard {
                            HStack {
                                Text("Penalty Amount")
                                    .foregroundColor(Colors.textPrimary)
                                Spacer()
                                Menu {
                                    ForEach(1...10, id: \.self) { amount in
                                        Button("€\(amount)") {
                                            store.penaltyAmountEuro = amount
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text("€\(store.penaltyAmountEuro)")
                                            .fontWeight(.bold)
                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(.caption)
                                    }
                                    .foregroundColor(SettingsPalette.accent)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(8)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        
                        // Triggers
                        SettingsCard {
                            // Shutdown
                            SettingsToggleRow(
                                title: "Phone Shutdown",
                                subtitle: "Charge if shutdown attempted while ringing",
                                isOn: Binding(
                                    get: { store.triggerShutdownAttemptEnabled },
                                    set: { store.triggerShutdownAttemptEnabled = $0 }
                                )
                            )
                            
                            // Force Close
                            SettingsToggleRow(
                                title: "Force Close App",
                                subtitle: "Charge if app terminated while ringing",
                                isOn: Binding(
                                    get: { store.penaltyRules.triggerForceCloseEnabled },
                                    set: { store.penaltyRules.triggerForceCloseEnabled = $0 }
                                )
                            )
                            
                            // Tamper/Uninstall
                            SettingsToggleRow(
                                title: "Uninstall & Tamper",
                                subtitle: "Best-effort detection on next reinstall",
                                isOn: Binding(
                                    get: { store.triggerUninstallTamperEnabled },
                                    set: { store.triggerUninstallTamperEnabled = $0 }
                                )
                            )
                            
                            // Snooze Threshold
                            SettingsToggleRow(
                                title: "Excessive Snooze",
                                subtitle: "Charge if snooze limit exceeded",
                                isOn: Binding(
                                    get: { store.triggerSnoozeThresholdEnabled },
                                    set: { store.triggerSnoozeThresholdEnabled = $0 }
                                ),
                                isLast: !store.triggerSnoozeThresholdEnabled
                            )
                            
                            if store.triggerSnoozeThresholdEnabled {
                                HStack {
                                    Text("Snooze Limit")
                                        .foregroundColor(Colors.textSecondary)
                                    Spacer()
                                    Stepper("", value: Binding(
                                        get: { store.snoozePenaltyThreshold },
                                        set: { store.snoozePenaltyThreshold = $0 }
                                    ), in: 1...10)
                                    .labelsHidden()
                                    
                                    Text("\(store.snoozePenaltyThreshold)")
                                        .foregroundColor(Colors.textPrimary)
                                        .frame(minWidth: 20)
                                }
                                .padding(.vertical, 12)
                            }
                            
                            // Restart
                            SettingsToggleRow(
                                title: "Forced Restart",
                                subtitle: "Charge if device hard-reset detected",
                                isOn: Binding(
                                    get: { store.penaltyRules.triggerForcedRestartEnabled },
                                    set: { store.penaltyRules.triggerForcedRestartEnabled = $0 }
                                ),
                                isLast: true
                            )
                            // Airplane Mode (Optional)
                            // SettingsToggleRow(title: "Airplane Mode Abuse", ...)
                        }
                        
                        // Violation Center Link
                        Button(action: { showViolationCenter = true }) {
                            SettingsCard {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                    Text("Violation History")
                                        .foregroundColor(Colors.textPrimary)
                                    Spacer()
                                    if !store.violations.filter({ $0.status == .pendingGracePeriod }).isEmpty {
                                        Text("\(store.violations.filter({ $0.status == .pendingGracePeriod }).count) Pending")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.red)
                                            .cornerRadius(12)
                                    }
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(Colors.textSecondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        
                        // How it works
                        VStack(alignment: .leading, spacing: 12) {
                            Text("HOW PENALTIES WORK")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(Colors.textSecondary)
                            
                            Text("• Penalties are evaluated active ONLY during an active alarm session.\n• All violations trigger a 24-hour grace period before charging.\n• You can request an exemption if the violation was due to a technical issue or emergency.\n• Detection is best-effort due to iOS limitations.")
                                .font(.system(size: 14))
                                .foregroundColor(Colors.textSecondary)
                                .lineSpacing(4)
                        }
                        .padding(.horizontal, 24)
                        
                        Spacer(minLength: 50)
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .tint(SettingsPalette.accent)
                }
            }
            .sheet(isPresented: $showViolationCenter) {
                ViolationCenterView()
            }
        }
    }
}

struct SettingsToggleRow: View {
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool
    var isLast: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            Toggle(isOn: $isOn) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundColor(Colors.textPrimary)
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(Colors.textSecondary)
                    }
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: SettingsPalette.accent))
            .padding(.vertical, 12)
            
            if !isLast {
                Divider()
                    .background(Color.white.opacity(0.1))
            }
        }
    }
}
