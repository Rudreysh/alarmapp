import SwiftUI

struct AccountabilityShieldSettingsView: View {
    @ObservedObject var store = SettingsStore.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var showViolationCenter = false
    @State private var showInfo = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                SettingsGlassBackground()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header with Visual
                        VStack(spacing: 16) {
                            Image(systemName: "shield.checkered")
                                .font(.system(size: 64))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Colors.accentTeal, Colors.accentTeal.opacity(0.6)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: Colors.accentTeal.opacity(0.3), radius: 10, x: 0, y: 5)
                            
                            VStack(spacing: 4) {
                                Text("Accountability Shield")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.white)
                                Text("Global Penalty Rules")
                                    .font(.subheadline)
                                    .foregroundColor(Colors.textSecondary)
                            }
                        }
                        .padding(.top, 24)
                        
                        // Penalty Amount Tile (Standalone)
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("PENALTY STAKE")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(Colors.textSecondary)
                                Text("Penalty Amount")
                                    .font(.headline)
                                    .foregroundColor(Colors.textPrimary)
                            }
                            
                            Spacer()
                            
                            Menu {
                                ForEach(1...10, id: \.self) { amount in
                                    Button("€\(amount)") {
                                        store.penaltyAmountEuro = amount
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Text("€\(store.penaltyAmountEuro)")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.caption)
                                }
                                .foregroundColor(Colors.bgPrimary)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule()
                                        .fill(Colors.accentTeal)
                                )
                            }
                        }
                        .padding(16)
                        .background(Colors.cardSurface)
                        .cornerRadius(16)
                        
                        // Triggers Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("TRIGGERS")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(Colors.textSecondary)
                                .padding(.leading, 8)
                            
                            // Shutdown
                            ShieldTile(
                                icon: "power.circle.fill",
                                color: .red,
                                title: "Phone Shutdown",
                                subtitle: "Turning off phone while ringing",
                                isOn: Binding(
                                    get: { store.triggerShutdownAttemptEnabled },
                                    set: { store.triggerShutdownAttemptEnabled = $0 }
                                )
                            )
                            
                            // Force Close
                            ShieldTile(
                                icon: "xmark.circle.fill",
                                color: .orange,
                                title: "Force Close App",
                                subtitle: "Killing the app from multitasking",
                                isOn: Binding(
                                    get: { store.penaltyRules.triggerForceCloseEnabled },
                                    set: { store.penaltyRules.triggerForceCloseEnabled = $0 }
                                )
                            )
                            
                            // Restart
                            ShieldTile(
                                icon: "arrow.triangle.2.circlepath.circle.fill",
                                color: .yellow,
                                title: "Forced Restart",
                                subtitle: "Hard resetting device",
                                isOn: Binding(
                                    get: { store.penaltyRules.triggerForcedRestartEnabled },
                                    set: { store.penaltyRules.triggerForcedRestartEnabled = $0 }
                                )
                            )
                            
                            // Tamper
                            ShieldTile(
                                icon: "trash.circle.fill",
                                color: .purple,
                                title: "Uninstall & Tamper",
                                subtitle: "Deleting app during alarm",
                                isOn: Binding(
                                    get: { store.triggerUninstallTamperEnabled },
                                    set: { store.triggerUninstallTamperEnabled = $0 }
                                )
                            )
                            
                            // Snooze
                            ShieldTile(
                                icon: "zzz",
                                color: .blue,
                                title: "Excessive Snooze",
                                subtitle: "Exceeding snooze limit",
                                isOn: Binding(
                                    get: { store.triggerSnoozeThresholdEnabled },
                                    set: { store.triggerSnoozeThresholdEnabled = $0 }
                                )
                            )
                            
                            // Nested Snooze Config
                            if store.triggerSnoozeThresholdEnabled {
                                HStack {
                                    Image(systemName: "number.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(Colors.textSecondary)
                                        .frame(width: 32)
                                    
                                    Text("Max Snoozes Allowed")
                                        .font(.system(size: 16))
                                        .foregroundColor(Colors.textPrimary)
                                    
                                    Spacer()
                                    
                                    HStack(spacing: 16) {
                                        Button(action: {
                                            if store.snoozePenaltyThreshold > 1 { store.snoozePenaltyThreshold -= 1 }
                                        }) {
                                            Image(systemName: "minus.circle.fill")
                                                .font(.title2)
                                                .foregroundColor(Colors.textSecondary)
                                        }
                                        
                                        Text("\(store.snoozePenaltyThreshold)")
                                            .font(.headline)
                                            .foregroundColor(Colors.textPrimary)
                                            .frame(width: 20)
                                        
                                        Button(action: {
                                            if store.snoozePenaltyThreshold < 10 { store.snoozePenaltyThreshold += 1 }
                                        }) {
                                            Image(systemName: "plus.circle.fill")
                                                .font(.title2)
                                                .foregroundColor(Colors.accentTeal)
                                        }
                                    }
                                }
                                .padding(16)
                                .background(Colors.cardSurface)
                                .cornerRadius(16)
                            }
                        }
                        
                        // Violation History Tile
                        Button(action: { showViolationCenter = true }) {
                            HStack {
                                ZStack {
                                    Circle()
                                        .fill(Color.orange.opacity(0.2))
                                        .frame(width: 40, height: 40)
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                        .font(.system(size: 20))
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Violation History")
                                        .font(.headline)
                                        .foregroundColor(Colors.textPrimary)
                                    Text("Check past charges")
                                        .font(.caption)
                                        .foregroundColor(Colors.textSecondary)
                                }
                                
                                Spacer()
                                
                                // Pending Badge
                                let pendingCount = store.violations.filter({ $0.status == .pendingGracePeriod }).count
                                if pendingCount > 0 {
                                    Text("\(pendingCount) Pending")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Capsule().fill(Color.red))
                                }
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(Colors.textSecondary)
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .padding(16)
                            .background(Colors.cardSurface)
                            .cornerRadius(16)
                        }
                        
                        // Info Footer
                        VStack(spacing: 16) {
                            Button(action: { showInfo.toggle() }) {
                                HStack {
                                    Image(systemName: "info.circle")
                                    Text("How Penalties Work")
                                    Image(systemName: "chevron.down")
                                        .rotationEffect(.degrees(showInfo ? 180 : 0))
                                }
                                .font(.subheadline)
                                .foregroundColor(Colors.textSecondary)
                            }
                            
                            if showInfo {
                                VStack(alignment: .leading, spacing: 12) {
                                    InfoRow(text: "Penalties are only active during a ringing alarm session.")
                                    InfoRow(text: "Violations trigger a 24-hour grace period before charging.")
                                    InfoRow(text: "You can request an exemption for bugs or emergencies.")
                                    InfoRow(text: "Detection is best-effort due to iOS limitations.")
                                }
                                .padding()
                                .background(Colors.cardSurface)
                                .cornerRadius(12)
                                .transition(.opacity)
                            }
                        }
                        .padding(.horizontal, 24)
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Colors.accentTeal)
                }
            }
            .sheet(isPresented: $showViolationCenter) {
                ViolationCenterView()
            }
        }
    }
}

// MARK: - Subviews

struct ShieldTile: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
                .frame(width: 32)
            
            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Colors.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(Colors.textSecondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: Colors.accentTeal))
        }
        .padding(16)
        .background(Colors.cardSurface)
        .cornerRadius(16)
    }
}

struct InfoRow: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(Colors.textSecondary)
                .frame(width: 4, height: 4)
                .padding(.top, 6)
            Text(text)
                .font(.caption)
                .foregroundColor(Colors.textSecondary)
                .lineSpacing(4)
        }
    }
}

#Preview {
    AccountabilityShieldSettingsView()
}
