import SwiftUI

struct AppProtectionGuideView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                ZStack {
                    SettingsGlassBackground()
                    
                    VStack(alignment: .leading, spacing: Spacing.xl) {
                        // Header
                        VStack(alignment: .leading, spacing: Spacing.s) {
                            Image(systemName: "shield.checkered")
                                .font(.system(size: 60))
                                .foregroundColor(Colors.accentTeal)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.bottom, Spacing.m)
                            
                            Text("App Protection Guide")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(Colors.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .center)
                            
                            Text("Maximize your accountability by enabling iOS restrictions")
                                .font(.system(size: 15))
                                .foregroundColor(Colors.textSecondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                        }
                        .padding(.top, Spacing.xl)
                        
                        // What We Can Do
                        SectionCard(
                            icon: "checkmark.circle.fill",
                            iconColor: .green,
                            title: "What Alarmo Can Do",
                            items: [
                                "✅ Detect shutdown attempts",
                                "✅ Log all attempts with timestamps",
                                "✅ Apply automatic penalties",
                                "✅ Keep screen awake during alarms",
                                "✅ Track accountability metrics"
                            ]
                        )
                        
                        // iOS Limitations
                        SectionCard(
                            icon: "exclamationmark.triangle.fill",
                            iconColor: .orange,
                            title: "iOS Security Limitations",
                            items: [
                                "❌ Cannot prevent device shutdown",
                                "❌ Cannot block power button",
                                "❌ Cannot prevent app deletion",
                                "❌ Cannot disable force restart"
                            ]
                        )
                        
                        // Enable Screen Time
                        VStack(alignment: .leading, spacing: Spacing.m) {
                            HStack(spacing: 12) {
                                Image(systemName: "hourglass.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(Colors.accentTeal)
                                
                                Text("Enable Screen Time Protection")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(Colors.textPrimary)
                            }
                            
                            Text("For maximum protection, enable iOS Screen Time restrictions:")
                                .font(.system(size: 15))
                                .foregroundColor(Colors.textSecondary)
                            
                            VStack(alignment: .leading, spacing: Spacing.m) {
                                StepView(number: 1, text: "Open iOS Settings app")
                                StepView(number: 2, text: "Tap 'Screen Time'")
                                StepView(number: 3, text: "Tap 'Content & Privacy Restrictions'")
                                StepView(number: 4, text: "Enable restrictions if not already on")
                                StepView(number: 5, text: "Tap 'iTunes & App Store Purchases'")
                                StepView(number: 6, text: "Tap 'Deleting Apps'")
                                StepView(number: 7, text: "Select 'Don't Allow'")
                                StepView(number: 8, text: "Set a Screen Time passcode")
                            }
                            .padding(.vertical, Spacing.m)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Colors.cardSurface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Colors.cardStroke, lineWidth: 1)
                        )
                        
                        // Guided Access
                        VStack(alignment: .leading, spacing: Spacing.m) {
                            HStack(spacing: 12) {
                                Image(systemName: "lock.shield.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(Colors.accentTeal)
                                
                                Text("Use Guided Access")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(Colors.textPrimary)
                            }
                            
                            Text("Lock your device to Alarmo before sleep:")
                                .font(.system(size: 15))
                                .foregroundColor(Colors.textSecondary)
                            
                            VStack(alignment: .leading, spacing: Spacing.m) {
                                StepView(number: 1, text: "Settings > Accessibility > Guided Access")
                                StepView(number: 2, text: "Enable Guided Access")
                                StepView(number: 3, text: "Set a passcode")
                                StepView(number: 4, text: "Before sleep, triple-click side button in Alarmo")
                                StepView(number: 5, text: "Tap 'Start' to lock to this app")
                            }
                            
                            Text("⚠️ You'll need to triple-click and enter passcode to exit")
                                .font(.caption)
                                .foregroundColor(Colors.textSecondary)
                                .padding(.top, Spacing.s)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Colors.cardSurface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Colors.cardStroke, lineWidth: 1)
                        )
                        
                        // Bottom Note
                        Text("These iOS features provide the strongest protection available while respecting Apple's security model.")
                            .font(.caption)
                            .foregroundColor(Colors.textSecondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.top, Spacing.m)
                    }
                    .padding(.horizontal, Spacing.l)
                    .padding(.bottom, Spacing.xl)
                }
            }
            .navigationTitle("Protection Guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Colors.accentTeal)
                }
            }
        }
    }
}

struct SectionCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let items: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(iconColor)
                
                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Colors.textPrimary)
            }
            
            VStack(alignment: .leading, spacing: Spacing.s) {
                ForEach(items, id: \.self) { item in
                    Text(item)
                        .font(.system(size: 15))
                        .foregroundColor(Colors.textSecondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Colors.cardSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Colors.cardStroke, lineWidth: 1)
        )
    }
}

struct StepView: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Colors.bgPrimary)
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(Colors.accentTeal)
                )
            
            Text(text)
                .font(.system(size: 15))
                .foregroundColor(Colors.textPrimary)
        }
    }
}

#Preview {
    AppProtectionGuideView()
}
