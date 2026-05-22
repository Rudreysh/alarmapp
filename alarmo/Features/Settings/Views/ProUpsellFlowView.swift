import SwiftUI

struct ProUpsellFlowView: View {
    @Environment(\.dismiss) var dismiss
    @State private var stepIndex: Int = 0
    @ObservedObject var subManager = SubscriptionManager.shared
    @State private var showPaywall = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Colors.bgPrimary.ignoresSafeArea()
                
                if stepIndex == 0 {
                    UpsellBenefitsView(onNext: {
                        withAnimation(.easeInOut) { stepIndex = 1 }
                    })
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                } else if stepIndex == 1 {
                    UpsellTrialDesignView(onNext: {
                        withAnimation(.easeInOut) { stepIndex = 2 }
                    })
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                } else if stepIndex == 2 {
                    UpsellReminderView(onNext: {
                        showPaywall = true
                    })
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                }
            }
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Colors.textSecondary)
                            .font(.system(size: 24))
                    }
                }
                
                ToolbarItem(placement: .topBarLeading) {
                    if stepIndex > 0 {
                        Button(action: { withAnimation { stepIndex -= 1 } }) {
                            Image(systemName: "chevron.left")
                                .foregroundColor(.white)
                                .font(.system(size: 18, weight: .bold))
                        }
                    }
                }
            }
            .fullScreenCover(isPresented: $showPaywall) {
                PaywallView(
                    onClose: { showPaywall = false },
                    onSuccess: {
                        Task { @MainActor in
                            await subManager.refreshEntitlements()
                        }
                        showPaywall = false
                        dismiss()
                    }
                )
            }
        }
    }
}

// MARK: - Screen 1: Benefits Display
struct UpsellBenefitsView: View {
    let onNext: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Faux Bar Chart comparison
                HStack(spacing: 16) {
                    ComparisonChartCard(title: "Before Awayk", duration: "1h 32m", type: .before)
                    ComparisonChartCard(title: "After Awayk", duration: "0h 12m", type: .after)
                }
                .padding(.horizontal)
                .padding(.top, 16)
                
                Text("Build a better sleep routine")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                VStack(spacing: 24) {
                    BenefitRow(icon: "alarm.fill", title: "Smart Alarms.", text: "Wake up gently and reliably.", iconColor: Colors.accentTeal)
                    BenefitRow(icon: "timer", title: "Pomodoro Timer.", text: "Stay focused and productive.")
                    BenefitRow(icon: "checklist", title: "Habit Tracker.", text: "Build consistent routines.")
                    BenefitRow(icon: "globe.americas", title: "Overlap Timezones.", text: "Compare times anywhere instantly.")
                }
                .padding(.horizontal)
                
                Spacer(minLength: 20)
            }
        }
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: "Continue", style: .blueGlass) {
                onNext()
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
    }
}

// Helper Subviews for Benefits
struct ComparisonChartCard: View {
    let title: String
    let duration: String
    let type: ChartType
    
    enum ChartType { case before, after }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 16))
                .foregroundColor(.white)
            
            Text("Snooze Time")
                .font(.system(size: 10))
                .foregroundColor(Colors.textSecondary)
            
            Text(duration)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
            
            // Faux graph visualization
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(0..<5) { idx in
                    Rectangle()
                        .fill(type == .before ? Colors.accentTeal : Colors.accentBlue)
                        .frame(width: 12, height: type == .before ? CGFloat.random(in: 20...60) : CGFloat.random(in: 4...15))
                        .cornerRadius(2)
                }
            }
            .frame(height: 60, alignment: .bottom)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
    }
}

struct BenefitRow: View {
    let icon: String
    let title: String
    let text: String
    var iconColor: Color = .white
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .font(.system(size: 24))
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Text(text)
                    .font(.system(size: 15))
                    .foregroundColor(Colors.textSecondary)
            }
            Spacer()
        }
    }
}

// MARK: - Screen 2: Trial Design & Plans
struct UpsellTrialDesignView: View {
    let onNext: () -> Void
    @State private var selectedPlan: Int = 0
    
