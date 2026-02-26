import SwiftUI

struct SettingsRootView: View {
    @ObservedObject var store = SettingsStore.shared
    @StateObject var subManager = SubscriptionManager.shared
    @StateObject var coordinator = SettingsCoordinator()
    
    @State private var showSignIn = false
    @State private var showPro = false
    @State private var showPenalty = false
    @State private var showProUpsellFlow = false
    
    // For ambient background animation
    @State private var animateItems = false
    
    var body: some View {
        NavigationStack(path: $coordinator.path) {
            ZStack {
                // Modern Ambient Background
                Colors.bgPrimary.ignoresSafeArea()
                
                GeometryReader { proxy in
                    let size = proxy.size
                    Circle()
                        .fill(Colors.accentTeal.opacity(0.1))
                        .frame(width: 250, height: 250)
                        .blur(radius: 60)
                        .offset(x: animateItems ? size.width - 150 : -50,
                                y: animateItems ? -20 : size.height * 0.2)
                    
                    Circle()
                        .fill(Colors.accentBlue.opacity(0.1))
                        .frame(width: 200, height: 200)
                        .blur(radius: 60)
                        .offset(x: animateItems ? -50 : size.width - 100,
                                y: animateItems ? size.height * 0.5 : 0)
                }
                .animation(.easeInOut(duration: 8).repeatForever(autoreverses: true), value: animateItems)
                .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: Spacing.xl) {
                        
                        // Header
                        Text("Workspace")
                            .font(.system(size: 34, weight: .black, design: .rounded))
                            .foregroundColor(Colors.textPrimary)
                            .padding(.horizontal, Spacing.l)
                            .padding(.top, Spacing.s)
                        
                        if !subManager.isPro {
                            FreePlanSettingsBanner {
                                showProUpsellFlow = true
                            }
                            .padding(.horizontal, Spacing.l)
                            .padding(.bottom, -Spacing.s)
                        }
                        
                        // User Hero Profile Card
                        VStack(spacing: 0) {
                            Button(action: { showSignIn = true }) {
                                HStack(spacing: Spacing.m) {
                                    ZStack {
                                        Circle()
                                            .fill(Colors.bgSecondary)
                                            .frame(width: 56, height: 56)
                                        Image(systemName: "person.crop.circle.fill")
                                            .font(.system(size: 32))
                                            .foregroundColor(Colors.textSecondary)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(store.isSignedIn ? "User_62831" : "Sign in to profile")
                                            .font(.system(size: 20, weight: .bold))
                                            .foregroundColor(Colors.textPrimary)
                                        Text("Manage account & sync")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(Colors.textSecondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(Colors.textTertiary)
                                }
                                .padding(Spacing.m)
                            }
                            .buttonStyle(PressedScaleButtonStyle())
                            
                            Divider().background(Colors.cardStroke)
                            
                            // Horizontal Premium Metric Dashboard
                            HStack(spacing: 0) {
                                // Points Metric
                                NavigationLink(destination: MyPointsView()) {
                                    VStack(alignment: .center, spacing: 6) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "p.circle.fill")
                                                .foregroundColor(.orange)
                                            Text("Points")
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundColor(Colors.textSecondary)
                                        }
                                        Text("\(store.points)")
                                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                                            .foregroundColor(Colors.textPrimary)
                                    }
                                    .padding(.vertical, Spacing.m)
                                    .frame(maxWidth: .infinity)
                                }
                                
                                Divider().background(Colors.cardStroke)
                                
                                // Pro Status
                                Button(action: { showPro = true }) {
                                    VStack(alignment: .center, spacing: 6) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "bolt.fill")
                                                .foregroundColor(Colors.accentTeal)
                                            Text("Status")
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundColor(Colors.textSecondary)
                                        }
                                        Text(subManager.isPro ? "Pro" : "Free")
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundColor(subManager.isPro ? Colors.accentTeal : Colors.textPrimary)
                                    }
                                    .padding(.vertical, Spacing.m)
                                    .frame(maxWidth: .infinity)
                                }
                                
                                Divider().background(Colors.cardStroke)
                                
                                // Shield
                                Button(action: { 
                                    if subManager.isPro {
                                        showPenalty = true 
                                    } else {
                                        showProUpsellFlow = true
                                    }
                                }) {
                                    VStack(alignment: .center, spacing: 6) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "shield.fill")
                                                .foregroundColor(.green)
                                            Text("Shield")
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundColor(Colors.textSecondary)
                                        }
                                        Text(store.accountabilityEnabled ? "ON" : "OFF")
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundColor(store.accountabilityEnabled ? .green : Colors.textTertiary)
                                    }
                                    .padding(.vertical, Spacing.m)
                                    .frame(maxWidth: .infinity)
                                }
                            }
                            .buttonStyle(PressedScaleButtonStyle())
                        }
                        .background(Colors.cardSurface)
                        .cornerRadius(24)
                        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Colors.cardStroke, lineWidth: 1))
                        .appShadow(Shadows.card)
                        .padding(.horizontal, Spacing.l)
                        
                        // Essential Config Modules
                        VStack(spacing: Spacing.m) {
                            Text("Engine Behavior")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Colors.textSecondary)
                                .textCase(.uppercase)
                                .padding(.horizontal, Spacing.l)
                                .padding(.bottom, -8)
                            
                            VStack(spacing: 0) {
                                ModularSettingsRow(title: "Advanced Alarm Options", icon: "slider.horizontal.3", isLast: false) {
                                    coordinator.navigate(to: .advanced)
                                }
                                ModularSettingsRow(title: "Sound Output Matrix", icon: "hifispeaker.fill", trailing: store.soundOutputMode.rawValue, isLast: false) {
                                    coordinator.navigate(to: .soundOutput)
                                }
                                ModularSettingsRow(title: "Appearance & Theme", icon: "paintpalette.fill", isLast: false) {
                                    coordinator.navigate(to: .theme)
                                }
                                ModularSettingsRow(title: "System Notifications", icon: "bell.badge.fill", isLast: false) {
                                    coordinator.navigate(to: .notification)
                                }
                                ModularSettingsRow(title: "App Configurations", icon: "gearshape.fill", isLast: true) {
                                    coordinator.navigate(to: .system)
                                }
                            }
                            .background(Colors.cardSurface)
                            .cornerRadius(24)
                            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Colors.cardStroke, lineWidth: 1))
                            .appShadow(Shadows.card)
                            .padding(.horizontal, Spacing.l)
                        }
                        
                        // Premium Help Banner
                        Button(action: { coordinator.navigate(to: .optimization) }) {
                            HStack(spacing: Spacing.m) {
                                ZStack {
                                    Circle().fill(Colors.accentTeal.opacity(0.2)).frame(width: 44, height: 44)
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(Colors.accentTeal)
                                        .font(.system(size: 20))
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Alarms didn't ring?")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(Colors.accentTeal)
                                    Text("Run Alarm Optimizer")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Colors.textTertiary)
                            }
                            .padding(Spacing.m)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(LinearGradient(colors: [Colors.bgSecondary, Colors.cardSurface], startPoint: .topLeading, endPoint: .bottomTrailing))
                            )
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Colors.accentTeal.opacity(0.3), lineWidth: 1))
                        }
                        .appShadow(Shadows.card)
                        .padding(.horizontal, Spacing.l)
                        
                        // Footer Links
                        HStack(spacing: 30) {
                            Button("Notice") { coordinator.navigate(to: .notice) }
                            Button("FAQ") { coordinator.navigate(to: .faq) }
                            Button("Feedback") {
                                if let url = URL(string: "mailto:support@alarmo.app") {
                                    UIApplication.shared.open(url)
                                }
                            }
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, Spacing.m)
                        
                        // Developer Tools
                        #if DEBUG
                        VStack(spacing: 8) {
                            Text("Developer Tools")
                                .font(.caption)
                                .foregroundColor(Colors.textTertiary)
                            
                            Button(action: {
                                subManager.isPro.toggle()
                                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                            }) {
                                Text(subManager.isPro ? "Force Free Version" : "Force Pro Version")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(subManager.isPro ? Color.red.opacity(0.8) : Colors.accentTeal)
                                    .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.top, Spacing.xl)
                        #endif
                        
                    }
                    .padding(.bottom, AppConstants.tabBarHeight + 40)
                }
            }
            .navigationDestination(for: SettingsRoute.self) { route in
                switch route {
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
                    SimplePlaceholderView(title: "Notice")
                }
            }
        }
        .fullScreenCover(isPresented: $showSignIn) {
            SignInView()
        }
        .fullScreenCover(isPresented: $showPro) {
            ProView()
        }
        .fullScreenCover(isPresented: $showPenalty) {
            AccountabilityShieldSettingsView()
        }
        .fullScreenCover(isPresented: $showProUpsellFlow) {
            ProUpsellFlowView()
        }
        .onAppear {
            animateItems = true
        }
    }
}

private struct ModularSettingsRow: View {
    let title: String
    let icon: String
    var trailing: String? = nil
    let isLast: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.m) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(Colors.textSecondary)
                    .frame(width: 24)
                
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Colors.textPrimary)
                
                Spacer()
                
                if let trailing = trailing {
                    Text(trailing)
                        .font(.system(size: 15, weight: .medium))
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
        .buttonStyle(PressedScaleButtonStyle())
        .overlay(
            VStack {
                if !isLast {
                    Spacer()
                    Divider()
                        .background(Colors.cardStroke)
                        .padding(.leading, 56) // align under text roughly
                }
            }
        )
    }
}

struct SimplePlaceholderView: View {
    let title: String
    
    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()
            Text("\(title) coming soon")
                .foregroundColor(Colors.textSecondary)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
