import SwiftUI

struct OnboardingPermissionsView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let onNext: () -> Void
    @State private var isRequesting = false
    @State private var animateItems = false

    var body: some View {
        ZStack {
            // Premium ambient background matching Intro
            Colors.bgPrimary.ignoresSafeArea()
            
            GeometryReader { proxy in
                let size = proxy.size
                Circle()
                    .fill(Colors.accentTeal.opacity(0.12))
                    .frame(width: 300, height: 300)
                    .blur(radius: 60)
                    .offset(x: animateItems ? size.width - 200 : -50,
                            y: animateItems ? -20 : size.height * 0.3)
                
                Circle()
                    .fill(Colors.accentBlue.opacity(0.12))
                    .frame(width: 250, height: 250)
                    .blur(radius: 60)
                    .offset(x: animateItems ? -100 : size.width - 150,
                            y: animateItems ? size.height * 0.6 : 0)
            }
            .animation(.easeInOut(duration: 8).repeatForever(autoreverses: true), value: animateItems)
            .ignoresSafeArea()

            VStack(spacing: 0) {
                ProgressHeader(step: 2, total: AppConstants.onboardingTotalSteps)
                    .padding(.horizontal, Spacing.l)
                    .padding(.top, Spacing.m)
                    .padding(.bottom, Spacing.s)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 6) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Colors.accentTeal)
                            
                        Text("System Access.")
                            .font(.system(size: 34, weight: .black, design: .rounded))
                            .foregroundColor(Colors.textPrimary)
                        
                        Text("To guarantee you wake up, Alarmo requires highest-level system priority.")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(Colors.textSecondary)
                            .lineSpacing(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Spacing.l)
                    .padding(.top, Spacing.xs)
                    .opacity(animateItems ? 1 : 0)
                    .offset(y: animateItems ? 0 : 20)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: animateItems)

                    VStack(spacing: Spacing.m) {
                        PermissionFeatureCard(
                            icon: "bell.badge.fill",
                            color: Colors.accentTeal,
                            title: "Time-Sensitive Alerts",
                            subtitle: "Allows alarms to ring instantly and display controls."
                        )
                        .opacity(animateItems ? 1 : 0)
                        .offset(y: animateItems ? 0 : 20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2), value: animateItems)

                        PermissionFeatureCard(
                            icon: "moon.zzz.fill",
                            color: Color.orange,
                            title: "Bypass Do Not Disturb",
                            subtitle: "Critical alerts force max volume even in Focus Mode."
                        )
                        .opacity(animateItems ? 1 : 0)
                        .offset(y: animateItems ? 0 : 20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.3), value: animateItems)
                    }
                    .padding(.horizontal, Spacing.l)
                    .padding(.top, Spacing.m)
                    
                    PermissionDialogPreview(onAllow: {
                        requestPermission()
                    }, onDeny: {
                        onNext()
                    })
                    .padding(.top, Spacing.m)
                    .padding(.bottom, Spacing.m)
                    .opacity(animateItems ? 1 : 0)
                    .offset(y: animateItems ? 0 : 20)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.4), value: animateItems)
                }
                Spacer(minLength: 0)
            }
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: "Next", style: .blueGlass) {
                    onNext() // Only going next, access is requested in the Allow button above
                }
                .padding(.horizontal, Spacing.l)
                .padding(.bottom, 48)
                .opacity(animateItems ? 1 : 0)
                .animation(.easeIn(duration: 0.5).delay(0.5), value: animateItems)
            }
        }
        .onAppear {
            animateItems = true
        }
    }
    
    private func requestPermission() {
        guard !isRequesting else { return }
        isRequesting = true
        
        // Haptic feedback
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        Task { @MainActor in
            await viewModel.requestNotificationPermissionAndAdvance()
            isRequesting = false
            onNext()
        }
    }
}

private struct PermissionFeatureCard: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(alignment: .top, spacing: Spacing.s) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
                
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(2)
            }
            .padding(.top, 2)
            
            Spacer(minLength: 0)
        }
        .padding(Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Colors.cardSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Colors.cardStroke, lineWidth: 1)
        )
        .appShadow(Shadows.card)
    }
}

private struct PermissionDialogPreview: View {
    let onAllow: () -> Void
    let onDeny: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: Spacing.xs) {
                Text("Please allow permission")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
                Text("Alarms and Notifications let us ring when the phone is locked")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Divider()
                .background(Colors.cardStroke)

            HStack(spacing: 0) {
                Button(action: onDeny) { 
                    Text("Don’t Allow")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }

                Divider()
                    .frame(height: 44) // Smaller divider Height
                    .background(Colors.cardStroke)

                Button(action: onAllow) {
                    Text("Allow")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Colors.accentTeal)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 290) // Match aesthetic size
        .background(Colors.cardSurface)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Colors.cardStroke, lineWidth: 0.5)
        )
        .appShadow(Shadows.card)
    }
}