    var body: some View {
        VStack(spacing: 0) {
            Text("Design Your Trial\nExperience")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.top, 16)
                .padding(.bottom, 32)
            
            // Timeline
            VStack(alignment: .leading, spacing: 0) {
                TimelineRow(icon: "checkmark", title: "Get your Setup Ready", text: "You successfully started your journey to better productivity.", isFirst: true, isLast: false)
                TimelineRow(icon: "lock", title: "Today: Boost Motivation", text: "Set smart routines, utilize Pomodoro timers, and build consistent habits.", isFirst: false, isLast: false)
                TimelineRow(icon: "bell.fill", title: "Day 6: See first results", text: "We'll send a report to show how your focus and habits improved.", isFirst: false, isLast: false)
                TimelineRow(icon: "star.fill", title: "Day 7: Take your next steps", text: "Continue building productive habits with Awayk's advanced features.", isFirst: false, isLast: true)
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Bottom Sheet Area
            VStack(spacing: 16) {
                SelectionRow(title: "Starter Trial", subtitle: "Trial availability shown at checkout", isSelected: selectedPlan == 0) {
                    selectedPlan = 0
                }
                
                SelectionRow(title: "Monthly Plan", subtitle: "Price shown at checkout", isSelected: selectedPlan == 1) {
                    selectedPlan = 1
                }
                
                HStack(spacing: 8) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                    Text("Pricing and renewal terms are shown at checkout")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(Colors.textSecondary)
                .padding(.top, 8)
                
                PrimaryButton(title: selectedPlan == 0 ? "Continue with trial options" : "Continue with monthly options", style: .blueGlass) {
                    onNext()
                }
                .padding(.bottom, 8)
                
                Text(selectedPlan == 0 ? "Trial and subscription details appear before purchase confirmation." : "Monthly terms appear before purchase confirmation.")
                    .font(.footnote)
                    .foregroundColor(Colors.textTertiary)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 32)
                    .fill(Colors.cardSurface)
                    .ignoresSafeArea(edges: .bottom)
            )
        }
    }
}

// Timeline helpers
struct TimelineRow: View {
    let icon: String
    let title: String
    let text: String
    let isFirst: Bool
    let isLast: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 0) {
                if !isFirst {
                    Rectangle()
                        .fill(Colors.textSecondary.opacity(0.3))
                        .frame(width: 2, height: 20)
                }
                
                ZStack {
                    Circle()
                        .fill(Colors.bgPrimary)
                        .frame(width: 30, height: 30)
                    Image(systemName: icon)
                        .foregroundColor(.white)
                        .font(.system(size: 12, weight: .bold))
                }
                .overlay(Circle().stroke(Colors.textSecondary.opacity(0.5), lineWidth: 2))
                
                if !isLast {
                    Rectangle()
                        .fill(Colors.textSecondary.opacity(0.3))
                        .frame(width: 2)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Text(text)
                    .font(.system(size: 14))
                    .foregroundColor(Colors.textSecondary)
            }
            .padding(.top, 4)
            .padding(.bottom, 24)
            
            Spacer()
        }
        .frame(minHeight: 60)
    }
}

struct SelectionRow: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.system(size: 15))
                        .foregroundColor(Colors.textSecondary)
                }
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .white : Colors.textTertiary)
                    .font(.system(size: 24))
            }
            .padding(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.white : Colors.cardStroke, lineWidth: isSelected ? 2 : 1)
            )
            .background(RoundedRectangle(cornerRadius: 16).fill(Colors.bgPrimary.opacity(isSelected ? 0.5 : 0.0)))
        }
    }
}

// MARK: - Screen 3: Reminder Notification selection
struct UpsellReminderView: View {
    let onNext: () -> Void
    @State private var reminderDays: Int = 2
    
    var body: some View {
        VStack(spacing: 0) {
            Text("When should we remind\nyou before your trial ends?")
                .font(.system(size: 24, weight: .bold)) // Reduced font size as requested
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.top, 16)
                .padding(.bottom, 40)
            
            ZStack {
                Circle()
                    .fill(Color(red: 0.08, green: 0.12, blue: 0.13)) // Dark, slightly teal gray matching screenshot
                    .frame(width: 160, height: 160)
                Image(systemName: "bell.badge.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Color(red: 0.95, green: 0.3, blue: 0.3), Color(white: 0.8)) // Red dot, light gray bell
                    .font(.system(size: 80))
            }
            .padding(.bottom, 40)
            
            VStack(spacing: 16) {
                UpsellReminderRow(days: 2, isSelected: reminderDays == 2) {
                    reminderDays = 2
                }
                UpsellReminderRow(days: 3, isSelected: reminderDays == 3) {
                    reminderDays = 3
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            VStack(spacing: 16) {
                Text("Enable notifications to receive this reminder")
                    .font(.system(size: 15))
                    .foregroundColor(Colors.textSecondary)
                
                PrimaryButton(title: "Continue", style: .blueGlass) {
                    onNext()
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }
}

struct UpsellReminderRow: View {
    let days: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(days) days before")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                    Text("12:00 PM (Local Time)") // Matched from typical reminders
                        .font(.system(size: 15))
                        .foregroundColor(Colors.textTertiary)
                }
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .white : Colors.textTertiary)
                    .font(.system(size: 24))
            }
            .padding(16)
            .background(Colors.cardSurface)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.white : Colors.cardStroke, lineWidth: isSelected ? 2 : 1)
            )
        }
    }
}

#Preview {
    ProUpsellFlowView()
}
